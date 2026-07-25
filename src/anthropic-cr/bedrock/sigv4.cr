require "openssl"
require "openssl/hmac"
require "openssl/digest"
require "uri"

module Anthropic
  module Bedrock
    # AWS Signature Version 4 signer for Bedrock Runtime.
    #
    # Produces the headers needed for a signed request (`Authorization`,
    # `x-amz-date`, `x-amz-content-sha256`, and optional `x-amz-security-token`).
    module SigV4
      extend self

      SERVICE = "bedrock"

      # Sign an HTTP request and return headers to merge into the outbound request.
      #
      # `service` defaults to `"bedrock"` (Bedrock Runtime). Mantle uses
      # `"bedrock-mantle"`.
      def sign(
        credentials : Credentials,
        method : String,
        url : String,
        headers : HTTP::Headers,
        body : String?,
        now : Time = Time.utc,
        service : String = SERVICE,
      ) : Hash(String, String)
        uri = URI.parse(url)
        host = uri.host || raise ArgumentError.new("URL missing host: #{url}")
        # Use the raw path as transmitted. Crystal's URI.parse may already have
        # percent-decoding; prefer the path component from the URL string so
        # signing matches the request line.
        path = extract_path(url)
        query = uri.query || ""

        amz_date = now.to_utc.to_s("%Y%m%dT%H%M%SZ")
        date_stamp = now.to_utc.to_s("%Y%m%d")
        payload_hash = sha256_hex(body || "")

        signed = {} of String => String
        signed["host"] = host_header(uri, host)
        signed["x-amz-date"] = amz_date
        signed["x-amz-content-sha256"] = payload_hash
        if token = credentials.session_token
          signed["x-amz-security-token"] = token
        end

        # Include content-type when present (Bedrock JSON posts always send it).
        if ct = headers["content-type"]? || headers["Content-Type"]?
          signed["content-type"] = ct
        end

        # SigV4 canonical URI: percent-encode each path segment (slashes kept).
        # Already-encoded bytes are encoded again for the canonical string.
        canonical_uri = encode_path(path)

        canonical_headers, signed_headers = build_canonical_headers(signed)
        # Header block already ends with a trailing newline. One more newline
        # creates the required blank line before SignedHeaders (do not insert an
        # empty join element — that would add an extra blank line).
        canonical_request = String.build do |io|
          io << method.upcase << '\n'
          io << canonical_uri << '\n'
          io << canonicalize_query(query) << '\n'
          io << canonical_headers
          io << '\n'
          io << signed_headers << '\n'
          io << payload_hash
        end

        credential_scope = "#{date_stamp}/#{credentials.region}/#{service}/aws4_request"
        string_to_sign = [
          "AWS4-HMAC-SHA256",
          amz_date,
          credential_scope,
          sha256_hex(canonical_request),
        ].join('\n')

        signing_key = derive_signing_key(
          credentials.secret_access_key,
          date_stamp,
          credentials.region,
          service
        )
        signature = OpenSSL::HMAC.hexdigest(:sha256, signing_key, string_to_sign)

        authorization = String.build do |io|
          io << "AWS4-HMAC-SHA256 Credential="
          io << credentials.access_key_id << '/' << credential_scope
          io << ", SignedHeaders=" << signed_headers
          io << ", Signature=" << signature
        end

        result = {
          "authorization"        => authorization,
          "x-amz-date"           => amz_date,
          "x-amz-content-sha256" => payload_hash,
          "host"                 => signed["host"],
        }
        if token = credentials.session_token
          result["x-amz-security-token"] = token
        end
        result
      end

      private def host_header(uri : URI, host : String) : String
        port = uri.port
        if port && !default_port?(uri.scheme, port)
          "#{host}:#{port}"
        else
          host
        end
      end

      private def default_port?(scheme : String?, port : Int32) : Bool
        (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
      end

      # Path + optional query stripped absolute path from a full URL.
      private def extract_path(url : String) : String
        # Strip scheme://authority
        rest = if idx = url.index("://")
                 url[(idx + 3)..]
               else
                 url
               end
        path_start = rest.index('/') || return "/"
        path_and_query = rest[path_start..]
        path = path_and_query.split('?', 2).first
        path.empty? ? "/" : path
      end

      # URI-encode a path for the SigV4 canonical request. Slashes are preserved;
      # every other byte (including already-percent-encoded sequences) is encoded
      # so `:` → `%3A` and `%3A` → `%253A`.
      private def encode_path(path : String) : String
        path.split('/').map { |segment| aws_encode(segment) }.join('/')
      end

      private def build_canonical_headers(headers : Hash(String, String)) : {String, String}
        # Lowercase keys, trim values, sort by key.
        pairs = headers.map { |k, v| {k.downcase, v.strip} }.sort_by!(&.[0])
        canonical = String.build do |io|
          pairs.each do |key, value|
            io << key << ':' << value << '\n'
          end
        end
        signed = pairs.map(&.[0]).join(';')
        {canonical, signed}
      end

      private def canonicalize_query(query : String) : String
        return "" if query.empty?

        params = URI::Params.parse(query)
        # Sort by key then value; encode each component.
        pairs = [] of {String, String}
        params.each do |key, value|
          pairs << {aws_encode(key), aws_encode(value)}
        end
        pairs.sort_by! { |k, v| {k, v} }
        pairs.map { |k, v| "#{k}=#{v}" }.join('&')
      end

      # AWS SigV4 URI encoding: encode all except unreserved characters.
      private def aws_encode(value : String) : String
        String.build do |io|
          value.each_byte do |byte|
            char = byte.chr
            if unreserved?(char)
              io << char
            else
              io << '%'
              io << byte.to_s(16).upcase.rjust(2, '0')
            end
          end
        end
      end

      private def unreserved?(char : Char) : Bool
        char.ascii_alphanumeric? || char == '-' || char == '_' || char == '.' || char == '~'
      end

      private def derive_signing_key(secret : String, date : String, region : String, service : String) : Bytes
        k_date = hmac_sha256("AWS4#{secret}".to_slice, date)
        k_region = hmac_sha256(k_date, region)
        k_service = hmac_sha256(k_region, service)
        hmac_sha256(k_service, "aws4_request")
      end

      private def hmac_sha256(key : Bytes | String, data : String) : Bytes
        key_bytes = key.is_a?(String) ? key.to_slice : key
        OpenSSL::HMAC.digest(:sha256, key_bytes, data)
      end

      private def sha256_hex(data : String) : String
        digest = OpenSSL::Digest.new("SHA256")
        digest.update(data)
        digest.final.hexstring
      end
    end
  end
end
