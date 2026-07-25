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
      DEFAULT_VERSION = "bedrock-2023-05-31"

      getter aws_region : String
      getter? use_sig_v4 : Bool

      @credentials : Credentials?
      @bearer_token : String?

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
        api_key : String? = nil,
        base_url : String? = nil,
        timeout : Time::Span = 600.seconds,
        max_retries : Int32 = DEFAULT_MAX_RETRIES,
        initial_retry_delay : Float64 = DEFAULT_INITIAL_DELAY,
        max_retry_delay : Float64 = DEFAULT_MAX_DELAY,
        default_headers : Hash(String, String) = {} of String => String,
        middleware : Array = [] of Middleware,
      )
        bearer = api_key || ENV["AWS_BEARER_TOKEN_BEDROCK"]?

        has_explicit_aws = !aws_access_key.nil? || !aws_secret_key.nil? ||
                           !aws_session_token.nil? || !aws_profile.nil?
        if bearer && has_explicit_aws
          raise ArgumentError.new(
            "Cannot specify both api_key/AWS_BEARER_TOKEN_BEDROCK and AWS credentials " \
            "(aws_access_key, aws_secret_key, aws_session_token, aws_profile)"
          )
        end

        if bearer
          @use_sig_v4 = false
          @bearer_token = bearer
          @credentials = nil
          @aws_region = aws_region || ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]? || "us-east-1"
        else
          creds = CredentialsResolver.resolve(
            aws_access_key: aws_access_key,
            aws_secret_key: aws_secret_key,
            aws_session_token: aws_session_token,
            aws_region: aws_region,
            aws_profile: aws_profile,
          )
          @use_sig_v4 = true
          @credentials = creds
          @bearer_token = nil
          @aws_region = creds.region
        end

        resolved_base = base_url ||
                        ENV["ANTHROPIC_BEDROCK_BASE_URL"]? ||
                        "https://bedrock-runtime.#{@aws_region}.amazonaws.com"

        # Parent requires an api_key string; Bedrock auth is handled in #headers.
        super(
          api_key: bearer || "bedrock",
          base_url: resolved_base,
          timeout: timeout,
          max_retries: max_retries,
          initial_retry_delay: initial_retry_delay,
          max_retry_delay: max_retry_delay,
          default_headers: default_headers,
          middleware: middleware,
        )
      end

      # Bedrock does not support the Models API the same way as the public API.
      def models : Models
        raise NotImplementedError.new(
          "List models via the Bedrock control plane (AWS CLI/SDK), not the Anthropic Models API. " \
          "See https://docs.anthropic.com/en/api/claude-on-amazon-bedrock#list-available-models"
        )
      end

      # Bedrock exposes only `beta.messages` (not Managed Agents APIs).
      def beta : Bedrock::Beta
        Bedrock::Beta.new(self)
      end

      private def headers(extra_headers : Hash(String, String)? = nil, content_type : String? = "application/json", method : String? = nil) : HTTP::Headers
        # Do not send x-api-key; Bedrock uses SigV4 or a bearer token.
        HTTP::Headers{
          "anthropic-version" => API_VERSION,
          "user-agent"        => "anthropic-crystal/#{VERSION} (bedrock)",
        }.tap do |hdrs|
          hdrs["content-type"] = content_type if content_type
          if bearer = @bearer_token
            hdrs["authorization"] = "Bearer #{bearer}"
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

        method_u = method.upcase
        req_path = path
        req_body = body

        if method_u == "POST" && messages_path?(path) && body
          req_path, req_body = rewrite_messages_request(path, body, extra_headers)
        end

        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: method_u)

        if use_sig_v4?
          creds = @credentials || raise ArgumentError.new("Missing AWS credentials for SigV4")
          full_url = "#{@base_url}#{req_path}"
          signed = SigV4.sign(creds, method_u, full_url, req_headers, req_body)
          signed.each { |key, value| req_headers[key] = value }
        end

        return request_direct(method_u, req_path, req_body, uri, req_headers) if @middleware.empty?

        api_request = APIRequest.new(method_u, req_path, req_headers, req_body)
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

      # Streaming against Bedrock uses `invoke-with-response-stream` and returns
      # AWS Event Stream framing. This rewrites the path, SigV4-signs, and
      # transcodes `application/vnd.amazon.eventstream` bodies into SSE so
      # `MessageStream` / `messages.stream` work unchanged.
      def post_stream(path : String, body, extra_headers : Hash(String, String)? = nil, &)
        validate_bedrock_path!(path)

        body_str = body.nil? ? "{}" : body.to_json
        req_path = path
        req_body = body_str

        if messages_path?(path)
          req_path, req_body = rewrite_messages_request(path, body_str, extra_headers)
        end

        uri = URI.parse(@base_url)
        req_headers = headers(extra_headers, method: "POST")

        if use_sig_v4?
          creds = @credentials || raise ArgumentError.new("Missing AWS credentials for SigV4")
          full_url = "#{@base_url}#{req_path}"
          signed = SigV4.sign(creds, "POST", full_url, req_headers, req_body)
          signed.each { |key, value| req_headers[key] = value }
        end

        HTTP::Client.new(uri) do |client|
          client.connect_timeout = @timeout
          client.read_timeout = @timeout

          begin
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
          rescue ex : IO::Error | Socket::Error
            raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
          end
        end
      end

      # --- request rewrite ---------------------------------------------------

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
          raise NotImplementedError.new("The Batch API is not supported in Bedrock yet")
        end
        if path.includes?("count_tokens")
          raise NotImplementedError.new("Token counting is not supported in Bedrock yet")
        end
        if path.includes?("/v1/models")
          raise NotImplementedError.new(
            "Please instead use the AWS Bedrock control plane to list available models. " \
            "See https://docs.anthropic.com/en/api/claude-on-amazon-bedrock#list-available-models"
          )
        end
      end

      # Transform Anthropic Messages JSON body + path into Bedrock invoke shape.
      private def rewrite_messages_request(
        path : String,
        body : String,
        extra_headers : Hash(String, String)?,
      ) : {String, String}
        json = JSON.parse(body)
        hash = json.as_h

        model = hash.delete("model").try(&.as_s?) || raise ArgumentError.new("Bedrock request missing model")
        stream = hash.delete("stream").try(&.as_bool?) || false

        # Official SDKs fold anthropic-beta header into body anthropic_beta.
        if betas = extra_headers.try(&.["anthropic-beta"]?)
          unless hash.has_key?("anthropic_beta")
            hash["anthropic_beta"] = JSON::Any.new(betas.split(',').map { |beta| JSON::Any.new(beta.strip) })
          end
        end

        hash["anthropic_version"] ||= JSON::Any.new(DEFAULT_VERSION)

        # Keep ":" in the request path unescaped; SigV4 canonicalization
        # percent-encodes it when signing (matches botocore/Bedrock behavior).
        encoded_model = encode_model_id(model)
        new_path = if stream
                     "/model/#{encoded_model}/invoke-with-response-stream"
                   else
                     "/model/#{encoded_model}/invoke"
                   end

        {new_path, hash.to_json}
      end

      # Encode model id for the HTTP path: unreserved + ":" + "/" left as-is.
      private def encode_model_id(model : String) : String
        String.build do |io|
          model.each_byte do |byte|
            char = byte.chr
            if char.ascii_alphanumeric? || char == '-' || char == '_' ||
               char == '.' || char == '~' || char == ':'
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
