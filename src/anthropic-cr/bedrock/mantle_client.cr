module Anthropic
  module Bedrock
    # Anthropic Messages client that targets Amazon Bedrock Mantle.
    #
    # Unlike `Anthropic::Bedrock::Client` (Bedrock Runtime), Mantle uses native
    # Anthropic paths (`/v1/messages`) and does not rewrite the request body.
    # Auth is SigV4 with service name `bedrock-mantle`, or a Bedrock bearer token.
    #
    # ```
    # client = Anthropic::Bedrock::MantleClient.new(
    #   aws_profile: "anthropic-cr-bedrock",
    #   aws_region: "us-east-1",
    # )
    #
    # message = client.messages.create(
    #   model: "claude-haiku-4-5-20251001",
    #   max_tokens: 256,
    #   messages: [{role: "user", content: "Hello from Mantle!"}],
    # )
    # puts message.text
    # ```
    #
    # Only `messages` and `beta.messages` are supported. Models, batches, files,
    # and other resources raise `NotImplementedError`.
    class MantleClient < Anthropic::Client
      SERVICE_NAME = "bedrock-mantle"

      getter aws_region : String?
      getter? use_sig_v4 : Bool
      getter? skip_auth : Bool

      @credentials : Credentials?
      @bearer_token : String?
      # Path component of the Mantle base URL (e.g. "/anthropic"). Crystal's
      # HTTP::Client only uses host/port from the URI, so we prepend this to
      # every request path so the wire path is `/anthropic/v1/messages`.
      @path_prefix : String

      # Create a Bedrock Mantle client.
      #
      # Auth precedence (matches official SDKs):
      # 1. `api_key` constructor arg → Bearer mode
      # 2. Explicit AWS credentials / `aws_profile` → SigV4 (`bedrock-mantle`)
      # 3. `AWS_BEARER_TOKEN_BEDROCK` or `ANTHROPIC_AWS_API_KEY` → Bearer mode
      # 4. Default AWS credential chain → SigV4
      #
      # Base URL: `ANTHROPIC_BEDROCK_MANTLE_BASE_URL`, else
      # `https://bedrock-mantle.{region}.api.aws/anthropic`.
      def initialize(
        aws_access_key : String? = nil,
        aws_secret_key : String? = nil,
        aws_session_token : String? = nil,
        aws_region : String? = nil,
        aws_profile : String? = nil,
        api_key : String? = nil,
        skip_auth : Bool = false,
        base_url : String? = nil,
        timeout : Time::Span = 600.seconds,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
      )
        if aws_access_key.nil? != aws_secret_key.nil?
          raise ArgumentError.new(
            "`aws_access_key` and `aws_secret_key` must be provided together. " \
            "You provided only one."
          )
        end

        @skip_auth = skip_auth
        resolved_region = aws_region || ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]?

        if skip_auth
          @use_sig_v4 = false
          @bearer_token = nil
          @credentials = nil
          @aws_region = resolved_region
        else
          use_sig_v4, bearer_token, credentials, region =
            resolve_auth(
              api_key: api_key,
              aws_access_key: aws_access_key,
              aws_secret_key: aws_secret_key,
              aws_session_token: aws_session_token,
              aws_region: aws_region,
              aws_profile: aws_profile,
              resolved_region: resolved_region,
            )
          @use_sig_v4 = use_sig_v4
          @bearer_token = bearer_token
          @credentials = credentials
          @aws_region = region
        end

        resolved_base = base_url || ENV["ANTHROPIC_BEDROCK_MANTLE_BASE_URL"]?
        if resolved_base.nil?
          region_for_url = @aws_region
          if region_for_url.nil? || region_for_url.empty?
            raise ArgumentError.new(
              "No AWS region or base URL found. Set `aws_region` in the constructor, " \
              "the `AWS_REGION` / `AWS_DEFAULT_REGION` environment variable, or provide " \
              "a `base_url` / `ANTHROPIC_BEDROCK_MANTLE_BASE_URL` environment variable."
            )
          end
          resolved_base = "https://bedrock-mantle.#{region_for_url}.api.aws/anthropic"
        end

        host_base, @path_prefix = split_base_url(resolved_base)

        # Parent requires an api_key string; Mantle auth is handled in #headers / SigV4.
        # Pass host-only base URL — path prefix is applied in #request / #post_stream.
        super(
          api_key: @bearer_token || "bedrock-mantle",
          base_url: host_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          middleware: middleware,
        )
      end

      # Models listing is not supported on Bedrock Mantle.
      def models : Models
        raise NotImplementedError.new(
          "Models listing is not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      # Restricted beta surface: messages only.
      def beta : MantleBeta
        MantleBeta.new(self)
      end

      # Mantle returns native SSE — stream via the standard Anthropic event path
      # with Mantle auth (SigV4 or Bearer) applied.
      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        validate_mantle_path!(path)

        req_path = with_path_prefix(path)
        uri = URI.parse(@base_url)
        body_str = body.nil? ? "{}" : body.to_json
        req_headers = headers(extra_headers, method: "POST")
        apply_sig_v4!(req_headers, "POST", req_path, body_str)

        HTTP::Client.new(uri) do |client|
          client.connect_timeout = @timeout
          client.read_timeout = @timeout

          begin
            client.post(req_path, headers: req_headers, body: body_str) do |response|
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

      # Returns {use_sig_v4, bearer_token, credentials, region}.
      private def resolve_auth(
        api_key : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_region : String?,
        aws_profile : String?,
        resolved_region : String?,
      ) : {Bool, String?, Credentials?, String?}
        has_explicit_api_key = !api_key.nil?
        has_explicit_aws = !aws_access_key.nil?
        has_aws_profile = !aws_profile.nil?
        env_bearer = ENV["AWS_BEARER_TOKEN_BEDROCK"]? || ENV["ANTHROPIC_AWS_API_KEY"]?

        if has_explicit_api_key
          {false, api_key, nil, resolved_region}
        elsif has_explicit_aws || has_aws_profile
          creds = CredentialsResolver.resolve(
            aws_access_key: aws_access_key,
            aws_secret_key: aws_secret_key,
            aws_session_token: aws_session_token,
            aws_region: aws_region,
            aws_profile: aws_profile,
          )
          {true, nil, creds, creds.region}
        elsif env_bearer
          {false, env_bearer, nil, resolved_region}
        else
          creds = CredentialsResolver.resolve(
            aws_access_key: aws_access_key,
            aws_secret_key: aws_secret_key,
            aws_session_token: aws_session_token,
            aws_region: aws_region,
            aws_profile: aws_profile,
          )
          {true, nil, creds, creds.region}
        end
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        # Do not send x-api-key; Mantle uses SigV4 or a Bearer token.
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (bedrock-mantle)",
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          unless skip_auth?
            if bearer = @bearer_token
              hdrs["authorization"] = "Bearer #{bearer}"
            end
          end
          @default_headers.each { |key, value| hdrs[key] = value }
          extra_headers.try &.each { |key, value| hdrs[key] = value }

          if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) &&
             !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
            hdrs["idempotency-key"] = UUID.random.to_s
          end
        end
      end

      # Override request: native Anthropic paths + Mantle auth (no invoke rewrite).
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        validate_mantle_path!(path)

        method_u = method.upcase
        req_path = with_path_prefix(path)
        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: method_u)
        apply_sig_v4!(req_headers, method_u, req_path, body)

        return request_direct(method_u, req_path, body, uri, req_headers) if @middleware.empty?

        api_request = APIRequest.new(method_u, req_path, req_headers, body)
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

      private def apply_sig_v4!(req_headers : HTTP::Headers, method : String, path : String, body : String?) : Nil
        return if skip_auth? || !use_sig_v4?

        creds = @credentials || raise ArgumentError.new("Missing AWS credentials for SigV4")
        full_url = "#{@base_url}#{path}"
        signed = SigV4.sign(creds, method, full_url, req_headers, body, service: SERVICE_NAME)
        signed.each { |key, value| req_headers[key] = value }
      end

      # Split `https://host/path` into host base URL + path prefix.
      private def split_base_url(url : String) : {String, String}
        uri = URI.parse(url.rstrip('/'))
        host = uri.host || raise ArgumentError.new("base_url missing host: #{url}")
        scheme = uri.scheme || "https"
        port = uri.port
        host_base = if port && !((scheme == "https" && port == 443) || (scheme == "http" && port == 80))
                      "#{scheme}://#{host}:#{port}"
                    else
                      "#{scheme}://#{host}"
                    end
        prefix = uri.path.rstrip('/')
        {host_base, prefix}
      end

      private def with_path_prefix(path : String) : String
        return path if @path_prefix.empty?
        "#{@path_prefix}#{path}"
      end

      private def validate_mantle_path!(path : String) : Nil
        if path.includes?("/v1/messages/batches")
          raise NotImplementedError.new(
            "The Batch API is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
        if path.includes?("count_tokens")
          raise NotImplementedError.new(
            "Token counting is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
        if path.includes?("/v1/models")
          raise NotImplementedError.new(
            "Models listing is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
        if path.includes?("/v1/files") || path.includes?("/v1/skills")
          raise NotImplementedError.new(
            "This endpoint is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
      end
    end

    # Restricted Beta service that only exposes messages.
    class MantleBeta
      def initialize(@client : MantleClient)
      end

      def messages : BetaMessages
        BetaMessages.new(@client)
      end

      def models
        raise NotImplementedError.new(
          "Beta models are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def files
        raise NotImplementedError.new(
          "Beta files are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def skills
        raise NotImplementedError.new(
          "Beta skills are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def user_profiles
        raise NotImplementedError.new(
          "Beta user profiles are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def environments
        raise NotImplementedError.new(
          "Beta environments are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def memory_stores
        raise NotImplementedError.new(
          "Beta memory stores are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def sessions
        raise NotImplementedError.new(
          "Beta sessions are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def agents
        raise NotImplementedError.new(
          "Beta agents are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def vaults
        raise NotImplementedError.new(
          "Beta vaults are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def deployments
        raise NotImplementedError.new(
          "Beta deployments are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def dreams
        raise NotImplementedError.new(
          "Beta dreams are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def tunnels
        raise NotImplementedError.new(
          "Beta tunnels are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end
    end
  end
end
