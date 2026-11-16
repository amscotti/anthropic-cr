module Anthropic
  module GoogleCloud
    # Claude API on the Google Cloud gateway — the first-party Anthropic API
    # served through Google Cloud.
    #
    # Unlike `Anthropic::Vertex::Client` (publisher-model `:rawPredict`
    # API, messages only), this client speaks the full first-party API:
    # requests pass through the gateway unchanged — standard `/v1/*` paths,
    # standard model names, the complete API surface.
    #
    # ```
    # client = Anthropic::GoogleCloud::Client.new(
    #   project: "my-gcp-project",
    #   location: "global",
    #   workspace_id: "ws_123",
    # )
    #
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_5,
    #   max_tokens: 256,
    #   messages: [{role: "user", content: "Hello!"}],
    # )
    # ```
    #
    # Authentication uses Google credentials unless `skip_auth` is true:
    # `token_provider` (a proc returning a token, called per request),
    # an explicit `access_token`, or Application Default Credentials via
    # `Anthropic::GoogleAuth::Provider`.
    class Client < Anthropic::Client
      # Gateway base URL templates.
      URL_TEMPLATE              = "https://claude.googleapis.com/v1/projects/%<project>s/locations/%<location>s/workspaces/%<workspace_id>s/invoke"
      ORGANIZATION_URL_TEMPLATE = "https://claude.googleapis.com/v1/projects/%<project>s/locations/%<location>s/claudeOrganization/invoke"
      ORGANIZATION_PATH         = /\A\/v1\/(?:organizations\/|user_profiles(?:[\/?]|$))/

      getter project : String?
      getter location : String
      getter workspace_id : String?
      getter? skip_auth : Bool

      @auth : GoogleAuth::Provider?
      @explicit_base_url : String?
      @path_prefix : String
      @organization_path_prefix : String?

      def initialize(
        project : String | UnsetValue | Nil = UNSET,
        location : String | UnsetValue | Nil = UNSET,
        workspace_id : String | UnsetValue | Nil = UNSET,
        base_url : String? = nil,
        access_token : String? = nil,
        token_provider : (-> String)? = nil,
        credentials_path : String | Path | Nil = nil,
        skip_auth : Bool = false,
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
        user_profile_id : String? = nil,
      )
        self.class.reject_unsupported_credentials!(api_key, auth_token)

        if skip_auth && token_provider
          raise ArgumentError.new(
            "`skip_auth` is mutually exclusive with `token_provider`; " \
            "`skip_auth` disables authentication entirely."
          )
        end

        @skip_auth = skip_auth
        @auth = skip_auth ? nil : GoogleAuth::Provider.new(
          access_token: access_token,
          token_provider: token_provider,
          credentials_path: credentials_path,
        )

        @project = case project
                   when UnsetValue
                     ENV["ANTHROPIC_GOOGLE_CLOUD_PROJECT"]? || ENV["GOOGLE_CLOUD_PROJECT"]?
                   else
                     project
                   end
        @location = case location
                    when UnsetValue, Nil
                      ENV["ANTHROPIC_GOOGLE_CLOUD_LOCATION"]? || "global"
                    else
                      location
                    end
        @workspace_id = case workspace_id
                        when UnsetValue
                          ENV["ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID"]?
                        else
                          workspace_id
                        end

        explicit_base = base_url || ENV["ANTHROPIC_GOOGLE_CLOUD_BASE_URL"]?
        @explicit_base_url = explicit_base.try(&.rstrip('/'))

        resolved_base, @path_prefix, @organization_path_prefix =
          self.class.compute_routing(@explicit_base_url, @project, @location, @workspace_id)

        # Parent requires an api_key string; gateway auth is a Bearer token
        # applied in #headers, so the placeholder is cleared right after super().
        super(
          api_key: "google-cloud",
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
          user_profile_id: user_profile_id,
        )
        @api_key = nil
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
        project : String | UnsetValue | Nil = UNSET,
        location : String | UnsetValue | Nil = UNSET,
        access_token : String | UnsetValue | Nil = UNSET,
        token_provider : (-> String) | UnsetValue | Nil = UNSET,
        credentials_path : String | Path | UnsetValue | Nil = UNSET,
        skip_auth : Bool? = nil,
      ) : self
        self.class.reject_unsupported_credentials!(api_key, auth_token)

        next_project = project.is_a?(UnsetValue) ? @project : project
        next_location = case location
                        when UnsetValue then @location
                        when Nil        then "global"
                        else                 location
                        end
        next_workspace = workspace_id.is_a?(UnsetValue) ? @workspace_id : workspace_id
        next_skip = skip_auth.nil? ? @skip_auth : skip_auth

        next_auth = resolve_option_google_auth(
          next_skip,
          access_token,
          token_provider,
          credentials_path,
        )

        next_explicit_base = base_url ? base_url.rstrip('/') : @explicit_base_url
        next_base, next_path_prefix, next_org_prefix =
          self.class.compute_routing(next_explicit_base, next_project, next_location, next_workspace)

        copy = super(
          timeout: timeout,
          max_retries: max_retries,
          extra_headers: extra_headers,
          extra_query: extra_query,
          middleware: middleware,
          base_url: next_base,
          proxy: proxy,
          user_profile_id: user_profile_id,
        ).as(self)

        copy.apply_google_cloud_state!(
          project: next_project,
          location: next_location,
          workspace_id: next_workspace,
          skip_auth: next_skip,
          auth: next_auth,
          explicit_base_url: next_explicit_base,
          path_prefix: next_path_prefix,
          organization_path_prefix: next_org_prefix,
        )
        copy
      end

      def self.reject_unsupported_credentials!(
        api_key : String | UnsetValue | Nil,
        auth_token : String | UnsetValue | Nil,
      ) : Nil
        if !api_key.is_a?(UnsetValue) && !api_key.nil?
          raise ArgumentError.new(
            "The `api_key` option is not supported by Anthropic::GoogleCloud::Client; " \
            "authentication uses Google credentials."
          )
        end
        if !auth_token.is_a?(UnsetValue) && !auth_token.nil?
          raise ArgumentError.new(
            "The `auth_token` option is not supported by Anthropic::GoogleCloud::Client; " \
            "authentication uses Google credentials."
          )
        end
      end

      def self.compute_routing(
        explicit_base_url : String?,
        project : String?,
        location : String,
        workspace_id : String?,
      ) : {String, String, String?}
        if explicit_base_url
          return {explicit_base_url, URI.parse(explicit_base_url).path.rstrip("/"), nil}
        end

        proj = validate_segment(
          project,
          "project",
          "No project was given and the base URL cannot be derived. Set the " \
          "`project` argument, the `ANTHROPIC_GOOGLE_CLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT` " \
          "environment variables, or pass `base_url` explicitly."
        )
        loc = validate_segment(location, "location", "No location was given.")

        enc_proj = encode_uri_path(proj)
        enc_loc = encode_uri_path(loc)
        org_url = ORGANIZATION_URL_TEMPLATE % {project: enc_proj, location: enc_loc}
        org_prefix = URI.parse(org_url).path.rstrip("/")

        if workspace_id
          ws = validate_segment(workspace_id, "workspace_id", "No workspace ID was given.")
          ws_url = URL_TEMPLATE % {project: enc_proj, location: enc_loc, workspace_id: encode_uri_path(ws)}
          return {ws_url, URI.parse(ws_url).path.rstrip("/"), org_prefix}
        end

        {org_url, "", org_prefix}
      end

      def self.validate_segment(value : String?, name : String, missing_message : String) : String
        if value.nil?
          raise ArgumentError.new(missing_message)
        end
        if value.empty?
          raise ArgumentError.new("`#{name}` cannot be empty.")
        end
        Anthropic.validate_path_segment!(value)
      end

      # RFC 3986 pchar percent-encoder matching upstream encodeURIPath.
      def self.encode_uri_path(value : String) : String
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

      private def self.pchar?(char : Char) : Bool
        char.ascii_alphanumeric? ||
          "-._~!$&'()*+,;=:@".includes?(char)
      end

      protected def apply_google_cloud_state!(
        project : String?,
        location : String,
        workspace_id : String?,
        skip_auth : Bool,
        auth : GoogleAuth::Provider?,
        explicit_base_url : String?,
        path_prefix : String,
        organization_path_prefix : String?,
      ) : Nil
        @project = project
        @location = location
        @workspace_id = workspace_id
        @skip_auth = skip_auth
        @auth = auth
        @explicit_base_url = explicit_base_url
        @path_prefix = path_prefix
        @organization_path_prefix = organization_path_prefix
        @api_key = nil
        @auth_token = nil
      end

      private def resolve_option_google_auth(
        next_skip : Bool,
        access_token : String | UnsetValue | Nil,
        token_provider : (-> String) | UnsetValue | Nil,
        credentials_path : String | Path | UnsetValue | Nil,
      ) : GoogleAuth::Provider?
        creds_touched = !access_token.is_a?(UnsetValue) ||
                        !token_provider.is_a?(UnsetValue) ||
                        !credentials_path.is_a?(UnsetValue)

        next_provider = token_provider.is_a?(UnsetValue) ? nil : token_provider
        if next_skip && next_provider
          raise ArgumentError.new(
            "`skip_auth` is mutually exclusive with `token_provider`; " \
            "`skip_auth` disables authentication entirely."
          )
        end

        return nil if next_skip

        if creds_touched
          return GoogleAuth::Provider.new(
            access_token: access_token.is_a?(UnsetValue) ? nil : access_token,
            token_provider: next_provider,
            credentials_path: credentials_path.is_a?(UnsetValue) ? nil : credentials_path,
          )
        end

        @auth || GoogleAuth::Provider.new
      end

      # Join the gateway invoke prefix with a canonical `/v1/*` path.
      #
      # Crystal's HTTP client replaces (rather than joins) a base URL path,
      # so the prefix is applied per request. An empty prefix (explicit
      # host-only `base_url`) leaves the path untouched.
      private def gateway_path(path : String) : String
        prefix = active_prefix_for(path)
        return path if prefix.empty?

        if path.includes?("?")
          base, query = path.split("?", 2)
          "#{prefix}#{base}?#{query}"
        else
          "#{prefix}#{path}"
        end
      end

      private def active_prefix_for(path : String) : String
        return @path_prefix unless @explicit_base_url.nil?

        base_path = path.split("?", 2).first
        if ORGANIZATION_PATH.matches?(base_path)
          return @organization_path_prefix || @path_prefix
        end

        if @workspace_id.nil?
          raise ArgumentError.new(
            "No workspace ID was given. Set the `workspace_id` argument or the " \
            "`ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID` environment variable."
          )
        end
        @path_prefix
      end

      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        super(method, gateway_path(path), body, extra_headers)
      end

      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        super(gateway_path(path), body, extra_headers) do |response|
          yield response
        end
      end

      def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
        super(gateway_path(path), extra_headers) do |response|
          yield response
        end
      end

      def get_raw(path : String, extra_headers : Hash(String, String)? = nil) : IO::Memory
        super(gateway_path(path), extra_headers)
      end

      def post_multipart(
        path : String,
        file : IO,
        filename : String? = nil,
        content_type : String = "application/octet-stream",
        extra_headers : Hash(String, String)? = nil,
        form_fields : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        super(gateway_path(path), file, filename, content_type, extra_headers, form_fields)
      end

      def post_multipart_files(
        path : String,
        files : Array(FileUpload),
        form_fields : Hash(String, String)? = nil,
        extra_headers : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        super(gateway_path(path), files, form_fields, extra_headers)
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        ctx_timeout, _ = current_request_context
        # Do not send x-api-key; the gateway uses Google OAuth Bearer tokens.
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (google-cloud)",
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          unless @skip_auth
            auth = @auth || raise ArgumentError.new("Missing Google credentials")
            hdrs["authorization"] = auth.authorization_header
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
    end
  end
end
