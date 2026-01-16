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
    #   betas: ["structured-outputs-2025-11-13"],
    #   ...
    # )
    # ```
    def beta : Beta
      Beta.new(self)
    end

    # HTTP methods
    def get(path : String, params : Hash(String, String)? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      full_path = if params && !params.empty?
                    "#{path}?#{URI::Params.encode(params)}"
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

        client.post(path, headers: headers(extra_headers), body: body.to_json) do |response|
          handle_error(response) unless response.success?
          yield response
        end
      end
    end

    def get_stream(path : String, &)
      uri = URI.parse(@base_url)

      HTTP::Client.new(uri) do |client|
        client.connect_timeout = @timeout
        client.read_timeout = @timeout

        client.get(path, headers: headers) do |response|
          handle_error(response) unless response.success?
          yield response
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
        hdrs = HTTP::Headers{
          "x-api-key"         => @api_key,
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION}",
        }
        @default_headers.each { |key, value| hdrs[key] = value }
        extra_headers.try &.each { |key, value| hdrs[key] = value }

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

        # Build multipart body
        io = IO::Memory.new
        boundary = "----AnthropicCrystalSDK#{Random.new.hex(16)}"

        # File part
        io << "--#{boundary}\r\n"
        io << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
        io << "Content-Type: #{content_type}\r\n"
        io << "\r\n"
        IO.copy(file, io)
        io << "\r\n"
        io << "--#{boundary}--\r\n"

        # Headers for multipart
        hdrs = HTTP::Headers{
          "x-api-key"         => @api_key,
          "anthropic-version" => API_VERSION,
          "content-type"      => "multipart/form-data; boundary=#{boundary}",
          "user-agent"        => "anthropic-crystal/#{VERSION}",
        }
        @default_headers.each { |key, value| hdrs[key] = value }
        extra_headers.try &.each { |key, value| hdrs[key] = value }

        response = client.post(path, headers: hdrs, body: io.to_s)
        handle_error(response) unless response.success?
        return response
      end

      raise APIError.new("Request failed")
    end

    private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
      uri = URI.parse(@base_url)
      response = nil
      req_headers = headers(extra_headers)

      (@max_retries + 1).times do |attempt|
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
    rescue ex : IO::Error | Socket::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out")
    end

    private def headers(extra_headers : Hash(String, String)? = nil) : HTTP::Headers
      HTTP::Headers{
        "x-api-key"         => @api_key,
        "anthropic-version" => API_VERSION,
        "content-type"      => "application/json",
        "user-agent"        => "anthropic-crystal/#{VERSION}",
      }.tap do |headers|
        @default_headers.each { |key, value| headers[key] = value }
        extra_headers.try &.each { |key, value| headers[key] = value }
      end
    end

    private def handle_error(response : HTTP::Client::Response)
      status = response.status_code
      body = response.body
      headers = response.headers

      message = begin
        json = JSON.parse(body)
        json["error"]?.try(&.["message"]?.try(&.as_s)) || body
      rescue
        body
      end

      error = case status
              when 400 then BadRequestError.new(message, status, body, headers)
              when 401 then AuthenticationError.new(message, status, body, headers)
              when 403 then PermissionDeniedError.new(message, status, body, headers)
              when 404 then NotFoundError.new(message, status, body, headers)
              when 409 then ConflictError.new(message, status, body, headers)
              when 422 then UnprocessableEntityError.new(message, status, body, headers)
              when 429
                retry_after = headers["retry-after"]?.try(&.to_i)
                RateLimitError.new(message, status, body, headers, retry_after)
              else
                status >= 500 ? InternalServerError.new(message, status, body, headers) : APIError.new(message, status, body, headers)
              end

      raise error
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
      status == 408 || status == 409 || status == 429 || status >= 500
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
          # Could also parse HTTP date format, but numeric is more common
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
