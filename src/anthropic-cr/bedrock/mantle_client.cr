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
    # Only `messages` (including `count_tokens`) and `beta.messages` are supported.
    # Models, batches, files, skills, user profiles, and other resources raise
    # `NotImplementedError`.
    class MantleClient < Anthropic::Client
      SERVICE_NAME            = "bedrock-mantle"
      USER_PROFILE_BODY_PATHS = {"/v1/messages", "/v1/messages/count_tokens"}

      getter aws_region : String?
      getter aws_access_key : String?
      getter aws_secret_key : String?
      getter aws_session_token : String?
      getter aws_profile : String?
      getter? use_sig_v4 : Bool
      getter? skip_auth : Bool

      @credentials : Credentials?
      @bearer_token : String?
      # Path component of the Mantle base URL (e.g. "/anthropic"). Crystal's
      # HTTP::Client only uses host/port from the URI, so we prepend this to
      # every request path so the wire path is `/anthropic/v1/messages`.
      @path_prefix : String
      @explicit_base_url : String?

      # Create a Bedrock Mantle client.
      #
      # Auth precedence (matches official SDKs):
      # 1. `api_key` constructor arg → Bearer mode (`api_key: nil` skips env)
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
        api_key : String | UnsetValue | Nil = UNSET,
        auth_token : String | UnsetValue | Nil = UNSET,
        skip_auth : Bool = false,
        base_url : String? = nil,
        timeout : Time::Span | UnsetValue | Nil = UNSET,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        default_query : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
        webhook_key : String? = nil,
        proxy : String? = nil,
        workspace_id : String? = nil,
        user_profile_id : String? = nil,
      )
        self.class.validate_auth_inputs!(
          auth_token: auth_token,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_profile: aws_profile,
        )

        @skip_auth = skip_auth
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @aws_session_token = aws_session_token
        @aws_profile = aws_profile

        env_bearer = api_key.is_a?(UnsetValue) ? (ENV["AWS_BEARER_TOKEN_BEDROCK"]? || ENV["ANTHROPIC_AWS_API_KEY"]?) : nil
        explicit_key = api_key.is_a?(UnsetValue) ? nil : api_key

        @use_sig_v4, @bearer_token, @credentials, @aws_region = resolve_auth(
          api_key: explicit_key,
          env_api_key: env_bearer,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_region: aws_region,
          aws_profile: aws_profile,
          skip_auth: skip_auth,
        )

        explicit_base = base_url || ENV["ANTHROPIC_BEDROCK_MANTLE_BASE_URL"]?
        @explicit_base_url = explicit_base.try(&.rstrip('/'))
        resolved_base = @explicit_base_url || derive_mantle_base_url(@aws_region)

        host_base, @path_prefix = split_base_url(resolved_base)

        # Parent requires an api_key string; Mantle auth is handled in #headers / SigV4
        # and placeholder is cleared right after super().
        # Pass host-only base URL — path prefix is applied in #request / #post_stream.
        super(
          api_key: @bearer_token || "bedrock-mantle",
          base_url: host_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          default_query: default_query,
          middleware: middleware,
          webhook_key: webhook_key,
          proxy: proxy,
          workspace_id: workspace_id,
          user_profile_id: user_profile_id,
        )
        @api_key = @bearer_token
        @auth_token = nil
      end

      def supports_message_threads? : Bool
        false
      end

      def user_profiles : NoReturn
        raise ::NotImplementedError.new(
          "User profiles are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

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
        aws_access_key : String | UnsetValue | Nil = UNSET,
        aws_secret_key : String | UnsetValue | Nil = UNSET,
        aws_session_token : String | UnsetValue | Nil = UNSET,
        aws_profile : String | UnsetValue | Nil = UNSET,
        aws_region : String? = nil,
        skip_auth : Bool? = nil,
      ) : self
        aws_creds_touched = !aws_access_key.is_a?(UnsetValue) ||
                            !aws_secret_key.is_a?(UnsetValue) ||
                            !aws_session_token.is_a?(UnsetValue) ||
                            !aws_profile.is_a?(UnsetValue)

        next_ak, next_sk, next_st, next_prof = resolve_option_aws_tuple(
          aws_creds_touched,
          api_key,
          aws_access_key,
          aws_secret_key,
          aws_session_token,
          aws_profile,
        )

        self.class.validate_auth_inputs!(
          auth_token: auth_token,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
        )

        next_api_key = if !api_key.is_a?(UnsetValue)
                         api_key
                       elsif aws_creds_touched
                         nil
                       else
                         @bearer_token
                       end

        next_skip = skip_auth.nil? ? @skip_auth : skip_auth
        next_region = aws_region || @aws_region

        use_sig_v4, bearer_token, credentials, resolved_region = resolve_auth(
          api_key: next_api_key,
          env_api_key: nil,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_region: next_region,
          aws_profile: next_prof,
          skip_auth: next_skip,
        )

        next_explicit_base = base_url ? base_url.rstrip('/') : @explicit_base_url
        next_full_base = next_explicit_base || derive_mantle_base_url(resolved_region)
        next_host_base, next_prefix = split_base_url(next_full_base)

        copy = super(
          timeout: timeout,
          max_retries: max_retries,
          extra_headers: extra_headers,
          extra_query: extra_query,
          middleware: middleware,
          base_url: next_host_base,
          proxy: proxy,
          workspace_id: workspace_id,
          user_profile_id: user_profile_id,
        ).as(self)

        copy.apply_mantle_state!(
          use_sig_v4: use_sig_v4,
          bearer_token: bearer_token,
          credentials: credentials,
          aws_region: resolved_region,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
          skip_auth: next_skip,
          path_prefix: next_prefix,
          explicit_base_url: next_explicit_base,
        )
        copy
      end

      def self.validate_auth_inputs!(
        auth_token : String | UnsetValue | Nil,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
      ) : Nil
        if !auth_token.is_a?(UnsetValue) && !auth_token.nil?
          raise ArgumentError.new(
            "The `auth_token` option is not supported by Anthropic::Bedrock::MantleClient; " \
            "authentication uses a Bedrock API key (`api_key`) or AWS credentials (SigV4)."
          )
        end
        if aws_access_key.nil? != aws_secret_key.nil?
          raise ArgumentError.new(
            "`aws_access_key` and `aws_secret_key` must be provided together. " \
            "You provided only one."
          )
        end
        if !aws_session_token.nil? && aws_access_key.nil?
          raise ArgumentError.new("`aws_session_token` requires `aws_access_key` and `aws_secret_key`.")
        end
        if !aws_profile.nil? && !aws_access_key.nil?
          raise ArgumentError.new("Cannot specify both `aws_profile` and `aws_access_key`/`aws_secret_key`.")
        end
      end

      # Models listing is not supported on Bedrock Mantle.
      def models : Models
        raise ::NotImplementedError.new(
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

        ctx_timeout, _ = current_request_context
        full_path = apply_default_query(path)
        req_path = with_path_prefix(full_path)
        uri = URI.parse(@base_url)
        body_str = body.nil? ? "{}" : body.to_json
        req_headers = headers(extra_headers, method: "POST")
        body_str = move_user_profile_id_to_body!("POST", full_path, req_headers, body_str) || body_str
        apply_sig_v4!(req_headers, "POST", req_path, body_str)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          client.post(req_path, headers: req_headers, body: body_str) do |response|
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
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end

      def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
        validate_mantle_path!(path)

        ctx_timeout, _ = current_request_context
        full_path = apply_default_query(path)
        req_path = with_path_prefix(full_path)
        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: "GET")
        apply_sig_v4!(req_headers, "GET", req_path, nil)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          client.get(req_path, headers: req_headers) do |response|
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
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end

      protected def apply_mantle_state!(
        use_sig_v4 : Bool,
        bearer_token : String?,
        credentials : Credentials?,
        aws_region : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
        skip_auth : Bool,
        path_prefix : String,
        explicit_base_url : String?,
      ) : Nil
        @use_sig_v4 = use_sig_v4
        @bearer_token = bearer_token
        @api_key = bearer_token
        @auth_token = nil
        @credentials = credentials
        @aws_region = aws_region
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @aws_session_token = aws_session_token
        @aws_profile = aws_profile
        @skip_auth = skip_auth
        @path_prefix = path_prefix
        @explicit_base_url = explicit_base_url
      end

      private def derive_mantle_base_url(region : String?) : String
        if region.nil? || region.empty?
          raise ArgumentError.new(
            "No AWS region or base URL found. Set `aws_region` in the constructor, " \
            "the `AWS_REGION` / `AWS_DEFAULT_REGION` environment variable, or provide " \
            "a `base_url` / `ANTHROPIC_BEDROCK_MANTLE_BASE_URL` environment variable."
          )
        end
        "https://bedrock-mantle.#{region}.api.aws/anthropic"
      end

      # Returns {use_sig_v4, bearer_token, credentials, region}.
      private def resolve_auth(
        api_key : String?,
        env_api_key : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_region : String?,
        aws_profile : String?,
        skip_auth : Bool,
      ) : {Bool, String?, Credentials?, String?}
        env_region = aws_region || ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]?
        return {false, nil, nil, env_region} if skip_auth

        has_explicit_aws = !aws_access_key.nil? || !aws_profile.nil?
        return {false, api_key, nil, env_region} if api_key

        if has_explicit_aws
          creds = CredentialsResolver.resolve(
            aws_access_key: aws_access_key,
            aws_secret_key: aws_secret_key,
            aws_session_token: aws_session_token,
            aws_region: env_region,
            aws_profile: aws_profile,
          )
          return {true, nil, creds, creds.region}
        end

        return {false, env_api_key, nil, env_region} if env_api_key

        creds = CredentialsResolver.resolve(
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_region: env_region,
          aws_profile: aws_profile,
        )
        {true, nil, creds, creds.region}
      end

      private def resolve_option_aws_tuple(
        aws_creds_touched : Bool,
        api_key : String | UnsetValue | Nil,
        aws_access_key : String | UnsetValue | Nil,
        aws_secret_key : String | UnsetValue | Nil,
        aws_session_token : String | UnsetValue | Nil,
        aws_profile : String | UnsetValue | Nil,
      ) : {String?, String?, String?, String?}
        if aws_creds_touched
          return {
            aws_access_key.is_a?(UnsetValue) ? nil : aws_access_key,
            aws_secret_key.is_a?(UnsetValue) ? nil : aws_secret_key,
            aws_session_token.is_a?(UnsetValue) ? nil : aws_session_token,
            aws_profile.is_a?(UnsetValue) ? nil : aws_profile,
          }
        end

        if api_key.is_a?(String)
          return {nil, nil, nil, nil}
        end

        {@aws_access_key, @aws_secret_key, @aws_session_token, @aws_profile}
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        ctx_timeout, _ = current_request_context
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
          if effective_timeout = ctx_timeout || @timeout
            hdrs["x-stainless-timeout"] = effective_timeout.total_seconds.to_i.to_s
          end
          if ws = @client_workspace_id
            hdrs[WORKSPACE_ID_HEADER] = ws
          end
          if up = @client_user_profile_id
            hdrs[USER_PROFILE_ID_HEADER] = up
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

        ctx_timeout, beta = current_request_context
        method_u = method.upcase
        req_path = with_path_prefix(path)
        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: method_u)
        req_body = move_user_profile_id_to_body!(method_u, path, req_headers, body)
        apply_sig_v4!(req_headers, method_u, req_path, req_body)

        return request_direct(method_u, req_path, req_body, uri, req_headers, timeout: ctx_timeout) if @middleware.empty?

        api_request = APIRequest.new(method_u, req_path, req_headers, req_body, beta: beta)
        response = nil
        (@max_retries + 1).times do |attempt|
          begin
            api_response = invoke_chain(api_request, uri, timeout: ctx_timeout)
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

      # Mantle strips custom headers on messages/count_tokens, so forward
      # anthropic-user-profile-id inside the JSON body instead.
      private def move_user_profile_id_to_body!(
        method : String,
        path : String,
        req_headers : HTTP::Headers,
        body : String?,
      ) : String?
        return body if method != "POST" || body.nil?

        clean_path = path.split('?', 2).first
        return body unless USER_PROFILE_BODY_PATHS.includes?(clean_path)

        profile_id = req_headers[USER_PROFILE_ID_HEADER]?
        return body if profile_id.nil?

        json = JSON.parse(body)
        hash = json.as_h? || return body

        req_headers.delete(USER_PROFILE_ID_HEADER)
        unless hash.has_key?("user_profile_id")
          hash["user_profile_id"] = JSON::Any.new(profile_id)
        end
        hash.to_json
      rescue JSON::ParseException
        body
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
          raise ::NotImplementedError.new(
            "The Batch API is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
        if path.includes?("/v1/models")
          raise ::NotImplementedError.new(
            "Models listing is not supported on Bedrock Mantle. " \
            "Only Messages (/v1/messages) is supported."
          )
        end
        if path.includes?("/v1/files") || path.includes?("/v1/skills") || path.includes?("/v1/user_profiles")
          raise ::NotImplementedError.new(
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
        raise ::NotImplementedError.new(
          "Beta models are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def files
        raise ::NotImplementedError.new(
          "Beta files are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def skills
        raise ::NotImplementedError.new(
          "Beta skills are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def user_profiles
        raise ::NotImplementedError.new(
          "Beta user profiles are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def environments
        raise ::NotImplementedError.new(
          "Beta environments are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def memory_stores
        raise ::NotImplementedError.new(
          "Beta memory stores are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def sessions
        raise ::NotImplementedError.new(
          "Beta sessions are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def agents
        raise ::NotImplementedError.new(
          "Beta agents are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def vaults
        raise ::NotImplementedError.new(
          "Beta vaults are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def deployments
        raise ::NotImplementedError.new(
          "Beta deployments are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def dreams
        raise ::NotImplementedError.new(
          "Beta dreams are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end

      def tunnels
        raise ::NotImplementedError.new(
          "Beta tunnels are not supported on Bedrock Mantle. " \
          "Only Messages (/v1/messages) is supported."
        )
      end
    end
  end
end
