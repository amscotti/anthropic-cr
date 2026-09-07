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
    class Client < Anthropic::Client
      DEFAULT_VERSION = "vertex-2023-10-16"

      getter region : String
      getter project_id : String

      def initialize(
        region : String? = nil,
        project_id : String? = nil,
        base_url : String? = nil,
        access_token : String? = nil,
        token_provider : (-> String)? = nil,
        credentials_path : String | Path | Nil = nil,
        timeout : Time::Span = 600.seconds,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
      )
        resolved_region = region || ENV["CLOUD_ML_REGION"]?
        if resolved_region.nil? || resolved_region.empty?
          raise ArgumentError.new(
            "No region was given. The client should be instantiated with the " \
            "`region` argument or the `CLOUD_ML_REGION` environment variable should be set."
          )
        end
        @region = resolved_region

        resolved_project = project_id || ENV["ANTHROPIC_VERTEX_PROJECT_ID"]?
        if resolved_project.nil? || resolved_project.empty?
          raise ArgumentError.new(
            "No project_id was given. The client should be instantiated with the " \
            "`project_id` argument or the `ANTHROPIC_VERTEX_PROJECT_ID` environment variable should be set."
          )
        end
        @project_id = resolved_project

        @auth = GoogleAuth::Provider.new(
          access_token: access_token,
          token_provider: token_provider,
          credentials_path: credentials_path,
        )

        resolved_base = base_url || ENV["ANTHROPIC_VERTEX_BASE_URL"]? || self.class.default_base_url(@region)

        # Parent requires an api_key string; Vertex auth is a Bearer token
        # applied in #headers, so a placeholder is never sent.
        super(
          api_key: "vertex",
          base_url: resolved_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          middleware: middleware,
        )
      end

      def self.default_base_url(region : String) : String
        case region
        when "global" then "https://aiplatform.googleapis.com/v1"
        when "us"     then "https://aiplatform.us.rep.googleapis.com/v1"
        when "eu"     then "https://aiplatform.eu.rep.googleapis.com/v1"
        else               "https://#{region}-aiplatform.googleapis.com/v1"
        end
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        # Do not send x-api-key; Vertex uses Google OAuth Bearer tokens.
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (vertex)",
          "authorization"     => @auth.authorization_header,
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          @default_headers.each { |key, value| hdrs[key] = value }
          extra_headers.try &.each { |key, value| hdrs[key] = value }

          if method && {"POST", "PUT", "DELETE", "PATCH"}.includes?(method) &&
             !hdrs.has_key?("idempotency-key") && !hdrs.has_key?("Idempotency-Key")
            hdrs["idempotency-key"] = UUID.random.to_s
          end
        end
      end

      # Rewrite canonical paths into Vertex publisher-model paths.
      private def request(method : String, path : String, body : String? = nil, extra_headers : Hash(String, String)? = nil) : HTTP::Client::Response
        new_path, new_body = rewrite_vertex_request(method, path, body)
        super(method, new_path, new_body, extra_headers)
      end

      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        body_str = body.nil? ? "{}" : body.to_json
        new_path, new_body = rewrite_vertex_request("POST", path, body_str)
        super(new_path, JSON.parse(new_body || "{}"), extra_headers) do |response|
          yield response
        end
      end

      def get_stream(path : String, extra_headers : Hash(String, String)? = nil, &)
        new_path, _ = rewrite_vertex_request("GET", path, nil)
        super(new_path, extra_headers) do |response|
          yield response
        end
      end

      # Rewrite a canonical request path/body into Vertex's shape.
      #
      # Returns `{path, body}` with the query dropped on rewritten routes.
      private def rewrite_vertex_request(method : String, path : String, body : String?) : {String, String?}
        base_path = path.split("?", 2).first

        if base_path.starts_with?("/v1/messages/batches")
          raise NotImplementedError.new("The Batch API is not supported in the Vertex client yet")
        end

        if method.upcase == "POST" && base_path == "/v1/messages" && body
          payload = JSON.parse(body).as_h
          model = payload["model"]?.try(&.as_s?) ||
                  raise ArgumentError.new("Expected json data to include a model for post /v1/messages")
          streaming = payload["stream"]?.try(&.as_bool?) || false
          specifier = streaming ? "streamRawPredict" : "rawPredict"
          payload.delete("model")
          payload["anthropic_version"] = JSON::Any.new(DEFAULT_VERSION)

          rewritten = "/v1/projects/#{@project_id}/locations/#{@region}/" \
                      "publishers/anthropic/models/#{model}:#{specifier}"
          return {rewritten, payload.to_json}
        end

        if method.upcase == "POST" && base_path == "/v1/messages/count_tokens" && body
          payload = JSON.parse(body).as_h
          payload["anthropic_version"] = JSON::Any.new(DEFAULT_VERSION)

          rewritten = "/v1/projects/#{@project_id}/locations/#{@region}/" \
                      "publishers/anthropic/models/count-tokens:rawPredict"
          return {rewritten, payload.to_json}
        end

        {path, body}
      end
    end
  end
end
