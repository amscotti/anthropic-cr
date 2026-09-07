module Anthropic
  module AWS
    # Anthropic models via the AWS gateway — the full first-party API
    # served through `aws-external-anthropic`.
    #
    # Unlike `Anthropic::Bedrock::Client` (Bedrock Runtime invoke API),
    # requests pass through unchanged: standard `/v1/*` paths, standard
    # model names, the complete API surface.
    #
    # Credentials resolve in priority order:
    # 1. `api_key` (or `ANTHROPIC_AWS_API_KEY`) → API-key mode
    #    (`x-api-key` header, no SigV4),
    # 2. explicit `aws_access_key`/`aws_secret_key`/`aws_session_token`/`aws_profile`,
    # 3. the default AWS chain (env → shared config → SSO/login cache → IMDS)
    #    via `Bedrock::CredentialsResolver`.
    #
    # ```
    # client = Anthropic::AWS::Client.new(aws_region: "us-east-1")
    #
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_5,
    #   max_tokens: 256,
    #   messages: [{role: "user", content: "Hello from AWS!"}],
    # )
    # ```
    class Client < Anthropic::Client
      SERVICE = "aws-external-anthropic"

      getter aws_region : String?
      getter workspace_id : String?
      getter? skip_auth : Bool

      @credentials : Bedrock::Credentials?
      @gateway_api_key : String?

      def initialize(
        api_key : String? = nil,
        aws_access_key : String? = nil,
        aws_secret_key : String? = nil,
        aws_session_token : String? = nil,
        aws_profile : String? = nil,
        aws_region : String? = nil,
        workspace_id : String? = nil,
        skip_auth : Bool = false,
        base_url : String? = nil,
        timeout : Time::Span = 600.seconds,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
      )
        @skip_auth = skip_auth

        gateway_key = api_key || ENV["ANTHROPIC_AWS_API_KEY"]?
        @gateway_api_key, @credentials, @aws_region = self.class.resolve_auth(
          api_key: api_key,
          env_api_key: ENV["ANTHROPIC_AWS_API_KEY"]?,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_profile: aws_profile,
          aws_region: aws_region,
          skip_auth: skip_auth
        )
        @workspace_id = workspace_id || ENV["ANTHROPIC_AWS_WORKSPACE_ID"]?

        resolved_base = base_url || ENV["ANTHROPIC_AWS_BASE_URL"]? || self.class.default_base_url(@aws_region)

        # Parent requires an api_key string; gateway auth is handled in
        # #headers/#request, so a placeholder is never sent.
        super(
          api_key: gateway_key || "aws",
          base_url: resolved_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          middleware: middleware,
        )
      end

      def self.default_base_url(region : String?) : String
        if region.nil? || region.empty?
          raise ArgumentError.new(
            "No AWS region was given and the base URL cannot be derived. Set the " \
            "`aws_region` argument or pass `base_url` explicitly."
          )
        end
        "https://aws-external-anthropic.#{region}.api.aws"
      end

      # Resolve the auth mode: API key, SigV4 credentials, or nothing when
      # `skip_auth` is set. Returns `{gateway_key, credentials, region}`.
      # An explicit `api_key` always wins (API-key mode); the
      # `ANTHROPIC_AWS_API_KEY` env key applies only without platform args.
      # Internal constructor helper; not part of the public API.
      def self.resolve_auth(
        api_key : String?,
        env_api_key : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
        aws_region : String?,
        skip_auth : Bool,
      ) : {String?, Bedrock::Credentials?, String?}
        has_platform_auth = !aws_access_key.nil? || !aws_secret_key.nil? ||
                            !aws_session_token.nil? || !aws_profile.nil?
        env_region = aws_region || ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]?

        return {nil, nil, env_region} if skip_auth
        return {api_key, nil, env_region} if api_key
        return {env_api_key, nil, env_region} if env_api_key && !has_platform_auth

        region = env_region
        if region.nil? || region.empty?
          raise ArgumentError.new(
            "No AWS region was given. The client should be instantiated with the " \
            "`aws_region` argument or the `AWS_REGION`/`AWS_DEFAULT_REGION` environment variables should be set."
          )
        end

        credentials = Bedrock::CredentialsResolver.resolve(
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_region: region,
          aws_profile: aws_profile,
        )
        {nil, credentials, region}
      end

      # Whether requests are API-key authenticated (vs SigV4).
      def api_key_mode? : Bool
        !@gateway_api_key.nil?
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (aws)",
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          if api_key = @gateway_api_key
            hdrs["x-api-key"] = api_key
          end
          if workspace = @workspace_id
            hdrs[WORKSPACE_ID_HEADER] = workspace
          end
          @default_headers.each { |key, value| hdrs[key] = value }
          extra_headers.try &.each { |key, value| hdrs[key] = value }

          if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) &&
             !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
            hdrs["idempotency-key"] = UUID.random.to_s
          end
        end
      end

      # Sign SigV4 requests (API-key and skip-auth modes pass through).
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        method_u = method.upcase
        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: method_u)

        if creds = @credentials
          full_url = "#{@base_url}#{path}"
          signed = Bedrock::SigV4.sign(creds, method_u, full_url, req_headers, body, service: SERVICE)
          signed.each { |key, value| req_headers[key] = value }
        end

        return request_direct(method_u, path, body, uri, req_headers) if @middleware.empty?

        api_request = APIRequest.new(method_u, path, req_headers, body)
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

      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        body_str = body.nil? ? "{}" : body.to_json

        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: "POST")

        if creds = @credentials
          full_url = "#{@base_url}#{path}"
          signed = Bedrock::SigV4.sign(creds, "POST", full_url, req_headers, body_str, service: SERVICE)
          signed.each { |key, value| req_headers[key] = value }
        end

        HTTP::Client.new(uri) do |client|
          client.connect_timeout = @timeout
          client.read_timeout = @timeout

          begin
            client.post(path, headers: req_headers, body: body_str) do |response|
              unless response.success?
                error_body = response.body_io?.try(&.gets_to_end) || response.body
                handle_error(HTTP::Client::Response.new(
                  response.status_code,
                  body: error_body,
                  headers: response.headers,
                ))
              end
              yield response
            end
          rescue ex : IO::TimeoutError
            raise APITimeoutError.new("Stream read timed out", cause: ex)
          rescue ex : IO::Error | Socket::Error
            raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
          end
        end
      end
    end
  end
end
