module Anthropic
  class Client
    DEFAULT_BASE_URL      = "https://api.anthropic.com"
    API_VERSION           = "2023-06-01"
    DEFAULT_MAX_RETRIES   =   2
    DEFAULT_INITIAL_DELAY = 0.5 # seconds
    DEFAULT_MAX_DELAY     = 8.0 # seconds

    @api_key : String
    @base_url : String
    @timeout : Time::Span
    @max_retries : Int32
    @initial_retry_delay : Float64
    @max_retry_delay : Float64
    @default_headers : Hash(String, String)

    def initialize(
      api_key : String? = nil,
      base_url : String = DEFAULT_BASE_URL,
      timeout : Time::Span = 600.seconds,
      max_retries : Int32 = DEFAULT_MAX_RETRIES,
      initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
      max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
      default_headers : Hash(String, String) = {} of String => String,
    )
      @api_key = api_key || ENV["ANTHROPIC_API_KEY"]? || raise ArgumentError.new(
        "API key required. Set ANTHROPIC_API_KEY environment variable or pass api_key parameter."
      )
      @base_url = base_url.rstrip('/')
      @timeout = timeout
      @max_retries = max_retries
      @initial_retry_delay = initial_retry_delay
      @max_retry_delay = max_retry_delay
      @default_headers = default_headers
    end

    # Resource accessors
    def messages : Messages
      Messages.new(self)
    end

    def models : Models
      Models.new(self)
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
      full_path = if params && !params.empty?
                    separator = path.includes?('?') ? '&' : '?'
                    "#{path}#{separator}#{encode_query_params(params)}"
                  else
                    path
                  end
      request("GET", full_path, nil, extra_headers)
    end

    # POST with any JSON::Serializable body
    def post(path : String, body, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      request("POST", path, body.to_json, extra_headers)
    end

    def delete(path : String, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      request("DELETE", path, nil, extra_headers)
    end

    # POST with streaming response
    def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
      uri = URI.parse(@base_url)

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

        begin
          client.post(path, headers: headers(extra_headers, method: "POST"), body: body.to_json) do |response|
            handle_error(response) unless response.success?
            yield response
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Stream read timed out", cause: ex)
        rescue ex : IO::Error | Socket::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end
    end

    def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
      uri = URI.parse(@base_url)

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

        begin
          client.get(path, headers: headers(extra_headers, method: "GET")) do |response|
            handle_error(response) unless response.success?
            yield response
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Stream read timed out", cause: ex)
        rescue ex : IO::Error | Socket::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end
    end

    # GET request returning raw response body (for binary downloads)
    def get_raw(path : String, extra_headers : Hash(String, String)? = nil) : IO::Memory
      uri = URI.parse(@base_url)
      io = IO::Memory.new

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

        # Don't set content-type for downloads
        hdrs = headers(extra_headers, content_type: nil, method: "GET")

        response = client.get(path, headers: hdrs)
        handle_error(response) unless response.success?
        io.write(response.body.to_slice)
        io.rewind
      end

      io
    end

    # POST multipart form data (for file uploads)
    def post_multipart(
      path : String,
      file : IO,
      filename : String,
      content_type : String = "application/octet-stream",
      extra_headers : Hash(String, String)? = nil,
    ) : HTTP::Client::Response
      uri = URI.parse(@base_url)

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

        # Build multipart body using Crystal's standard FormData builder
        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)

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
    end

    # POST multipart form data with multiple files and optional form fields
    def post_multipart_files(
      path : String,
      files : Array(FileUpload),
      form_fields : Hash(String, String)? = nil,
      extra_headers : Hash(String, String)? = nil,
    ) : HTTP::Client::Response
      uri = URI.parse(@base_url)

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

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
    end

    private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      uri = URI.parse(@base_url)
      response = nil
      req_headers = headers(extra_headers, method: method)

      (@max_retries + 1).times do |attempt|
        begin
          HTTP::Client.new(uri) do |client|
            client.connect_timeout = @timeout
            client.read_timeout = @timeout

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
          raise APITimeoutError.new("Request timed out") if attempt >= @max_retries
        rescue ex : IO::Error | Socket::Error
          raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex) if attempt >= @max_retries
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

    private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
      HTTP::Headers{
        "x-api-key"         => @api_key,
        "anthropic-version" => API_VERSION,
        "user-agent"        => "anthropic-crystal/#{VERSION}",
      }.tap do |hdrs|
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
end
