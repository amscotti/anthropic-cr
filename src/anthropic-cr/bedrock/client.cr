require "./event_stream"
require "./beta"

module Anthropic
  module Bedrock
    # Anthropic Messages client that targets Amazon Bedrock Runtime.
    #
    # Rewrites canonical `/v1/messages` calls to Bedrock's
    # `/model/{modelId}/invoke` (and stream variant) and authenticates with
    # AWS SigV4 (or an optional Bedrock bearer token).
    #
    # ```
    # client = Anthropic::Bedrock::Client.new(
    #   aws_profile: "anthropic-cr-bedrock",
    #   aws_region: "us-east-1",
    # )
    #
    # message = client.messages.create(
    #   model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    #   max_tokens: 256,
    #   messages: [{role: "user", content: "Hello from Bedrock!"}],
    # )
    # puts message.text
    # ```
    #
    # Prefer **inference profile** model IDs (`us.anthropic.*` / `global.anthropic.*`)
    # for current Claude models — bare `anthropic.*` on-demand IDs often fail.
    #
    # Not supported on Bedrock yet (matches official SDKs): Message Batches,
    # token counting, and the Models list endpoint.
    class Client < Anthropic::Client
      getter aws_region : String
      getter aws_access_key : String?
      getter aws_secret_key : String?
      getter aws_session_token : String?
      getter aws_profile : String?
      getter? use_sig_v4 : Bool
      getter? skip_auth : Bool

      @credentials : Credentials?
      @bearer_token : String?
      @explicit_base_url : String?

      # Create a Bedrock client.
      #
      # Pass AWS credentials explicitly, via `aws_profile`, or rely on the
      # resolver chain (env → shared credentials → `aws login` cache →
      # IAM Identity Center SSO → IMDS). Alternatively pass `api_key` /
      # set `AWS_BEARER_TOKEN_BEDROCK` for bearer-token auth (mutually exclusive
      # with AWS credentials).
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

        has_explicit_aws = !aws_access_key.nil? || !aws_profile.nil?
        bearer = case api_key
                 when UnsetValue
                   has_explicit_aws ? nil : ENV["AWS_BEARER_TOKEN_BEDROCK"]?
                 else
                   api_key
                 end

        if bearer && has_explicit_aws
          raise ArgumentError.new(
            "Cannot specify both api_key/AWS_BEARER_TOKEN_BEDROCK and AWS credentials " \
            "(aws_access_key, aws_secret_key, aws_session_token, aws_profile)"
          )
        end

        @use_sig_v4, @bearer_token, @credentials, @aws_region = resolve_bedrock_auth(
          bearer: bearer,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_region: aws_region,
          aws_profile: aws_profile,
          skip_auth: skip_auth,
        )

        explicit_base = base_url || ENV["ANTHROPIC_BEDROCK_BASE_URL"]?
        @explicit_base_url = explicit_base.try(&.rstrip('/'))
        resolved_base = @explicit_base_url || "https://bedrock-runtime.#{@aws_region}.amazonaws.com"

        # Parent requires an api_key string; Bedrock auth is handled in #headers
        # and placeholder is cleared right after super().
        super(
          api_key: @bearer_token || "bedrock",
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
          "Amazon Bedrock does not support the User Profiles API. " \
          "Pass `user_profile_id` directly on message requests instead."
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
          api_key: api_key,
          auth_token: auth_token,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_profile: next_prof,
        )

        has_new_aws = !next_ak.nil? || !next_prof.nil?
        next_bearer = if !api_key.is_a?(UnsetValue)
                        if !api_key.nil? && aws_creds_touched && has_new_aws
                          raise ArgumentError.new(
                            "Cannot specify both api_key and AWS credentials " \
                            "(aws_access_key, aws_secret_key, aws_session_token, aws_profile)"
                          )
                        end
                        api_key
                      elsif aws_creds_touched
                        nil
                      else
                        @bearer_token
                      end

        next_skip = skip_auth.nil? ? @skip_auth : skip_auth
        next_region = aws_region || @aws_region

        use_sig_v4, bearer_token, credentials, resolved_region = resolve_bedrock_auth(
          bearer: next_bearer,
          aws_access_key: next_ak,
          aws_secret_key: next_sk,
          aws_session_token: next_st,
          aws_region: next_region,
          aws_profile: next_prof,
          skip_auth: next_skip,
        )

        next_explicit_base = base_url ? base_url.rstrip('/') : @explicit_base_url
        next_base = next_explicit_base || "https://bedrock-runtime.#{resolved_region}.amazonaws.com"

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

        copy.apply_bedrock_state!(
          use_sig_v4: use_sig_v4,
          bearer_token: bearer_token,
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

      def self.validate_auth_inputs!(
        api_key : String | UnsetValue | Nil,
        auth_token : String | UnsetValue | Nil,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
      ) : Nil
        if !auth_token.is_a?(UnsetValue) && !auth_token.nil?
          raise ArgumentError.new(
            "The `auth_token` option is not supported by Anthropic::Bedrock::Client; " \
            "authentication uses AWS SigV4 or a Bedrock API key (`api_key`)."
          )
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

      # Bedrock does not support the Models API the same way as the public API.
      def models : Models
        raise ::NotImplementedError.new(
          "List models via the Bedrock control plane (AWS CLI/SDK), not the Anthropic Models API. " \
          "See https://docs.anthropic.com/en/api/claude-on-amazon-bedrock#list-available-models"
        )
      end

      # Bedrock exposes only `beta.messages` (not Managed Agents APIs).
      def beta : Bedrock::Beta
        Bedrock::Beta.new(self)
      end

      protected def apply_bedrock_state!(
        use_sig_v4 : Bool,
        bearer_token : String?,
        credentials : Credentials?,
        aws_region : String,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_profile : String?,
        skip_auth : Bool,
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
        @explicit_base_url = explicit_base_url
      end

      private def resolve_bedrock_region(aws_region : String?) : String
        region = aws_region || ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]? || "us-east-1"
        if region.empty?
          raise ArgumentError.new("`aws_region` cannot be empty.")
        end
        region
      end

      private def resolve_bedrock_auth(
        bearer : String?,
        aws_access_key : String?,
        aws_secret_key : String?,
        aws_session_token : String?,
        aws_region : String?,
        aws_profile : String?,
        skip_auth : Bool,
      ) : {Bool, String?, Credentials?, String}
        if skip_auth
          return {false, nil, nil, resolve_bedrock_region(aws_region)}
        end
        if bearer
          return {false, bearer, nil, resolve_bedrock_region(aws_region)}
        end
        if !aws_region.nil? && aws_region.empty?
          raise ArgumentError.new("`aws_region` cannot be empty.")
        end

        creds = CredentialsResolver.resolve(
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          aws_session_token: aws_session_token,
          aws_region: aws_region,
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
        # Do not send x-api-key; Bedrock uses SigV4 or a bearer token.
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (bedrock)",
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          if !@skip_auth && (bearer = @bearer_token)
            hdrs["authorization"] = "Bearer #{bearer}"
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

      # Override request to rewrite Messages routes and SigV4-sign.
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        validate_bedrock_path!(path)

        ctx_timeout, beta = current_request_context
        method_u = method.upcase
        req_headers = headers(extra_headers, method: method_u)
        version = req_headers.delete("anthropic-version") || API_VERSION
        req_path, req_body = prepare_bedrock_request(method_u, path, body, req_headers, version)

        uri = URI.parse(@base_url)
        sign_bedrock_headers!(method_u, req_path, req_headers, req_body)

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

      # Streaming against Bedrock uses `invoke-with-response-stream` and returns
      # AWS Event Stream framing. This rewrites the path, SigV4-signs, and
      # transcodes `application/vnd.amazon.eventstream` bodies into SSE so
      # `MessageStream` / `messages.stream` work unchanged.
      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        validate_bedrock_path!(path)

        ctx_timeout, _ = current_request_context
        body_str = body.nil? ? "{}" : body.to_json
        req_headers = headers(extra_headers, method: "POST")
        version = req_headers.delete("anthropic-version") || API_VERSION
        req_path, req_body = prepare_bedrock_request("POST", path, body_str, req_headers, version)

        uri = URI.parse(@base_url)
        sign_bedrock_headers!("POST", req_path, req_headers, req_body)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          client.post(req_path, headers: req_headers, body: req_body) do |response|
            unless response.success?
              # Block-form responses only expose the body via body_io.
              error_body = response.body_io?.try(&.gets_to_end) || response.body
              handle_error(HTTP::Client::Response.new(
                response.status_code,
                body: error_body,
                headers: response.headers,
              ))
            end
            yield adapt_stream_response(response)
          end
        rescue ex : IO::TimeoutError
          raise APITimeoutError.new("Stream read timed out", cause: ex)
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
        end
      end

      # --- request rewrite ---------------------------------------------------

      private def sign_bedrock_headers!(method : String, path : String, req_headers : HTTP::Headers, body : String?) : Nil
        return if @skip_auth || !use_sig_v4?

        creds = @credentials || raise ArgumentError.new("Missing AWS credentials for SigV4")
        full_url = "#{@base_url}#{path}"
        signed = SigV4.sign(creds, method, full_url, req_headers, body)
        signed.each { |key, value| req_headers[key] = value }
      end

      private def prepare_bedrock_request(
        method : String,
        path : String,
        body : String?,
        req_headers : HTTP::Headers,
        version : String,
      ) : {String, String?}
        return {path, body} unless method == "POST" && body

        if messages_path?(path)
          return rewrite_messages_request(path, body, req_headers, version)
        end

        {path, inject_anthropic_version(body, version)}
      end

      private def inject_anthropic_version(body : String, version : String) : String
        json = JSON.parse(body)
        hash = json.as_h? || return body
        return body if hash.has_key?("anthropic_version")

        hash["anthropic_version"] = JSON::Any.new(version)
        hash.to_json
      rescue JSON::ParseException
        body
      end

      # When Bedrock returns AWS event-stream framing, transcode to SSE and
      # rewrite content-type so MessageStream can parse events.
      private def adapt_stream_response(response : HTTP::Client::Response) : HTTP::Client::Response
        content_type = response.headers["content-type"]? || response.headers["Content-Type"]?
        return response unless EventStream.eventstream?(content_type)

        source = response.body_io? || IO::Memory.new(response.body)
        sse_body = EventStream.to_sse(source)

        new_headers = HTTP::Headers.new
        response.headers.each do |key, values|
          next if key.downcase == "content-length"
          values.each { |value| new_headers.add(key, value) }
        end
        new_headers["content-type"] = "text/event-stream"

        HTTP::Client::Response.new(
          response.status_code,
          headers: new_headers,
          body_io: IO::Memory.new(sse_body),
        )
      end

      private def messages_path?(path : String) : Bool
        base = path.split('?').first
        base == "/v1/messages" || base.ends_with?("/v1/messages") ||
          base == "/v1/complete" || base.ends_with?("/v1/complete")
      end

      private def validate_bedrock_path!(path : String) : Nil
        if path.includes?("/v1/messages/batches")
          raise ::NotImplementedError.new("The Batch API is not supported in Bedrock yet")
        end
        if path.includes?("count_tokens")
          raise ::NotImplementedError.new("Token counting is not supported in Bedrock yet")
        end
        if path.includes?("/v1/user_profiles")
          raise ::NotImplementedError.new("User profiles are not supported in Bedrock")
        end
        if path.includes?("/v1/models")
          raise ::NotImplementedError.new(
            "Please instead use the AWS Bedrock control plane to list available models. " \
            "See https://docs.anthropic.com/en/api/claude-on-amazon-bedrock#list-available-models"
          )
        end
      end

      # Transform Anthropic Messages JSON body + path into Bedrock invoke shape.
      private def rewrite_messages_request(
        path : String,
        body : String,
        req_headers : HTTP::Headers,
        version : String,
      ) : {String, String}
        json = JSON.parse(body)
        hash = json.as_h

        model = hash.delete("model").try(&.as_s?) || raise ArgumentError.new("Bedrock request missing model")
        stream = hash.delete("stream").try(&.as_bool?) || false

        # Official SDKs fold anthropic-beta header into body anthropic_beta.
        if betas = req_headers["anthropic-beta"]?
          unless hash.has_key?("anthropic_beta")
            hash["anthropic_beta"] = JSON::Any.new(betas.split(',').map { |beta| JSON::Any.new(beta.strip) })
          end
        end

        hash["anthropic_version"] ||= JSON::Any.new(version)

        # Validate model path segment and percent-encode keeping ":" and ";" unencoded;
        # SigV4 canonicalization percent-encodes them when signing.
        encoded_model = encode_model_id(model)
        new_path = if stream
                     "/model/#{encoded_model}/invoke-with-response-stream"
                   else
                     "/model/#{encoded_model}/invoke"
                   end

        {new_path, hash.to_json}
      end

      # Validate and encode model id for the HTTP path, keeping unreserved + ":" + ";".
      private def encode_model_id(model : String) : String
        before_params = model.partition(';')[0]
        normalized_head = before_params.gsub(/%2e/i, ".")
        if before_params.empty? || normalized_head == "." || normalized_head == ".."
          raise ArgumentError.new("Invalid Bedrock model identifier: #{model.inspect}")
        end
        Anthropic.validate_path_segment!(model)

        String.build do |io|
          model.each_byte do |byte|
            char = byte.chr
            if char.ascii_alphanumeric? || char == '-' || char == '_' ||
               char == '.' || char == '~' || char == ':' || char == ';'
              io << char
            else
              io << '%'
              io << byte.to_s(16).upcase.rjust(2, '0')
            end
          end
        end
      end
    end
  end
end
