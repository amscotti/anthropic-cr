require "http/client"
require "json"
require "uri"

module Anthropic
  # Google Cloud authentication for the Vertex and Google Cloud clients.
  #
  # Resolves a GCP access token from, in priority order:
  # 1. an explicit `access_token`,
  # 2. a `token_provider` proc (called whenever a fresh token is needed),
  # 3. Application Default Credentials: `GOOGLE_APPLICATION_CREDENTIALS`
  #    (`authorized_user` refresh flow), then the GCE metadata server.
  #
  # Service-account (`service_account`) key files are *not* supported: the
  # OAuth2 JWT-bearer grant needs RS256 signing and Crystal's standard
  # library has no RSA signer. Pass `access_token:`/`token_provider:`, use
  # `gcloud auth application-default login` (which writes `authorized_user`
  # credentials), or run on GCP so the metadata server can mint tokens.
  module GoogleAuth
    SCOPE     = "https://www.googleapis.com/auth/cloud-platform"
    TOKEN_URL = "https://oauth2.googleapis.com/token"

    # Resolves and caches GCP access tokens.
    class Provider
      @static_token : String?
      @token_provider : (-> String)?
      @credentials_path : String | Path | Nil
      @enable_metadata_server : Bool
      @cached_token : String?
      @cached_expiry : Time?
      @mutex : Mutex

      # Explicit token, token proc, ADC file path, and metadata toggle.
      def initialize(
        access_token : String? = nil,
        token_provider : (-> String)? = nil,
        credentials_path : String | Path | Nil = nil,
        enable_metadata_server : Bool = true,
      )
        @static_token = access_token
        @token_provider = token_provider
        @credentials_path = credentials_path
        @enable_metadata_server = enable_metadata_server
        @cached_token = nil
        @cached_expiry = nil
        @mutex = Mutex.new
      end

      # Return a usable access token, refreshing cached ADC tokens a minute
      # before expiry.
      def token : String
        if static_token = @static_token
          return static_token
        end
        if provider = @token_provider
          return provider.call
        end

        @mutex.synchronize do
          if cached = @cached_token
            if expiry = @cached_expiry
              return cached if expiry > Time.utc + 60.seconds
            else
              return cached
            end
          end

          fresh, expires_in = fetch_adc_token
          @cached_token = fresh
          @cached_expiry = expires_in.try { |ttl| Time.utc + ttl.seconds }
          fresh
        end
      end

      # Build the `Authorization` header value for a request.
      def authorization_header : String
        "Bearer #{token}"
      end

      private def request_path(uri : URI) : String
        if query = uri.query
          "#{uri.path}?#{query}"
        else
          uri.path
        end
      end

      private def fetch_adc_token : {String, Int64?}
        path = @credentials_path.try(&.to_s) ||
               ENV["GOOGLE_APPLICATION_CREDENTIALS"]?
        if path && !path.empty?
          return token_from_adc_file(path)
        end
        if @enable_metadata_server
          if token = token_from_metadata_server
            return token
          end
        end
        raise ArgumentError.new(
          "No Google credentials found. Pass access_token:/token_provider:, set " \
          "GOOGLE_APPLICATION_CREDENTIALS to authorized_user credentials, run " \
          "`gcloud auth application-default login`, or run on GCP."
        )
      end

      private def token_from_adc_file(path : String) : {String, Int64?}
        raw = begin
          File.read(path)
        rescue ex : File::NotFoundError | IO::Error
          raise ArgumentError.new("GOOGLE_APPLICATION_CREDENTIALS file not readable: #{path}")
        end
        adc = begin
          JSON.parse(raw)
        rescue ex : JSON::ParseException
          raise ArgumentError.new("GOOGLE_APPLICATION_CREDENTIALS file is not valid JSON: #{path}")
        end

        case adc["type"]?.try(&.as_s?)
        when "authorized_user"
          refresh_authorized_user(adc)
        when "service_account"
          raise ArgumentError.new(
            "Service-account key files require RS256 JWT signing, which Crystal's " \
            "standard library does not provide. Pass access_token:/token_provider: " \
            "instead, or use `gcloud auth application-default login`."
          )
        else
          raise ArgumentError.new(
            "Unsupported GOOGLE_APPLICATION_CREDENTIALS type #{adc["type"]?.inspect}; " \
            "expected \"authorized_user\"."
          )
        end
      end

      private def refresh_authorized_user(adc : JSON::Any) : {String, Int64?}
        client_id = adc["client_id"]?.try(&.as_s?) ||
                    raise ArgumentError.new("ADC file missing client_id: #{adc["type"]?}")
        client_secret = adc["client_secret"]?.try(&.as_s?)
        refresh_token = adc["refresh_token"]?.try(&.as_s?) ||
                        raise ArgumentError.new("ADC file missing refresh_token.")

        form = URI::Params{
          "grant_type"    => "refresh_token",
          "client_id"     => client_id,
          "refresh_token" => refresh_token,
        }
        form["client_secret"] = client_secret if client_secret

        payload = post_form(TOKEN_URL, form)
        token = payload["access_token"]?.try(&.as_s?) ||
                raise APIError.new("Google token refresh did not return access_token: #{payload}")
        {token, payload["expires_in"]?.try(&.as_i64?)}
      end

      private def token_from_metadata_server : {String, Int64?}?
        host = ENV["GCE_METADATA_HOST"]? || "metadata.google.internal"
        url = "http://#{host}/computeMetadata/v1/instance/service-accounts/default/token"
        uri = URI.parse(url)

        begin
          HTTP::Client.new(uri) do |client|
            client.connect_timeout = 2.seconds
            client.read_timeout = 2.seconds
            response = client.get(request_path(uri), HTTP::Headers{
              "Metadata-Flavor" => "Google",
            })
            return nil unless response.success?
            payload = JSON.parse(response.body)
            token = payload["access_token"]?.try(&.as_s?)
            return nil unless token
            {token, payload["expires_in"]?.try(&.as_i64?)}
          end
        rescue IO::Error | Socket::Error
          nil
        end
      end

      private def post_form(url : String, form : URI::Params) : JSON::Any
        uri = URI.parse(url)
        HTTP::Client.new(uri) do |client|
          client.connect_timeout = 10.seconds
          client.read_timeout = 10.seconds
          response = client.post(
            request_path(uri),
            HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
            form.to_s
          )
          unless response.success?
            raise APIError.new(
              "Google token endpoint returned #{response.status_code}: #{response.body}",
              response.status_code,
              response.body,
              response.headers
            )
          end
          JSON.parse(response.body)
        end
      end
    end
  end
end
