require "base64"
require "http/client"
require "openssl"
require "socket"
require "uri"

module Anthropic
  class Client
    DEFAULT_BASE_URL = "https://api.anthropic.com"
    API_VERSION      = "2026-10-21"
    DEFAULT_TIMEOUT  = 600.seconds
    MAX_REDIRECTS    = 20

    CROSS_ORIGIN_STRIPPED_HEADERS = {"authorization", "x-api-key", "cookie", "host", "proxy-authorization"}

    # Sentinel distinguishing omitted keyword arguments from explicit `nil`.
    struct UnsetValue
      INSTANCE = new
    end

    UNSET = UnsetValue::INSTANCE

    @@warned_dual_credentials = false
    class_property warning_io : IO? = nil

    # Reset one-shot dual-credential warning state (intended for test suites).
    def self.reset_dual_credentials_warning! : Nil
      @@warned_dual_credentials = false
    end

    DEFAULT_MAX_RETRIES   =   2
    DEFAULT_INITIAL_DELAY = 0.5 # seconds
    DEFAULT_MAX_DELAY     = 8.0 # seconds

    @api_key : String?
    @auth_token : String?
    @base_url : String
    @timeout : Time::Span?
    @timeout_overridden : Bool
    @max_retries : Int32
    @initial_retry_delay : Float64
    @max_retry_delay : Float64
    @default_headers : Hash(String, String)
    @default_query : Hash(String, String)
    @middleware : Array(Middleware)
    @proxy : String?
    @client_workspace_id : String?
    @client_user_profile_id : String?
    @request_contexts : Hash(UInt64, {Time::Span?, Bool})? = nil

    def initialize(
      api_key : String | UnsetValue | Nil = UNSET,
      auth_token : String | UnsetValue | Nil = UNSET,
      base_url : String? = nil,
      timeout : Time::Span | UnsetValue | Nil = UNSET,
      max_retries : Int32 = DEFAULT_MAX_RETRIES,
      initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
      max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
      default_headers : Hash(String, String) = {} of String => String,
      default_query : Hash(String, String) = {} of String => String,
      middleware : Array(Middleware) = [] of Middleware,
      webhook_key : String? = nil,
      proxy : String? = nil,
      workspace_id : String? = nil,
      user_profile_id : String? = nil,
    )
      @api_key, @auth_token = resolve_initial_credentials(api_key, auth_token)
      @base_url = (base_url || ENV["ANTHROPIC_BASE_URL"]? || DEFAULT_BASE_URL).rstrip('/')
      @timeout, @timeout_overridden = resolve_initial_timeout(timeout)
      @client_workspace_id = workspace_id
      @client_user_profile_id = user_profile_id
      @max_retries = max_retries
      @initial_retry_delay = initial_retry_delay
      @max_retry_delay = max_retry_delay
      @default_headers = default_headers.dup
      @default_query = default_query.dup
      # Normalize to Array(Middleware): argument matching accepts
      # Array(Subtype) but ivar assignment is invariant.
      @middleware = middleware.map(&.as(Middleware))
      @webhook_key = webhook_key || ENV["ANTHROPIC_WEBHOOK_SIGNING_KEY"]?
      @proxy = proxy
    end

    # Webhook signing key for `BetaWebhooks#unwrap`. Explicit argument wins,
    # falling back to `ANTHROPIC_WEBHOOK_SIGNING_KEY`.
    getter webhook_key : String?

    # Returns a copy of this client with per-request overrides applied.
    #
    # Upstream SDKs take `requestOptions` on every call; the Crystal
    # equivalent is a scoped copy, so every resource through it picks the
    # overrides up. `middleware` replaces the chain; credentials, base
    # URL, and proxy override the copy's connection settings (handy for
    # per-tenant scoping):
    #
    # ```
    # scoped = client.with_options(timeout: 30.seconds, max_retries: 0)
    # scoped.messages.create(model: "...", max_tokens: 64, messages: [...])
    # ```
    def with_options(
      timeout : Time::Span | UnsetValue | Nil = UNSET,
      max_retries : Int32? = nil,
      extra_headers : Hash(String, String)? = nil,
      extra_query : Hash(String, String)? = nil,
      middleware : Array(Middleware)? = nil,
      api_key : String | UnsetValue | Nil = UNSET,
      auth_token : String | UnsetValue | Nil = UNSET,
      base_url : String? = nil,
      proxy : String? = nil,
      workspace_id : String | UnsetValue | Nil = UNSET,
      user_profile_id : String | UnsetValue | Nil = UNSET,
    ) : Client
      if api_key.is_a?(String) && auth_token.is_a?(String)
        raise ArgumentError.new("Cannot provide both api_key and auth_token")
      end

      copy = dup
      copy.reset_request_contexts!
      copy.middleware = middleware ? middleware.map(&.as(Middleware)) : @middleware.dup
      apply_option_timeout(copy, timeout)
      copy.max_retries = max_retries if max_retries
      copy.default_headers = @default_headers.merge(extra_headers || {} of String => String)
      copy.default_query = @default_query.merge(extra_query || {} of String => String)
      apply_option_credentials(copy, api_key, auth_token)
      copy.base_url = base_url.rstrip('/') if base_url
      copy.proxy = proxy if proxy
      copy.client_workspace_id = workspace_id unless workspace_id.is_a?(UnsetValue)
      copy.client_user_profile_id = user_profile_id unless user_profile_id.is_a?(UnsetValue)
      copy
    end

    private def resolve_initial_credentials(
      api_key : String | UnsetValue | Nil,
      auth_token : String | UnsetValue | Nil,
    ) : {String?, String?}
      if api_key.is_a?(String) && auth_token.is_a?(String)
        raise ArgumentError.new("Cannot provide both api_key and auth_token")
      end

      resolved_key, resolved_token =
        if api_key.is_a?(UnsetValue) && auth_token.is_a?(UnsetValue)
          resolve_env_credentials
        else
          {
            api_key.is_a?(UnsetValue) ? nil : api_key,
            auth_token.is_a?(UnsetValue) ? nil : auth_token,
          }
        end

      unless resolved_key || resolved_token
        raise ArgumentError.new(
          "API key or auth token required. Set ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN environment variables, or pass api_key/auth_token parameters."
        )
      end

      {resolved_key, resolved_token}
    end

    private def resolve_env_credentials : {String?, String?}
      env_key = ENV["ANTHROPIC_API_KEY"]?
      env_token = ENV["ANTHROPIC_AUTH_TOKEN"]?
      has_key = !env_key.nil? && !env_key.empty?
      has_token = !env_token.nil? && !env_token.empty?

      if has_key && has_token
        emit_dual_credential_warning!
        return {env_key, nil}
      end
      return {env_key, nil} if has_key
      return {nil, env_token} if has_token

      {nil, nil}
    end

    private def emit_dual_credential_warning! : Nil
      return if @@warned_dual_credentials

      @@warned_dual_credentials = true
      (@@warning_io || STDERR).puts(
        "Anthropic: ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are both set. Using ANTHROPIC_API_KEY."
      )
    end

    private def resolve_initial_timeout(timeout : Time::Span | UnsetValue | Nil) : {Time::Span?, Bool}
      case timeout
      when UnsetValue, Nil
        {timeout.nil? ? nil : DEFAULT_TIMEOUT, !timeout.is_a?(UnsetValue)}
      else
        {timeout, true}
      end
    end

    private def apply_option_timeout(copy : Client, timeout : Time::Span | UnsetValue | Nil) : Nil
      case timeout
      when UnsetValue
        # Preserve existing timeout and override flag
      when Nil
        copy.timeout = nil
        copy.timeout_overridden = true
      else
        copy.timeout = timeout
        copy.timeout_overridden = true
      end
    end

    private def apply_option_credentials(
      copy : Client,
      api_key : String | UnsetValue | Nil,
      auth_token : String | UnsetValue | Nil,
    ) : Nil
      if !api_key.is_a?(UnsetValue) && !auth_token.is_a?(UnsetValue)
        if !api_key.nil? && !auth_token.nil?
          raise ArgumentError.new("Cannot provide both api_key and auth_token")
        end
        copy.api_key = api_key
        copy.auth_token = auth_token
      elsif !api_key.is_a?(UnsetValue)
        copy.api_key = api_key
        copy.auth_token = nil unless api_key.nil?
      elsif !auth_token.is_a?(UnsetValue)
        copy.auth_token = auth_token
        copy.api_key = nil unless auth_token.nil?
      end
    end

    # Returns a copy of this client with *middleware* appended after the
    # client's existing middleware (which stays outermost).
    #
    # ```
    # scoped = client.with_middleware(LoggingMiddleware.new)
    # ```
    def with_middleware(*middleware : Middleware) : Client
      with_options(middleware: @middleware + middleware.to_a)
    end

    getter api_key : String?
    getter auth_token : String?
    getter timeout : Time::Span?
    getter? timeout_overridden : Bool

    def workspace_id : String?
      @client_workspace_id
    end

    def user_profile_id : String?
      @client_user_profile_id
    end

    protected setter timeout : Time::Span?
    protected setter timeout_overridden : Bool
    protected setter max_retries : Int32
    protected setter default_headers : Hash(String, String)
    protected setter default_query : Hash(String, String)
    protected setter middleware : Array(Middleware)
    protected setter api_key : String?
    protected setter auth_token : String?
    protected setter base_url : String
    protected setter proxy : String?
    protected setter client_workspace_id : String?
    protected setter client_user_profile_id : String?

    # The configured middleware chain (outermost first).
    def middleware : Array(Middleware)
      @middleware
    end

    # Resource accessors
    def messages : Messages
      Messages.new(self)
    end

    def models : Models
      Models.new(self)
    end

    # Files API for uploading and managing files.
    #
    # ```
    # file = client.files.upload(Path["document.pdf"])
    # ```
    def files : Files
      Files.new(self)
    end

    # Skills API for managing skills.
    #
    # ```
    # skills = client.skills.list
    # ```
    def skills : Skills
      Skills.new(self)
    end

    # User Profiles API for managing end-user profiles, enforcement status, and action URLs.
    def user_profiles : UserProfiles
      UserProfiles.new(self)
    end

    def beta : Beta
      Beta.new(self)
    end

    # Whether this client supports the Beta Message Threads API.
    def supports_message_threads? : Bool
      true
    end

    # HTTP methods
    alias QueryParamValue = String | Int32 | Int64 | Float64 | Bool | Nil | JSON::Any | Array(String) | Array(JSON::Any) | Hash(String, String) | Hash(String, JSON::Any)
    alias QueryParams = Hash(String, String) |
                        Hash(String, String?) |
                        Hash(String, String | Array(String)) |
                        Hash(String, String | Array(String) | Nil) |
                        Hash(String, JSON::Any) |
                        Hash(String, QueryParamValue)

    def get(
      path : String,
      params : QueryParams? = nil,
      extra_headers : Hash(String, String)? = nil,
      timeout : Time::Span? = nil,
      beta : Bool = false,
    ) : HTTP::Client::Response
      full_path = append_query_params(path, merge_query(params))
      with_request_context(timeout, beta) do
        request("GET", full_path, nil, extra_headers)
      end
    end

    # POST with any JSON::Serializable body
    def post(
      path : String,
      body,
      extra_headers : Hash(String, String)? = nil,
      timeout : Time::Span? = nil,
      beta : Bool = false,
    ) : HTTP::Client::Response
      body_str = body.nil? ? "{}" : body.to_json
      full_path = apply_default_query(path)
      with_request_context(timeout, beta) do
        request("POST", full_path, body_str, extra_headers)
      end
    end

    def delete(
      path : String,
      extra_headers : Hash(String, String)? = nil,
      timeout : Time::Span? = nil,
      beta : Bool = false,
    ) : HTTP::Client::Response
      full_path = apply_default_query(path)
      with_request_context(timeout, beta) do
        request("DELETE", full_path, nil, extra_headers)
      end
    end

    # POST with streaming response
    def post_stream(
      path : String,
      body,
      extra_headers : Hash(String, String)? = nil,
      &
    )
      ctx_timeout, _ = current_request_context
      uri = URI.parse(@base_url)
      path = apply_default_query(path)
      hdrs = headers(extra_headers, method: "POST")

      with_http_client(uri, timeout: ctx_timeout) do |client|
        body_str = body.nil? ? "{}" : body.to_json
        client.post(path, headers: hdrs, body: body_str) do |response|
          handle_error(response) unless response.success?
          yield response
        end
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Stream read timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error | OpenSSL::Error
        raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
      end
    end

    def get_stream(
      path : String,
      extra_headers : Hash(String, String)? = nil,
      &
    )
      ctx_timeout, _ = current_request_context
      uri = URI.parse(@base_url)
      path = apply_default_query(path)
      hdrs = headers(extra_headers, method: "GET")

      with_http_client(uri, timeout: ctx_timeout) do |client|
        client.get(path, headers: hdrs) do |response|
          handle_error(response) unless response.success?
          yield response
        end
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Stream read timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error | OpenSSL::Error
        raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
      end
    end

    # GET request returning raw response body (for binary downloads)
    def get_raw(
      path : String,
      extra_headers : Hash(String, String)? = nil,
    ) : IO::Memory
      ctx_timeout, _ = current_request_context
      uri = URI.parse(@base_url)
      path = apply_default_query(path)
      io = IO::Memory.new

      # Don't set content-type for downloads
      hdrs = headers(extra_headers, content_type: nil, method: "GET")
      response = execute_http_with_redirects("GET", path, nil, uri, hdrs, timeout: ctx_timeout)
      handle_error(response) unless response.success?
      io.write(response.body.to_slice)
      io.rewind

      io
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    end

    # POST multipart form data (for file uploads)
    def post_multipart(
      path : String,
      file : IO,
      filename : String? = nil,
      content_type : String = "application/octet-stream",
      extra_headers : Hash(String, String)? = nil,
      form_fields : Hash(String, String)? = nil,
    ) : HTTP::Client::Response
      ctx_timeout, _ = current_request_context
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri, timeout: ctx_timeout) do |client|
        # Build multipart body using Crystal's standard FormData builder
        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)

        form_fields.try &.each do |name, value|
          builder.field(name, value)
        end

        metadata = HTTP::FormData::FileMetadata.new(filename: filename || "")
        file_headers = HTTP::Headers{"Content-Type" => content_type}
        builder.file("file", file, metadata, headers: file_headers)
        builder.finish

        body_io.rewind
        hdrs = headers(extra_headers, content_type: builder.content_type, method: "POST")

        response = client.post(path, headers: hdrs, body: body_io)
        handle_error(response) unless response.success?
        return response
      end

      raise APIError.new("Request failed")
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    end

    # POST multipart form data with multiple files and optional form fields
    def post_multipart_files(
      path : String,
      files : Array(FileUpload),
      form_fields : Hash(String, String)? = nil,
      extra_headers : Hash(String, String)? = nil,
    ) : HTTP::Client::Response
      ctx_timeout, _ = current_request_context
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri, timeout: ctx_timeout) do |client|
        # Build multipart body using Crystal's standard FormData builder
        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)

        # Form fields
        form_fields.try &.each do |name, value|
          builder.field(name, value)
        end

        # File parts
        files.each do |file|
          metadata = HTTP::FormData::FileMetadata.new(filename: file.filename || "")
          file_headers = HTTP::Headers{"Content-Type" => file.content_type}
          builder.file("files[]", file.io, metadata, headers: file_headers)
        end

        builder.finish

        # Headers for multipart using unified helper
        hdrs = headers(extra_headers, content_type: builder.content_type, method: "POST")

        body_io.rewind
        response = client.post(path, headers: hdrs, body: body_io)
        handle_error(response) unless response.success?
        return response
      end

      raise APIError.new("Request failed")
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    end

    private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      timeout, beta = current_request_context
      uri = URI.parse(@base_url)
      req_headers = headers(extra_headers, method: method)

      # Fast path: no middleware — send directly with the existing retry loop.
      return request_direct(method, path, body, uri, req_headers, timeout: timeout) if @middleware.empty?

      # Middleware path: compose a chain around the terminal HTTP send. The
      # chain runs once per attempt inside the retry loop. The terminal returns
      # an APIResponse for every status (4xx/5xx do not raise); connection
      # errors do raise. Typed error raising happens after the chain returns.
      api_request = APIRequest.new(method, path, req_headers, body, beta: beta)

      response = nil
      (@max_retries + 1).times do |attempt|
        begin
          api_response = invoke_chain(api_request, uri, timeout: timeout)
          response = to_http_response(api_response)

          if api_response.success? || !should_retry?(response)
            handle_error(response) unless response.success?
            return response
          end
        rescue ex : APITimeoutError
          raise ex if attempt >= @max_retries
        rescue ex : APIConnectionError
          raise ex if attempt >= @max_retries
        end

        if attempt < @max_retries
          sleep(backoff_delay(attempt, response))
        end
      end

      if resp = response
        handle_error(resp)
      end
      raise APIError.new("Request failed after #{@max_retries} retries")
    end

    # Send a single HTTP attempt and return its raw response (no middleware).
    private def request_direct(
      method : String,
      path : String,
      body : String?,
      uri : URI,
      req_headers : HTTP::Headers,
      timeout : Time::Span? = nil,
    ) : HTTP::Client::Response
      response = nil
      (@max_retries + 1).times do |attempt|
        begin
          response = execute_http_with_redirects(method, path, body, uri, req_headers, timeout: timeout)

          # Check if we should retry (respects x-should-retry header)
          if response.success? || !should_retry?(response)
            handle_error(response) unless response.success?
            return response
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Request timed out", cause: ex) if attempt >= @max_retries
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex) if attempt >= @max_retries
        rescue ex : APITimeoutError | APIConnectionError
          # Typed failures from the proxy path retry like socket errors.
          raise ex if attempt >= @max_retries
        end

        # Use server-provided retry delay if available
        if attempt < @max_retries
          sleep(backoff_delay(attempt, response))
        end
      end

      # All retries exhausted - raise the appropriate error from last response
      if resp = response
        handle_error(resp)
      end
      raise APIError.new("Request failed after #{@max_retries} retries")
    end

    # Compose the middleware chain around the terminal HTTP send and invoke it
    # for a single attempt.
    private def invoke_chain(api_request : APIRequest, uri : URI, timeout : Time::Span? = nil) : APIResponse
      terminal = MiddlewareNext.new do |req|
        send_terminal(req, uri, timeout: timeout)
      end

      chain = @middleware.reverse.reduce(terminal) do |inner, layer|
        inner_next = inner
        MiddlewareNext.new do |req|
          layer.call(req, inner_next)
        end
      end

      chain.call(api_request)
    end

    # The terminal HTTP send: performs one attempt and returns an APIResponse
    # for every status. Connection-level errors raise.
    private def send_terminal(api_request : APIRequest, uri : URI, timeout : Time::Span? = nil) : APIResponse
      http_response = execute_http_with_redirects(
        api_request.method,
        api_request.path,
        api_request.body,
        uri,
        api_request.headers,
        timeout: timeout
      )

      APIResponse.new(http_response.status_code, http_response.headers, http_response.body, api_request)
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    end

    private def execute_http_with_redirects(
      method : String,
      path : String,
      body : String?,
      uri : URI,
      req_headers : HTTP::Headers,
      timeout : Time::Span? = nil,
    ) : HTTP::Client::Response
      current_uri = uri
      current_path = path
      current_method = method
      current_body = body
      current_headers = req_headers.dup
      redirects = 0

      loop do
        response = send_once(current_method, current_path, current_body, current_uri, current_headers, timeout: timeout)
        location = response.headers["location"]?
        if !redirect_status?(response.status_code) || location.nil? || location.empty?
          return response
        end

        redirects += 1
        raise APIConnectionError.new("Too many redirects (exceeded #{MAX_REDIRECTS})") if redirects > MAX_REDIRECTS

        next_uri = current_uri.resolve(current_path).resolve(location)
        strip_cross_origin_headers!(current_headers) unless same_origin?(current_uri, next_uri)
        current_method, current_body = apply_redirect_method(response.status_code, current_method, current_body, current_headers)
        current_uri = next_uri
        current_path = request_target_for(next_uri)
      end
    end

    private def send_once(
      method : String,
      path : String,
      body : String?,
      uri : URI,
      req_headers : HTTP::Headers,
      timeout : Time::Span? = nil,
    ) : HTTP::Client::Response
      with_http_client(uri, timeout: timeout) do |client|
        case method
        when "GET"    then client.get(path, headers: req_headers)
        when "POST"   then client.post(path, headers: req_headers, body: body)
        when "DELETE" then client.delete(path, headers: req_headers)
        else               raise "Unknown HTTP method: #{method}"
        end
      end
    end

    private def redirect_status?(status : Int32) : Bool
      status == 301 || status == 302 || status == 303 || status == 307 || status == 308
    end

    private def same_origin?(a : URI, b : URI) : Bool
      a.scheme.try(&.downcase) == b.scheme.try(&.downcase) &&
        a.host.try(&.downcase) == b.host.try(&.downcase) &&
        effective_port(a) == effective_port(b)
    end

    private def effective_port(uri : URI) : Int32?
      return uri.port if uri.port
      case uri.scheme.try(&.downcase)
      when "https" then 443
      when "http"  then 80
      else              nil
      end
    end

    private def strip_cross_origin_headers!(headers : HTTP::Headers) : Nil
      CROSS_ORIGIN_STRIPPED_HEADERS.each { |name| headers.delete(name) }
    end

    private def apply_redirect_method(
      status : Int32,
      method : String,
      body : String?,
      headers : HTTP::Headers,
    ) : {String, String?}
      if status == 303 || ((status == 301 || status == 302) && method == "POST")
        headers.delete("content-type")
        headers.delete("content-length")
        {"GET", nil}
      else
        {method, body}
      end
    end

    private def request_target_for(uri : URI) : String
      target = uri.path.empty? ? "/" : uri.path
      uri.query ? "#{target}?#{uri.query}" : target
    end

    # Reconstruct an HTTP::Client::Response from an APIResponse so the existing
    # error-handling and retry helpers can be reused.
    private def to_http_response(api_response : APIResponse) : HTTP::Client::Response
      HTTP::Client::Response.new(
        api_response.status,
        body: api_response.body,
        headers: api_response.headers,
      )
    end

    private def encode_query_params(params : QueryParams) : String
      query = URI::Params.new

      params.each do |key, value|
        append_encoded_query_value(query, key, value)
      end

      query.to_s
    end

    private def append_encoded_query_value(query : URI::Params, prefix : String, value) : Nil
      case value
      when Nil
        return
      when Array
        array_key = prefix.ends_with?("[]") ? prefix : "#{prefix}[]"
        value.each do |item|
          next if item.nil?
          append_encoded_query_value(query, array_key, item)
        end
      when Hash
        value.each do |k, v|
          append_encoded_query_value(query, "#{prefix}[#{k}]", v)
        end
      when JSON::Any
        case raw = value.raw
        when Nil
          return
        when Array
          array_key = prefix.ends_with?("[]") ? prefix : "#{prefix}[]"
          raw.each { |item| append_encoded_query_value(query, array_key, item) }
        when Hash
          raw.each { |k, v| append_encoded_query_value(query, "#{prefix}[#{k}]", v) }
        else
          query.add(prefix, raw.to_s)
        end
      else
        query.add(prefix, value.to_s)
      end
    end

    # Merge default query params under per-request params: an explicit
    # per-request key wins over the default instead of sending both.
    private def merge_query(query : QueryParams?) : Hash(String, QueryParamValue)
      merged = {} of String => QueryParamValue
      @default_query.each { |key, value| merged[key] = value }
      if query
        query.each do |key, value|
          if value.nil?
            merged.delete(key)
          else
            merged[key] = value
          end
        end
      end
      merged
    end

    private def append_query_params(path : String, query : Hash(String, QueryParamValue)) : String
      return path if query.empty?

      encoded = encode_query_params(query)
      return path if encoded.empty?

      separator = path.includes?('?') ? '&' : '?'
      "#{path}#{separator}#{encoded}"
    end

    # Append the client's default query params to a request path.
    private def apply_default_query(path : String) : String
      append_query_params(path, merge_query(nil))
    end

    # Yields an HTTP client for *uri*, tunneling through the configured
    # proxy when one applies. Explicit `proxy:` wins, otherwise the
    # `HTTPS_PROXY`/`https_proxy` environment applies unless
    # `NO_PROXY`/`no_proxy` matches the host. Only HTTPS destinations
    # tunnel (plain-HTTP bases bypass the proxy); credentials in the
    # proxy URL become a `Proxy-Authorization` header. Every HTTP path
    # in this client goes through here so timeouts stay centralized.
    # Socket errors propagate unwrapped so each caller's retry handling
    # applies; proxy/TLS negotiation failures raise `APIConnectionError`.
    private def with_http_client(uri : URI, timeout : Time::Span? = nil, & : HTTP::Client -> T) : T forall T
      active_timeout = timeout || @timeout
      proxy_uri = proxy_for_uri(uri)

      unless proxy_uri
        return HTTP::Client.new(uri) do |client|
          client.connect_timeout = active_timeout
          client.read_timeout = active_timeout
          yield client
        end
      end

      socket = open_proxy_tunnel(uri, proxy_uri, active_timeout)
      begin
        tls = OpenSSL::SSL::Socket::Client.new(socket, sync_close: true, hostname: uri.host)
        client = HTTP::Client.new(tls, uri.host || "", uri.port || 443)
        client.connect_timeout = active_timeout
        client.read_timeout = active_timeout
        begin
          yield client
        ensure
          client.close
        end
      rescue ex : OpenSSL::Error
        raise APIConnectionError.new("Proxy TLS to #{uri.host} failed: #{ex.message}", cause: ex)
      ensure
        socket.close unless socket.closed?
      end
    end

    # Open a TCP connection to *proxy_uri* and issue the `CONNECT`
    # handshake for *uri*. Returns the tunneled socket with the proxy's
    # response headers consumed, ready for the TLS handshake.
    private def open_proxy_tunnel(uri : URI, proxy_uri : URI, timeout : Time::Span? = nil) : TCPSocket
      host = proxy_uri.host
      if host.nil? || host.empty?
        raise ArgumentError.new("Invalid proxy URL (missing host): #{proxy_uri}")
      end
      port = proxy_uri.port || (proxy_uri.scheme == "https" ? 443 : 80)

      active_timeout = timeout || @timeout
      socket = TCPSocket.new(host, port, connect_timeout: active_timeout)
      socket.read_timeout = active_timeout

      target = "#{uri.host}:#{uri.port || 443}"
      socket << "CONNECT #{target} HTTP/1.1\r\n"
      socket << "Host: #{target}\r\n"
      if user = proxy_uri.user
        socket << "Proxy-Authorization: Basic #{Base64.strict_encode("#{user}:#{proxy_uri.password}")}\r\n"
      end
      socket << "\r\n"
      socket.flush

      status = socket.gets
      if status.nil? || !status.matches?(/\AHTTP\/\d(?:\.\d)? 200\b/)
        socket.close
        raise APIConnectionError.new("Proxy CONNECT to #{target} failed: #{status.try(&.strip) || "no response"}")
      end
      while (line = socket.gets) && line != "\r\n" && !line.empty?
      end

      socket
    end

    private def proxy_for_uri(uri : URI) : URI?
      return nil unless uri.scheme == "https"
      return nil if proxy_bypassed?(uri.host)

      raw = @proxy || ENV["HTTPS_PROXY"]? || ENV["https_proxy"]?
      return nil if raw.nil? || raw.empty?

      normalized = raw.includes?("://") ? raw : "http://#{raw}"
      parsed = URI.parse(normalized)
      unless parsed.scheme == "http"
        raise ArgumentError.new("Only http:// proxies are supported (got #{parsed.scheme || "no scheme"}): #{raw}")
      end
      parsed
    rescue URI::Error
      raise ArgumentError.new("Invalid proxy URL: #{raw}")
    end

    private def proxy_bypassed?(host : String?) : Bool
      return false unless host

      no_proxy = ENV["NO_PROXY"]? || ENV["no_proxy"]?
      return false unless no_proxy

      downcased = host.downcase
      no_proxy.split(",").any? do |entry|
        pattern = entry.strip.downcase
        next false if pattern.empty?
        next true if pattern == "*"
        # Leading-dot entries (".example.com") match the domain itself
        # as well as subdomains.
        pattern = pattern.lstrip('.')
        next false if pattern.empty?
        # Strip an optional :port without mangling IPv6 literals.
        if bracketed = pattern.match(/\A\[(.+)\](?::\d+)?\z/)
          pattern = bracketed[1]
        elsif pattern.count(":") == 1
          pattern = pattern.sub(/:\d+\z/, "")
        end
        downcased == pattern || downcased.ends_with?(".#{pattern}")
      end
    end

    private def with_request_context(timeout : Time::Span?, beta : Bool, &)
      contexts = @request_contexts
      fiber_id = Fiber.current.object_id
      previous = contexts.try(&.[]?(fiber_id))
      return yield if previous.nil? && timeout.nil? && !beta

      contexts ||= (@request_contexts = {} of UInt64 => {Time::Span?, Bool})
      contexts[fiber_id] = {timeout, beta}
      begin
        yield
      ensure
        if prev = previous
          contexts[fiber_id] = prev
        else
          contexts.delete(fiber_id)
        end
      end
    end

    private def current_request_context : {Time::Span?, Bool}
      @request_contexts.try(&.[]?(Fiber.current.object_id)) || {nil, false}
    end

    protected def reset_request_contexts! : Nil
      @request_contexts = nil
    end

    private def headers(
      extra_headers : Hash(String, String)? = nil,
      content_type : String? = "application/json",
      method : String? = nil,
    ) : HTTP::Headers
      ctx_timeout, _ = current_request_context
      HTTP::Headers{
        "anthropic-version" => API_VERSION,
        "user-agent"        => "anthropic-crystal/#{VERSION}",
      }.tap do |hdrs|
        if (api_key = @api_key) && !api_key.empty?
          hdrs["authorization"] = "Bearer #{api_key}"
        elsif (auth_token = @auth_token) && !auth_token.empty?
          hdrs["authorization"] = "Bearer #{auth_token}"
        end

        if effective_timeout = ctx_timeout || @timeout
          hdrs["x-stainless-timeout"] = effective_timeout.total_seconds.to_i.to_s
        end

        if ws = @client_workspace_id
          hdrs[WORKSPACE_ID_HEADER] = ws
        end
        if up = @client_user_profile_id
          hdrs[USER_PROFILE_ID_HEADER] = up
        end

        hdrs["content-type"] = content_type if content_type
        @default_headers.each { |key, value| hdrs[key] = value }
        extra_headers.try &.each { |key, value| hdrs[key] = value }

        # Inject idempotency key automatically for mutating methods if not already set
        if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) && !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
          hdrs["idempotency-key"] = UUID.random.to_s
        end
      end
    end

    private def handle_error(response : HTTP::Client::Response)
      raise Anthropic.build_api_error(response.status_code, response.body, response.headers)
    end

    # Check if a response indicates we should retry
    # Respects x-should-retry header if present
    private def should_retry?(response : HTTP::Client::Response) : Bool
      # Check for explicit x-should-retry header
      if should_retry_header = response.headers["x-should-retry"]?
        return should_retry_header.downcase == "true"
      end

      retryable?(response.status_code)
    end

    private def retryable?(status : Int32) : Bool
      status == 408 || status == 409 || status == 429 || status == 529 || status >= 500
    end

    # Calculate retry delay, respecting server-provided hints
    # Uses Ruby SDK's formula: initial_delay * retry² * jitter, capped at max_delay
    private def backoff_delay(attempt : Int32, response : HTTP::Client::Response? = nil) : Time::Span
      # Check for server-provided retry delay
      if response
        # Check retry-after-ms first (milliseconds)
        if retry_ms = response.headers["retry-after-ms"]?
          if ms = retry_ms.to_i?
            return ms.milliseconds
          end
        end

        # Check retry-after (seconds or HTTP date)
        if retry_after = response.headers["retry-after"]?
          if seconds = retry_after.to_i?
            return seconds.seconds
          end

          begin
            retry_time = Time::Format::HTTP_DATE.parse(retry_after)
            delay = (retry_time - Time.utc).total_seconds
            return delay.clamp(0.0, @max_retry_delay).seconds
          rescue Time::Format::Error
          end
        end
      end

      # Ruby SDK formula: initial_delay * retry_count² * jitter
      # jitter is between 0.75 and 1.0 (1 - 0.25 * rand)
      scale = (attempt + 1) ** 2
      jitter = 1.0 - (0.25 * rand)
      delay = @initial_retry_delay * scale * jitter

      # Clamp to max delay
      delay.clamp(0.0, @max_retry_delay).seconds
    end
  end

  # Request header selecting the Workspace a request runs under.
  WORKSPACE_ID_HEADER = "anthropic-workspace-id"

  # Request header selecting the User Profile a request runs under.
  USER_PROFILE_ID_HEADER = "anthropic-user-profile-id"

  # Request header identifying the worker polling a self-hosted
  # environment work queue.
  WORKER_ID_HEADER = "anthropic-worker-id"

  # Validate a single URL path segment against empty strings, dot-segments,
  # and matrix parameter dot-segments (`.`, `..`, `%2e`, `;`, `.;`, `..;`).
  def self.validate_path_segment!(value : String) : String
    raise ArgumentError.new("Path segment cannot be empty") if value.empty?

    normalized = value.gsub(/%2e/i, ".").gsub(/%3b/i, ";")
    if value.starts_with?(';') || normalized.starts_with?(';')
      raise ArgumentError.new("Invalid path segment: #{value.inspect}")
    end

    head = normalized.split(';', 2).first
    if head == "." || head == ".."
      raise ArgumentError.new("Invalid path segment: #{value.inspect}")
    end

    value
  end

  # Validate and URL-encode a single URL path segment.
  def self.encode_path_segment(value : String) : String
    validate_path_segment!(value)
    URI.encode_path_segment(value)
  end

  # Merge an `anthropic-workspace-id` request header into an existing
  # header hash. Centralized so every resource sets the header the same
  # way; `nil` leaves the headers untouched.
  def self.merge_workspace_header(headers : Hash(String, String)?, workspace_id : String?) : Hash(String, String)?
    return headers if workspace_id.nil?
    (headers || {} of String => String).merge({WORKSPACE_ID_HEADER => workspace_id})
  end
end
