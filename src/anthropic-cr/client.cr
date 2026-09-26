require "base64"
require "http/client"
require "openssl"
require "socket"
require "uri"

module Anthropic
  class Client
    DEFAULT_BASE_URL      = "https://api.anthropic.com"
    API_VERSION           = "2023-06-01"
    DEFAULT_MAX_RETRIES   =   2
    DEFAULT_INITIAL_DELAY = 0.5 # seconds
    DEFAULT_MAX_DELAY     = 8.0 # seconds

    @api_key : String?
    @auth_token : String?
    @base_url : String
    @timeout : Time::Span
    @max_retries : Int32
    @initial_retry_delay : Float64
    @max_retry_delay : Float64
    @default_headers : Hash(String, String)
    @default_query : Hash(String, String)
    @middleware : Array(Middleware)
    @proxy : String?

    def initialize(
      api_key : String? = nil,
      auth_token : String? = nil,
      base_url : String? = nil,
      timeout : Time::Span = 600.seconds,
      max_retries : Int32 = DEFAULT_MAX_RETRIES,
      initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
      max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
      default_headers : Hash(String, String) = {} of String => String,
      default_query : Hash(String, String) = {} of String => String,
      middleware : Array(Middleware) = [] of Middleware,
      webhook_key : String? = nil,
      proxy : String? = nil,
    )
      # An explicit credential argument disables env-var lookup, matching
      # the Python and Ruby SDKs: pass one credential and no other source
      # is consulted. (TypeScript falls back per field instead.)
      if api_key || auth_token
        @api_key = api_key
        @auth_token = auth_token
      else
        @api_key = ENV["ANTHROPIC_API_KEY"]?
        @auth_token = ENV["ANTHROPIC_AUTH_TOKEN"]?
      end
      unless @api_key || @auth_token
        raise ArgumentError.new(
          "API key or auth token required. Set ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN environment variables, or pass api_key/auth_token parameters."
        )
      end
      @base_url = (base_url || ENV["ANTHROPIC_BASE_URL"]? || DEFAULT_BASE_URL).rstrip('/')
      @timeout = timeout
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
      timeout : Time::Span? = nil,
      max_retries : Int32? = nil,
      extra_headers : Hash(String, String)? = nil,
      extra_query : Hash(String, String)? = nil,
      middleware : Array(Middleware)? = nil,
      api_key : String? = nil,
      auth_token : String? = nil,
      base_url : String? = nil,
      proxy : String? = nil,
    ) : Client
      copy = dup
      copy.middleware = middleware ? middleware.map(&.as(Middleware)) : @middleware.dup
      copy.timeout = timeout if timeout
      copy.max_retries = max_retries if max_retries
      copy.default_headers = @default_headers.merge(extra_headers || {} of String => String)
      copy.default_query = @default_query.merge(extra_query || {} of String => String)
      copy.api_key = api_key if api_key
      copy.auth_token = auth_token if auth_token
      copy.base_url = base_url.rstrip('/') if base_url
      copy.proxy = proxy if proxy
      copy
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

    protected setter timeout : Time::Span
    protected setter max_retries : Int32
    protected setter default_headers : Hash(String, String)
    protected setter default_query : Hash(String, String)
    protected setter middleware : Array(Middleware)
    protected setter api_key : String?
    protected setter auth_token : String?
    protected setter base_url : String
    protected setter proxy : String?

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

    # [Legacy] Text Completions API.
    #
    # ```
    # completion = client.completions.create(
    #   model: "claude-haiku-4-5-20251001",
    #   prompt: "\n\nHuman: Hello!\n\nAssistant:",
    #   max_tokens_to_sample: 256
    # )
    # ```
    def completions : Completions
      Completions.new(self)
    end

    # Beta namespace for beta features
    #
    # ```
    # client.beta.messages.create(
    #   betas: ["structured-outputs-2025-12-15"],
    #   ...
    # )
    # ```
    def beta : Beta
      Beta.new(self)
    end

    # HTTP methods
    alias QueryParams = Hash(String, String) | Hash(String, String | Array(String))

    def get(path : String, params : QueryParams? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      request("GET", path, nil, extra_headers, query: params)
    end

    # POST with any JSON::Serializable body
    def post(path : String, body, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      body_str = body.nil? ? "{}" : body.to_json
      request("POST", path, body_str, extra_headers)
    end

    def delete(path : String, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      request("DELETE", path, nil, extra_headers)
    end

    # POST with streaming response
    def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri) do |client|
        begin
          body_str = body.nil? ? "{}" : body.to_json
          client.post(path, headers: headers(extra_headers, method: "POST"), body: body_str) do |response|
            handle_error(response) unless response.success?
            yield response
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Stream read timed out", cause: ex)
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end
    end

    def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri) do |client|
        begin
          client.get(path, headers: headers(extra_headers, method: "GET")) do |response|
            handle_error(response) unless response.success?
            yield response
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Stream read timed out", cause: ex)
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end
    end

    # GET request returning raw response body (for binary downloads)
    def get_raw(path : String, extra_headers : Hash(String, String)? = nil) : IO::Memory
      uri = URI.parse(@base_url)
      path = apply_default_query(path)
      io = IO::Memory.new

      with_http_client(uri) do |client|
        # Don't set content-type for downloads
        hdrs = headers(extra_headers, content_type: nil, method: "GET")

        response = client.get(path, headers: hdrs)
        handle_error(response) unless response.success?
        io.write(response.body.to_slice)
        io.rewind
      end

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
      filename : String,
      content_type : String = "application/octet-stream",
      extra_headers : Hash(String, String)? = nil,
      form_fields : Hash(String, String)? = nil,
    ) : HTTP::Client::Response
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri) do |client|
        # Build multipart body using Crystal's standard FormData builder
        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)

        form_fields.try &.each do |name, value|
          builder.field(name, value)
        end

        metadata = HTTP::FormData::FileMetadata.new(filename: filename)
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
      uri = URI.parse(@base_url)
      path = apply_default_query(path)

      with_http_client(uri) do |client|
        # Build multipart body using Crystal's FormData builder
        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)

        # Form fields
        form_fields.try &.each do |name, value|
          builder.field(name, value)
        end

        # File parts
        files.each do |file|
          metadata = HTTP::FormData::FileMetadata.new(filename: file.filename)
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

    private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil, query : QueryParams? = nil) : HTTP::Client::Response
      uri = URI.parse(@base_url)
      path = append_query_params(path, merge_query(query))
      req_headers = headers(extra_headers, method: method)

      # Fast path: no middleware — send directly with the existing retry loop.
      return request_direct(method, path, body, uri, req_headers) if @middleware.empty?

      # Middleware path: compose a chain around the terminal HTTP send. The
      # chain runs once per attempt inside the retry loop. The terminal returns
      # an APIResponse for every status (4xx/5xx do not raise); connection
      # errors do raise. Typed error raising happens after the chain returns.
      api_request = APIRequest.new(method, path, req_headers, body)

      response = nil
      (@max_retries + 1).times do |attempt|
        begin
          api_response = invoke_chain(api_request, uri)
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
    private def request_direct(method : String, path : String, body : String?, uri : URI, req_headers : HTTP::Headers) : HTTP::Client::Response
      response = nil
      (@max_retries + 1).times do |attempt|
        begin
          with_http_client(uri) do |client|
            response = case method
                       when "GET"    then client.get(path, headers: req_headers)
                       when "POST"   then client.post(path, headers: req_headers, body: body)
                       when "DELETE" then client.delete(path, headers: req_headers)
                       else               raise "Unknown HTTP method: #{method}"
                       end

            # Check if we should retry (respects x-should-retry header)
            if response.success? || !should_retry?(response)
              handle_error(response) unless response.success?
              return response
            end
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
    private def invoke_chain(api_request : APIRequest, uri : URI) : APIResponse
      terminal = MiddlewareNext.new do |req|
        send_terminal(req, uri)
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
    private def send_terminal(api_request : APIRequest, uri : URI) : APIResponse
      with_http_client(uri) do |client|
        http_response = case api_request.method
                        when "GET"    then client.get(api_request.path, headers: api_request.headers)
                        when "POST"   then client.post(api_request.path, headers: api_request.headers, body: api_request.body)
                        when "DELETE" then client.delete(api_request.path, headers: api_request.headers)
                        else               raise "Unknown HTTP method: #{api_request.method}"
                        end

        APIResponse.new(http_response.status_code, http_response.headers, http_response.body, api_request)
      end
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
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
        case value
        when Array
          value.each { |item| query.add(key, item) }
        else
          query.add(key, value)
        end
      end

      query.to_s
    end

    # Merge default query params under per-request params: an explicit
    # per-request key wins over the default instead of sending both.
    private def merge_query(query : QueryParams?) : Hash(String, String | Array(String))
      merged = {} of String => String | Array(String)
      @default_query.each { |key, value| merged[key] = value }
      if query
        query.each { |key, value| merged[key] = value }
      end
      merged
    end

    private def append_query_params(path : String, query : Hash(String, String | Array(String))) : String
      return path if query.empty?

      separator = path.includes?('?') ? '&' : '?'
      "#{path}#{separator}#{encode_query_params(query)}"
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
    private def with_http_client(uri : URI, & : HTTP::Client -> T) : T forall T
      proxy_uri = proxy_for_uri(uri)

      unless proxy_uri
        return HTTP::Client.new(uri) do |client|
          client.connect_timeout = @timeout
          client.read_timeout = @timeout
          yield client
        end
      end

      socket = open_proxy_tunnel(uri, proxy_uri)
      begin
        tls = OpenSSL::SSL::Socket::Client.new(socket, sync_close: true, hostname: uri.host)
        client = HTTP::Client.new(tls, uri.host || "", uri.port || 443)
        client.connect_timeout = @timeout
        client.read_timeout = @timeout
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
    private def open_proxy_tunnel(uri : URI, proxy_uri : URI) : TCPSocket
      host = proxy_uri.host
      if host.nil? || host.empty?
        raise ArgumentError.new("Invalid proxy URL (missing host): #{proxy_uri}")
      end
      port = proxy_uri.port || (proxy_uri.scheme == "https" ? 443 : 80)

      socket = TCPSocket.new(host, port, connect_timeout: @timeout)
      socket.read_timeout = @timeout

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

    private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
      HTTP::Headers{
        "anthropic-version" => API_VERSION,
        "user-agent"        => "anthropic-crystal/#{VERSION}",
      }.tap do |hdrs|
        if api_key = @api_key
          hdrs["x-api-key"] = api_key
        elsif auth_token = @auth_token
          hdrs["authorization"] = "Bearer #{auth_token}"
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
      status = response.status_code
      body = response.body
      headers = response.headers

      message, error_type = parse_error_payload(body)

      error = case status
              when 400 then BadRequestError.new(message, status, body, headers, error_type)
              when 401 then AuthenticationError.new(message, status, body, headers, error_type)
              when 403 then PermissionDeniedError.new(message, status, body, headers, error_type)
              when 404 then NotFoundError.new(message, status, body, headers, error_type)
              when 409 then ConflictError.new(message, status, body, headers, error_type)
              when 413 then PayloadTooLargeError.new(message, status, body, headers, error_type)
              when 422 then UnprocessableEntityError.new(message, status, body, headers, error_type)
              when 429
                retry_after = headers["retry-after"]?.try(&.to_i)
                RateLimitError.new(message, status, body, headers, error_type, retry_after)
              when 504 then GatewayTimeoutError.new(message, status, body, headers, error_type)
              when 529 then OverloadedError.new(message, status, body, headers, error_type)
              else
                status >= 500 ? InternalServerError.new(message, status, body, headers, error_type) : APIError.new(message, status, body, headers, error_type)
              end

      raise error
    end

    # Parse the error envelope from a response body, returning a tuple of
    # `{message, error_type}`. Tolerates empty bodies, non-JSON bodies, and
    # bodies that are valid JSON but don't follow the Anthropic envelope.
    private def parse_error_payload(body : String) : {String, String?}
      return {"", nil} if body.empty?

      begin
        json = JSON.parse(body)
        error = json["error"]?
        if error.nil?
          {body, nil}
        else
          message = error["message"]?.try(&.as_s?) || body
          error_type = error["type"]?.try(&.as_s?)
          {message, error_type}
        end
      rescue JSON::ParseException
        {body, nil}
      end
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

  # Request header identifying the worker polling a self-hosted
  # environment work queue.
  WORKER_ID_HEADER = "anthropic-worker-id"

  # Merge an `anthropic-workspace-id` request header into an existing
  # header hash. Centralized so every resource sets the header the same
  # way; `nil` leaves the headers untouched.
  def self.merge_workspace_header(headers : Hash(String, String)?, workspace_id : String?) : Hash(String, String)?
    return headers if workspace_id.nil?
    (headers || {} of String => String).merge({WORKSPACE_ID_HEADER => workspace_id})
  end
end
