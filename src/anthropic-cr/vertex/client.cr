module Anthropic
  module Vertex
    # Anthropic models on Google Cloud Vertex AI.
    #
    # Rewrites canonical `/v1/messages` calls to Vertex's publisher-model
    # API (`.../publishers/anthropic/models/{model}:rawPredict` and the
    # `streamRawPredict` variant) and authenticates with Google OAuth.
    #
    # ```
    # client = Anthropic::Vertex::Client.new(
    #   region: "us-central1",
    #   project_id: "my-gcp-project",
    # )
    #
    # message = client.messages.create(
    #   model: "claude-sonnet-4-6",
    #   max_tokens: 256,
    #   messages: [{role: "user", content: "Hello from Vertex!"}],
    # )
    # puts message.text
    # ```
    #
    # Credentials resolve via `Anthropic::GoogleAuth::Provider`: pass
    # `access_token:` or `token_provider:`, set `GOOGLE_APPLICATION_CREDENTIALS`
    # to `authorized_user` credentials, or run on GCP (metadata server).
    # Service-account key files are not supported (see `GoogleAuth`).
    #
    # Not supported on Vertex (matches the official SDKs): the Batch API,
    # Files, and Skills.
    class Beta < Anthropic::Beta
      def initialize(client : Client)
        super(client)
      end

      def user_profiles : NoReturn
        raise ::NotImplementedError.new(
          "Managing user profiles is not available on Anthropic::Vertex::Client. " \
          "Pass `user_profile_id` on message requests instead."
        )
      end
    end

    class Client < Anthropic::Client
      getter region : String
      getter project_id : String

      @auth : GoogleAuth::Provider
      @explicit_base_url : String?

      def initialize(
        region : String? = nil,
        project_id : String? = nil,
        base_url : String? = nil,
        access_token : String? = nil,
        token_provider : (-> String)? = nil,
        credentials_path : String | Path | Nil = nil,
        api_key : String | UnsetValue | Nil = UNSET,
        auth_token : String | UnsetValue | Nil = UNSET,
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
        self.class.reject_unsupported_credentials!(api_key, auth_token)

        @region = self.class.validate_region!(region || ENV["CLOUD_ML_REGION"]?)
        @project_id = self.class.validate_project_id!(project_id || ENV["ANTHROPIC_VERTEX_PROJECT_ID"]?)

        @auth = GoogleAuth::Provider.new(
          access_token: access_token,
          token_provider: token_provider,
          credentials_path: credentials_path,
        )

        explicit_base = base_url || ENV["ANTHROPIC_VERTEX_BASE_URL"]?
        @explicit_base_url = explicit_base.try(&.rstrip('/'))
        resolved_base = @explicit_base_url || self.class.default_base_url(@region)

        # Parent requires an api_key string; Vertex auth is a Bearer token
        # applied in #headers and placeholder is cleared right after super().
        super(
          api_key: "vertex",
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
        @api_key = nil
        @auth_token = nil
      end

      def supports_message_threads? : Bool
        false
      end

      def user_profiles : NoReturn
        raise ::NotImplementedError.new(
          "Managing user profiles is not available on Anthropic::Vertex::Client. " \
          "Pass `user_profile_id` on message requests instead."
        )
      end

      def beta : Vertex::Beta
        Vertex::Beta.new(self)
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
        region : String? = nil,
        project_id : String? = nil,
        access_token : String | UnsetValue | Nil = UNSET,
        token_provider : (-> String) | UnsetValue | Nil = UNSET,
        credentials_path : String | Path | UnsetValue | Nil = UNSET,
      ) : self
        self.class.reject_unsupported_credentials!(api_key, auth_token)

        next_region = self.class.validate_region!(region.nil? ? @region : region)
        next_project = self.class.validate_project_id!(project_id.nil? ? @project_id : project_id)

        creds_touched = !access_token.is_a?(UnsetValue) ||
                        !token_provider.is_a?(UnsetValue) ||
                        !credentials_path.is_a?(UnsetValue)
        next_auth = if creds_touched
                      GoogleAuth::Provider.new(
                        access_token: access_token.is_a?(UnsetValue) ? nil : access_token,
                        token_provider: token_provider.is_a?(UnsetValue) ? nil : token_provider,
                        credentials_path: credentials_path.is_a?(UnsetValue) ? nil : credentials_path,
                      )
                    else
                      @auth
                    end

        next_explicit_base = base_url ? base_url.rstrip('/') : @explicit_base_url
        next_base = next_explicit_base || self.class.default_base_url(next_region)

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

        copy.apply_vertex_state!(
          region: next_region,
          project_id: next_project,
          auth: next_auth,
          explicit_base_url: next_explicit_base,
        )
        copy
      end

      def self.reject_unsupported_credentials!(
        api_key : String | UnsetValue | Nil,
        auth_token : String | UnsetValue | Nil,
      ) : Nil
        if !api_key.is_a?(UnsetValue) && !api_key.nil?
          raise ArgumentError.new(
            "The `api_key` option is not supported by Anthropic::Vertex::Client; " \
            "authentication uses Google credentials."
          )
        end
        if !auth_token.is_a?(UnsetValue) && !auth_token.nil?
          raise ArgumentError.new(
            "The `auth_token` option is not supported by Anthropic::Vertex::Client; " \
            "authentication uses Google credentials."
          )
        end
      end

      def self.validate_region!(region : String?) : String
        if region.nil? || region.empty?
          raise ArgumentError.new(
            "No region was given. The client should be instantiated with the " \
            "`region` argument or the `CLOUD_ML_REGION` environment variable should be set."
          )
        end
        Anthropic.validate_path_segment!(region)
      end

      def self.validate_project_id!(project_id : String?) : String
        if project_id.nil? || project_id.empty?
          raise ArgumentError.new(
            "No project_id was given. The client should be instantiated with the " \
            "`project_id` argument or the `ANTHROPIC_VERTEX_PROJECT_ID` environment variable should be set."
          )
        end
        Anthropic.validate_path_segment!(project_id)
      end

      def self.default_base_url(region : String) : String
        case region
        when "global" then "https://aiplatform.googleapis.com/v1"
        when "us"     then "https://aiplatform.us.rep.googleapis.com/v1"
        when "eu"     then "https://aiplatform.eu.rep.googleapis.com/v1"
        else               "https://#{region}-aiplatform.googleapis.com/v1"
        end
      end

      protected def apply_vertex_state!(
        region : String,
        project_id : String,
        auth : GoogleAuth::Provider,
        explicit_base_url : String?,
      ) : Nil
        @region = region
        @project_id = project_id
        @auth = auth
        @explicit_base_url = explicit_base_url
        @api_key = nil
        @auth_token = nil
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        ctx_timeout, _ = current_request_context
        # Do not send x-api-key or anthropic-version; Vertex takes anthropic_version in JSON body.
        HTTP::Headers{
          "user-agent"    => "anthropic-crystal/#{VERSION} (vertex)",
          "authorization" => @auth.authorization_header,
        }.tap do |hdrs|
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
          hdrs.delete("anthropic-version")

          if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) &&
             !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
            hdrs["idempotency-key"] = UUID.random.to_s
          end
        end
      end

      # Rewrite canonical paths into Vertex publisher-model paths.
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        version = resolve_anthropic_version(extra_headers)
        new_path, new_body = rewrite_vertex_request(method, path, body, version)
        super(method, new_path, new_body, extra_headers)
      end

      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        body_str = body.nil? ? "{}" : body.to_json
        version = resolve_anthropic_version(extra_headers)
        new_path, new_body = rewrite_vertex_request("POST", path, body_str, version)
        super(new_path, JSON.parse(new_body || "{}"), extra_headers) do |response|
          yield response
        end
      end

      def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
        new_path, _ = rewrite_vertex_request("GET", path, nil, API_VERSION)
        super(new_path, extra_headers) do |response|
          yield response
        end
      end

      private def resolve_anthropic_version(extra_headers : Hash(String, String)?) : String
        extra_headers.try(&.each { |k, v| return v if k.downcase == "anthropic-version" })
        @default_headers.each { |k, v| return v if k.downcase == "anthropic-version" }
        API_VERSION
      end

      # Rewrite a canonical request path/body into Vertex's shape.
      #
      # Returns `{path, body}` with the query dropped on rewritten routes.
      private def rewrite_vertex_request(method : String, path : String, body : String?, version : String) : {String, String?}
        base_path = path.split("?", 2).first

        validate_vertex_path!(base_path)

        enc_project = encode_uri_path(@project_id)
        enc_region = encode_uri_path(@region)

        if method.upcase == "POST" && base_path == "/v1/messages" && body
          payload = JSON.parse(body).as_h
          model = payload["model"]?.try(&.as_s?) ||
                  raise ArgumentError.new("Expected json data to include a model for post /v1/messages")
          validate_vertex_model!(model)

          streaming = payload["stream"]?.try(&.as_bool?) || false
          specifier = streaming ? "streamRawPredict" : "rawPredict"
          payload.delete("model")
          payload["anthropic_version"] ||= JSON::Any.new(version)

          enc_model = encode_uri_path(model).gsub(';', "%3B")
          rewritten = "/v1/projects/#{enc_project}/locations/#{enc_region}/" \
                      "publishers/anthropic/models/#{enc_model}:#{specifier}"
          return {rewritten, payload.to_json}
        end

        if method.upcase == "POST" && base_path == "/v1/messages/count_tokens" && body
          payload = JSON.parse(body).as_h
          payload["anthropic_version"] ||= JSON::Any.new(version)

          rewritten = "/v1/projects/#{enc_project}/locations/#{enc_region}/" \
                      "publishers/anthropic/models/count-tokens:rawPredict"
          return {rewritten, payload.to_json}
        end

        if method.upcase == "POST" && body
          return {path, inject_anthropic_version(body, version)}
        end

        {path, body}
      end

      private def validate_vertex_path!(base_path : String) : Nil
        if base_path.starts_with?("/v1/messages/batches")
          raise ::NotImplementedError.new("The Batch API is not supported in the Vertex client yet")
        end
        if base_path.starts_with?("/v1/user_profiles")
          raise ::NotImplementedError.new("User profiles are not supported in the Vertex client")
        end
        if base_path.starts_with?("/v1/files") || base_path.starts_with?("/v1/skills")
          raise ::NotImplementedError.new("This endpoint is not supported in the Vertex client")
        end
      end

      private def validate_vertex_model!(model : String) : Nil
        if model.empty?
          raise ArgumentError.new("`model` cannot be empty")
        end
        Anthropic.validate_path_segment!(model)
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

      private def encode_uri_path(value : String) : String
        String.build do |io|
          value.each_byte do |byte|
            char = byte.chr
            if pchar?(char)
              io << char
            else
              io << '%'
              io << byte.to_s(16).upcase.rjust(2, '0')
            end
          end
        end
      end

      private def pchar?(char : Char) : Bool
        char.ascii_alphanumeric? ||
          "-._~!$&'()*+,;=:@".includes?(char)
      end
    end
  end
end
