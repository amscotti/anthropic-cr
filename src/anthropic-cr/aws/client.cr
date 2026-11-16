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
    #    (`Authorization: Bearer` header, no SigV4),
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
      getter aws_access_key : String?
      getter aws_secret_key : String?
      getter aws_session_token : String?
      getter aws_profile : String?
      getter? skip_auth : Bool

      @credentials : Bedrock::Credentials?
      @gateway_api_key : String?
      @explicit_base_url : String?

      def initialize(
        api_key : String | UnsetValue | Nil = UNSET,
        auth_token : String | UnsetValue | Nil = UNSET,
        aws_access_key : String? = nil,
        aws_secret_key : String? = nil,
        aws_session_token : String? = nil,
        aws_profile : String? = nil,
        aws_region : String? = nil,
        workspace_id : String | UnsetValue | Nil = UNSET,
        user_profile_id : String? = nil,
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
      )
        self.class.validate_auth_inputs!(
          api_key: api_key,
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

        env_key = api_key.is_a?(UnsetValue) && auth_token.is_a?(UnsetValue) ? ENV["ANTHROPIC_AWS_API_KEY"]? : nil
        effective_api_key = api_key.is_a?(UnsetValue) ? nil : api_key
        @gateway_api_key, @credentials, @aws_region = self.class.resolve_auth(
          api_key: effective_api_key,
          env_api_key: env_key,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_profile: aws_profile,
          aws_region: aws_region,
          skip_auth: skip_auth,
        )

        resolved_workspace = case workspace_id
                             when UnsetValue
                               ENV["ANTHROPIC_AWS_WORKSPACE_ID"]?
                             else
                               workspace_id
                             end

        explicit_base = base_url || ENV["ANTHROPIC_AWS_BASE_URL"]?
        @explicit_base_url = explicit_base.try(&.rstrip('/'))
        resolved_base = @explicit_base_url || self.class.default_base_url(@aws_region)

        # Parent requires an api_key string; gateway auth is handled in
        # #headers/#request and placeholder is cleared right after super().
        super(
          api_key: @gateway_api_key || "aws",
          base_url: resolved_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          default_query: default_query,
          middleware: middleware,
          webhook_key: webhook_key,
          proxy: proxy,
          workspace_id: resolved_workspace,
          user_profile_id: user_profile_id,
        )
        @api_key = @gateway_api_key
        @auth_token = nil
      end

      def supports_message_threads? : Bool
        true
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
        if api_key.is_a?(String) && auth_token.is_a?(String)
          raise ArgumentError.new("Cannot provide both api_key and auth_token")
        end

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

        next_api_key = resolve_option_api_key(api_key, auth_token, aws_creds_touched)
        next_skip = skip_auth.nil? ? @skip_auth : skip_auth
        next_region = aws_region || @aws_region

        self.class.validate_auth_inputs!(
          api_key: next_api_key,
          auth_token: auth_token.is_a?(UnsetValue) ? nil : auth_token,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
        )

        gateway_key, credentials, resolved_region = self.class.resolve_auth(
          api_key: next_api_key,
          env_api_key: nil,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
          aws_region: next_region,
          skip_auth: next_skip,
        )

        next_explicit_base = base_url ? base_url.rstrip('/') : @explicit_base_url
        next_base = next_explicit_base || self.class.default_base_url(resolved_region)

        copy = super(
          timeout: timeout,
          max_retries: max_retries,
          extra_headers: extra_headers,
          extra_query: extra_query,
          middleware: middleware,
          base_url: next_base,
          proxy: proxy,
          workspace_id: workspace_id,
          user_profile_id: user_profile_id,
        ).as(self)

        copy.apply_aws_state!(
          gateway_api_key: gateway_key,
          credentials: credentials,
          aws_region: resolved_region,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
          skip_auth: next_skip,
          explicit_base_url: next_explicit_base,
        )
        copy
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

      def self.validate_auth_inputs!(
        api_key : String | UnsetValue | Nil,
        auth_token : String | UnsetValue | Nil,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
      ) : Nil
        if api_key.is_a?(String) && auth_token.is_a?(String)
          raise ArgumentError.new("Cannot provide both api_key and auth_token")
        end
        if aws_access_key.nil? != aws_secret_key.nil?
          raise ArgumentError.new("`aws_access_key` and `aws_secret_key` must be provided together.")
        end
        if !aws_session_token.nil? && aws_access_key.nil?
          raise ArgumentError.new("`aws_session_token` requires `aws_access_key` and `aws_secret_key`.")
        end
        if !aws_profile.nil? && !aws_access_key.nil?
          raise ArgumentError.new("Cannot specify both `aws_profile` and `aws_access_key`/`aws_secret_key`.")
        end
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

      protected def apply_aws_state!(
        gateway_api_key : String?,
        credentials : Bedrock::Credentials?,
        aws_region : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
        skip_auth : Bool,
        explicit_base_url : String?,
      ) : Nil
        @gateway_api_key = gateway_api_key
        @api_key = gateway_api_key
        @auth_token = nil
        @credentials = credentials
        @aws_region = aws_region
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @aws_session_token = aws_session_token
        @aws_profile = aws_profile
        @skip_auth = skip_auth
        @explicit_base_url = explicit_base_url
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

      private def resolve_option_api_key(
        api_key : String | UnsetValue | Nil,
        auth_token : String | UnsetValue | Nil,
        aws_creds_touched : Bool,
      ) : String?
        return api_key unless api_key.is_a?(UnsetValue)
        return nil unless auth_token.is_a?(UnsetValue)
        return nil if aws_creds_touched

        @gateway_api_key
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        ctx_timeout, _ = current_request_context
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (aws)",
        }.tap do |hdrs|
          if !@skip_auth && (api_key = @gateway_api_key)
            hdrs["authorization"] = "Bearer #{api_key}"
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

          if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) &&
             !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
            hdrs["idempotency-key"] = UUID.random.to_s
          end
        end
      end

      private def reject_action_url_request!(method : String, path : String) : Nil
        return unless method.upcase == "POST"

        clean_path = path.split('?', 2).first
        if clean_path.starts_with?("/v1/user_profiles/") && clean_path.ends_with?("/action_urls")
          raise ArgumentError.new("User profile action URLs are not supported in the AWS client.")
        end
      end

      private def sign_headers!(method : String, path : String, req_headers : HTTP::Headers, body : String?) : Nil
        return if @skip_auth

        if creds = @credentials
          full_url = "#{@base_url}#{path}"
          signed = Bedrock::SigV4.sign(creds, method.upcase, full_url, req_headers, body, service: SERVICE)
          signed.each { |key, value| req_headers[key] = value }
        end
      end

      # Sign SigV4 requests (API-key and skip-auth modes pass through).
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        method_u = method.upcase
        reject_action_url_request!(method_u, path)

        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: method_u)
        sign_headers!(method_u, path, req_headers, body)

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
        reject_action_url_request!("POST", path)

        ctx_timeout, _ = current_request_context
        uri = URI.parse(@base_url)
        full_path = apply_default_query(path)
        body_str = body.nil? ? "{}" : body.to_json
        req_headers = headers(extra_headers, method: "POST")
        sign_headers!("POST", full_path, req_headers, body_str)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          client.post(full_path, headers: req_headers, body: body_str) do |response|
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
        ctx_timeout, _ = current_request_context
        uri = URI.parse(@base_url)
        full_path = apply_default_query(path)
        req_headers = headers(extra_headers, method: "GET")
        sign_headers!("GET", full_path, req_headers, nil)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          client.get(full_path, headers: req_headers) do |response|
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

      private def sig_v4_active? : Bool
        !@skip_auth && !@credentials.nil?
      end

      def get_raw(path : String, extra_headers : Hash(String, String)? = nil) : IO::Memory
        return super(path, extra_headers) unless sig_v4_active?

        ctx_timeout, _ = current_request_context
        uri = URI.parse(@base_url)
        full_path = apply_default_query(path)
        req_headers = headers(extra_headers, content_type: nil, method: "GET")
        sign_headers!("GET", full_path, req_headers, nil)

        response = execute_http_with_redirects("GET", full_path, nil, uri, req_headers, timeout: ctx_timeout)
        handle_error(response) unless response.success?
        IO::Memory.new(response.body)
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Request timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error | OpenSSL::Error
        raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
      end

      def post_multipart(
        path : String,
        file : IO,
        filename : String? = nil,
        content_type : String = "application/octet-stream",
        extra_headers : Hash(String, String)? = nil,
        form_fields : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        return super(path, file, filename, content_type, extra_headers, form_fields) unless sig_v4_active?

        send_signed_multipart(path, extra_headers) do |builder|
          form_fields.try &.each { |name, value| builder.field(name, value) }
          metadata = HTTP::FormData::FileMetadata.new(filename: filename || "")
          builder.file("file", file, metadata, headers: HTTP::Headers{"Content-Type" => content_type})
        end
      end

      def post_multipart_files(
        path : String,
        files : Array(FileUpload),
        form_fields : Hash(String, String)? = nil,
        extra_headers : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        return super(path, files, form_fields, extra_headers) unless sig_v4_active?

        send_signed_multipart(path, extra_headers) do |builder|
          form_fields.try &.each { |name, value| builder.field(name, value) }
          files.each do |upload|
            metadata = HTTP::FormData::FileMetadata.new(filename: upload.filename)
            builder.file("files[]", upload.io, metadata, headers: HTTP::Headers{"Content-Type" => upload.content_type})
          end
        end
      end

      private def send_signed_multipart(
        path : String,
        extra_headers : Hash(String, String)?,
        & : HTTP::FormData::Builder ->
      ) : HTTP::Client::Response
        ctx_timeout, _ = current_request_context
        uri = URI.parse(@base_url)
        full_path = apply_default_query(path)

        body_io = IO::Memory.new
        builder = HTTP::FormData::Builder.new(body_io)
        yield builder
        builder.finish

        body_str = body_io.to_s
        req_headers = headers(extra_headers, content_type: builder.content_type, method: "POST")
        sign_headers!("POST", full_path, req_headers, body_str)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          response = client.post(full_path, headers: req_headers, body: body_str)
          handle_error(response) unless response.success?
          return response
        end

        raise APIError.new("Request failed")
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Request timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error | OpenSSL::Error
        raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
      end
    end
  end
end
