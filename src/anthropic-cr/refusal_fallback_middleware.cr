require "./middleware"

module Anthropic
  # Client-side refusal fallbacks middleware.
  #
  # Retries refused `POST /v1/messages` requests down a client-side fallback
  # chain. Use this when the API provider does **not** support server-side
  # fallbacks (the `server-side-fallback-2026-06-01` beta). It is mutually
  # exclusive with the request-body `fallbacks:` param.
  #
  # On a `stop_reason: "refusal"` response, the middleware walks each fallback
  # entry (merging `model`, `max_tokens`, `thinking`, `output_config`, and
  # `speed` over the original body) and retries, carrying the refusal's
  # `fallback_credit_token` when present. The accepting hop's response is
  # returned verbatim; a chain-exhausted refusal is also returned verbatim.
  # Unlike server-side fallbacks, no synthetic `fallback` content block is
  # inserted — inspect `message.model` to detect which model served.
  #
  # This implementation handles the **non-streaming** path. For streaming
  # fallbacks, prefer server-side fallbacks (`betas: [SERVER_SIDE_FALLBACK_BETA]`
  # + `fallbacks:` param) which the API handles in one round-trip.
  #
  # ```
  # client = Anthropic::Client.new(
  #   middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
  #     [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
  #   )],
  # )
  #
  # message = client.beta.messages.create(
  #   model: Anthropic::Model::CLAUDE_FABLE_5,
  #   max_tokens: 1024,
  #   messages: [{role: "user", content: "..."}],
  # )
  # ```
  class BetaRefusalFallbackMiddleware
    include Middleware

    DEFAULT_BETAS = [FALLBACK_CREDIT_BETA] of String

    @fallbacks : Array(FallbackParam)
    @betas : Array(String)

    def initialize(fallbacks : Array(FallbackParam), betas : Array(String) = DEFAULT_BETAS)
      raise ArgumentError.new("BetaRefusalFallbackMiddleware requires at least one fallback") if fallbacks.empty?
      @fallbacks = fallbacks.dup
      @betas = betas.dup
    end

    def call(request : APIRequest, nxt : MiddlewareNext) : APIResponse
      # Only applies to messages create requests with a JSON body.
      return nxt.call(request) unless applies_to?(request)

      original_body = JSON.parse(request.body || "{}")

      # Server-side fallbacks and this middleware are mutually exclusive.
      if original_body["fallbacks"]?
        raise ArgumentError.new(
          "BetaRefusalFallbackMiddleware is incompatible with the request-body `fallbacks:` param. " \
          "Use the server-side-fallback-2026-06-01 beta header instead."
        )
      end

      # First attempt with the fallback-credit beta + helper tag attached.
      response = nxt.call(apply_defaults(request))

      return response unless response.status == 200

      message = JSON.parse(response.body)
      return response unless refusal?(message)

      # Walk the fallback chain on refusal.
      @fallbacks.each do |fallback|
        credit_token = refusal_credit_token(message)
        retry_body = build_retry_body(original_body, fallback, credit_token)
        retry_request = apply_defaults(request.with(body: retry_body.to_json), fresh_idempotency_key: true)
        response = nxt.call(retry_request)

        return response unless response.status == 200

        message = JSON.parse(response.body)
        return response unless refusal?(message)
      end

      # Chain exhausted — return the final refusal verbatim.
      response
    end

    # Applies to messages-create requests (POST /v1/messages) with a JSON body.
    # The beta vs non-beta distinction is conveyed via the anthropic-beta header;
    # since this middleware is opt-in, intercepting both surfaces is correct.
    private def applies_to?(request : APIRequest) : Bool
      request.method == "POST" &&
        (request.path == "/v1/messages" || request.path.starts_with?("/v1/messages?")) &&
        !request.body.nil?
    end

    # Attach the fallback-credit beta + helper tag to a request.
    #
    # Retry hops carry a different body than the original attempt, so they must
    # not reuse the original idempotency key (a key-honoring server would
    # replay the cached refusal instead of executing the fallback).
    private def apply_defaults(request : APIRequest, fresh_idempotency_key : Bool = false) : APIRequest
      new_headers = request.headers.dup

      # Merge betas (append semantics for anthropic-beta).
      existing = new_headers["anthropic-beta"]?
      merged = existing ? existing.split(',').map(&.strip) : [] of String
      @betas.each { |beta| merged << beta unless merged.includes?(beta) }
      new_headers["anthropic-beta"] = merged.join(",")

      # Tag with the helper header (append semantics).
      new_headers = StainlessHelper.merge_helper_header(new_headers, StainlessHelper::FALLBACK_REFUSAL_MIDDLEWARE)

      new_headers["idempotency-key"] = UUID.random.to_s if fresh_idempotency_key

      request.with(headers: new_headers)
    end

    private def refusal?(message : JSON::Any) : Bool
      message["stop_reason"]?.try(&.as_s?) == "refusal"
    end

    private def refusal_credit_token(message : JSON::Any) : String?
      message["stop_details"]?.try(&.["fallback_credit_token"]?).try(&.as_s?)
    end

    # Build a retry body by merging a fallback entry over the original.
    private def build_retry_body(original : JSON::Any, fallback : FallbackParam, credit_token : String?) : JSON::Any
      hash = original.as_h.dup

      hash["model"] = JSON::Any.new(fallback.model)

      if max_tokens = fallback.max_tokens
        hash["max_tokens"] = JSON::Any.new(max_tokens.to_i64)
      end
      if speed = fallback.speed
        hash["speed"] = JSON::Any.new(speed)
      end
      if thinking = fallback.thinking
        hash["thinking"] = JSON.parse(thinking.to_json)
      end
      if output_config = fallback.output_config
        hash["output_config"] = JSON.parse(output_config.to_json)
      end
      if token = credit_token
        hash["fallback_credit_token"] = JSON::Any.new(token)
      end

      JSON::Any.new(hash)
    end
  end
end
