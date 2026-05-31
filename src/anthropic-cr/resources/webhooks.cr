require "openssl/hmac"
require "base64"
require "crypto/subtle"

module Anthropic
  # Webhooks utility resource (beta)
  #
  # Used to verify and unwrap secure callback payloads sent by Managed Agents.
  # Follows the standard webhook signature verification specifications.
  class BetaWebhooks
    def initialize(@client : Client)
    end

    # Unwrap and verify a webhook payload
    #
    # Verification follows Standard Webhooks: HMAC-SHA256 over
    # webhook-id.webhook-timestamp.payload, base64 encoded, with a 5 minute
    # timestamp tolerance.
    #
    # ```
    # client = Anthropic::Client.new
    # event = client.beta.webhooks.unwrap(
    #   payload: request_body,
    #   headers: request_headers,
    #   key: "whsec_..."
    # )
    # puts event.id
    # ```
    def unwrap(
      payload : String,
      headers : Hash(String, String) | HTTP::Headers,
      key : String? = nil,
    ) : UnwrapWebhookEvent
      webhook_key = key || ENV["ANTHROPIC_WEBHOOK_SIGNING_KEY"]?

      if webhook_key.nil?
        raise ArgumentError.new("Cannot verify a webhook without a key. Set ANTHROPIC_WEBHOOK_SIGNING_KEY or pass it as an argument")
      end

      # Strip standard Svix/Webhook prefixes if present
      key_clean = webhook_key.starts_with?("whsec_") ? webhook_key[6..-1] : webhook_key

      # Standard webhook keys are Base64 encoded
      key_bytes = begin
        Base64.decode(key_clean)
      rescue Base64::Error
        key_clean.to_slice
      end

      msg_id = header_value(headers, "webhook-id", "x-webhook-id") || raise ArgumentError.new("Missing webhook-id header")
      msg_timestamp = header_value(headers, "webhook-timestamp", "x-webhook-timestamp") || raise ArgumentError.new("Missing webhook-timestamp header")
      msg_signature = header_value(headers, "webhook-signature", "x-webhook-signature") || raise ArgumentError.new("Missing webhook-signature header")

      # Verify timestamp tolerance to prevent replay attacks (5 minute threshold)
      epoch = begin
        msg_timestamp.to_i
      rescue ArgumentError
        raise ArgumentError.new("Invalid webhook timestamp format")
      end

      now = Time.utc.to_unix
      if (now - epoch).abs > 300
        raise ArgumentError.new("Webhook timestamp is outside tolerance limits")
      end

      # Construct signing payload: id.timestamp.body
      to_sign = "#{msg_id}.#{msg_timestamp}.#{payload}"
      digest = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, to_sign)
      computed = Base64.strict_encode(digest)

      # Check signatures matching v1 format
      signatures = msg_signature.split(' ')
      verified = false
      signatures.each do |sig|
        if sig.starts_with?("v1,")
          hash = sig[3..-1]
          # Constant-time comparison for security
          if Crypto::Subtle.constant_time_compare(hash, computed)
            verified = true
            break
          end
        end
      end

      unless verified
        raise ArgumentError.new("Webhook signature verification failed")
      end

      UnwrapWebhookEvent.from_json(payload)
    end

    private def header_value(headers : Hash(String, String) | HTTP::Headers, *names : String) : String?
      names.each do |name|
        if value = headers[name]?
          return value
        end

        headers.each do |key, header_value|
          return header_value if key.downcase == name.downcase
        end
      end

      nil
    end
  end
end
