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
      # Gateway base URL template.
      URL_TEMPLATE = "https://claude.googleapis.com/v1alpha/projects/%<project>s/locations/%<location>s/workspaces/%<workspace_id>s/invoke"

      getter project : String?
      getter location : String
      getter workspace_id : String?

      def initialize(
        project : String? = nil,
        location : String? = nil,
        workspace_id : String? = nil,
        base_url : String? = nil,
        access_token : String? = nil,
        token_provider : (-> String)? = nil,
        credentials_path : String | Path | Nil = nil,
        skip_auth : Bool = false,
        timeout : Time::Span = 600.seconds,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
      )
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

        @project = project || ENV["ANTHROPIC_GOOGLE_CLOUD_PROJECT"]? || ENV["GOOGLE_CLOUD_PROJECT"]?
        @location = location || ENV["ANTHROPIC_GOOGLE_CLOUD_LOCATION"]? || "global"

        resolved_workspace = workspace_id || ENV["ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID"]?
        if resolved_workspace.nil? && !skip_auth
          raise ArgumentError.new(
            "No workspace ID was given. Set the `workspace_id` argument or the " \
            "`ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID` environment variable."
          )
        end
        @workspace_id = resolved_workspace

        resolved_base = base_url || ENV["ANTHROPIC_GOOGLE_CLOUD_BASE_URL"]? || derive_base_url
        @path_prefix = URI.parse(resolved_base).path.rstrip("/")

        # Parent requires an api_key string; gateway auth is a Bearer token
        # applied in #headers, so a placeholder is never sent.
        super(
          api_key: "google-cloud",
          base_url: resolved_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          middleware: middleware,
        )
      end

      # Whether authentication is disabled (requests go unsigned).
      def skip_auth? : Bool
        @skip_auth
      end

      # Join the gateway invoke prefix with a canonical `/v1/*` path.
      #
      # Crystal's HTTP client replaces (rather than joins) a base URL path,
      # so the prefix is applied per request. An empty prefix (explicit
      # host-only `base_url`) leaves the path untouched.
      private def gateway_path(path : String) : String
        return path if @path_prefix.empty?
        if path.includes?("?")
          base, query = path.split("?", 2)
          "#{@path_prefix}#{base}?#{query}"
        else
          "#{@path_prefix}#{path}"
        end
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
        filename : String,
        content_type : String = "application/octet-stream",
        extra_headers : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        super(gateway_path(path), file, filename, content_type, extra_headers)
      end

      def post_multipart_files(
        path : String,
        files : Array(FileUpload),
        form_fields : Hash(String, String)? = nil,
        extra_headers : Hash(String, String)? = nil,
      ) : HTTP::Client::Response
        super(gateway_path(path), files, form_fields, extra_headers)
      end

      private def derive_base_url : String
        project = @project ||
                  raise ArgumentError.new(
                    "No project was given and the base URL cannot be derived. Set the " \
                    "`project` argument, the `ANTHROPIC_GOOGLE_CLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT` " \
                    "environment variables, or pass `base_url` explicitly."
                  )
        workspace = @workspace_id ||
                    raise ArgumentError.new(
                      "No workspace ID was given and the base URL cannot be derived. Set the " \
                      "`workspace_id` argument or pass `base_url` explicitly."
                    )
        URL_TEMPLATE % {project: project, location: @location, workspace_id: workspace}
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
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
