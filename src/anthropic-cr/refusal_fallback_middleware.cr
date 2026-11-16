require "./middleware"

module Anthropic
  # Client-side refusal fallbacks middleware.
  #
  # Retries refused `POST /v1/messages` requests down a client-side fallback
  # chain. Use this when the API provider does **not** support server-side
  # fallbacks (the `server-side-fallback-2026-07-01` beta). It is mutually
  # exclusive with the request-body `fallbacks:` param.
  #
  # On a `stop_reason: "refusal"` response, the middleware walks each fallback
  # entry (merging `model`, `max_tokens`, `thinking`, `output_config`, and
  # `speed` over the original body) and retries, carrying the refusal's
  # `fallback_credit_token` in object form with `mode: "best_effort"` when
  # present. The accepting hop's response is returned verbatim; a
  # chain-exhausted refusal is also returned verbatim. Unlike server-side
  # fallbacks, no synthetic `fallback` content block is inserted — inspect
  # `message.model` to detect which model served.
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

    # Matches the official Python/Ruby SDK default (`fallback-credit-2026-07-01`).
    DEFAULT_BETAS = [FALLBACK_CREDIT_BETA_2026_07_01] of String

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

      parsed_body = JSON.parse(request.body || "{}")

      # Server-side fallbacks and this middleware are mutually exclusive.
      if parsed_body["fallbacks"]?
        raise ArgumentError.new(
          "BetaRefusalFallbackMiddleware is incompatible with the request-body `fallbacks:` param. " \
          "Use the server-side-fallback-2026-07-01 beta header instead."
        )
      end

      original_body, cleaned_any = strip_fallback_blocks(parsed_body)
      initial_request = cleaned_any ? request.with(body: original_body.to_json) : request

      # First attempt with the fallback-credit beta + helper tag attached.
      response = nxt.call(apply_defaults(initial_request))

      return response unless response.status == 200

      message = JSON.parse(response.body)
      return response unless refusal?(message)

      # Walk the fallback chain on refusal.
      @fallbacks.each do |fallback|
        credit_token = refusal_credit_token(message)
        retry_body, speed_inherited_fast = build_retry_body(original_body, fallback, credit_token)
        response = send_hop(request, nxt, retry_body, speed_inherited_fast)

        return response unless response.status == 200

        message = JSON.parse(response.body)
        return response unless refusal?(message)
      end

      # Chain exhausted — return the final refusal verbatim.
      response
    end

    private def send_hop(
      request : APIRequest,
      nxt : MiddlewareNext,
      retry_body : JSON::Any,
      speed_inherited_fast : Bool,
    ) : APIResponse
      retry_request = apply_defaults(request.with(body: retry_body.to_json), fresh_idempotency_key: true)
      response = nxt.call(retry_request)

      if (response.status == 429 || response.status == 529) && speed_inherited_fast
        fallback_hash = retry_body.as_h.dup
        fallback_hash.delete("speed")
        retry_without_speed = apply_defaults(
          request.with(body: JSON::Any.new(fallback_hash).to_json),
          fresh_idempotency_key: true
        )
        return nxt.call(retry_without_speed)
      end

      response
    end

    # Applies to messages-create requests (POST /v1/messages) with a JSON body.
    # The beta vs non-beta distinction is conveyed via the anthropic-beta header;
    # since this middleware is opt-in, intercepting both surfaces is correct.
    private def applies_to?(request : APIRequest) : Bool
      request.beta? &&
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

    # Strip client-unrecognized `fallback` content blocks from historical messages,
    # preserving `role: "system"` directives verbatim and only dropping non-system
    # turns that were emptied by stripping.
    private def strip_fallback_blocks(body : JSON::Any) : {JSON::Any, Bool}
      raw_hash = body.as_h?
      return {body, false} unless raw_hash

      messages = raw_hash["messages"]?.try(&.as_a?)
      return {body, false} unless messages

      changed = false
      cleaned_messages = [] of JSON::Any

      messages.each do |msg|
        cleaned_msg, keep, msg_changed = clean_message_fallbacks(msg)
        changed ||= msg_changed
        cleaned_messages << cleaned_msg if keep
      end

      return {body, false} unless changed

      updated = raw_hash.dup
      updated["messages"] = JSON::Any.new(cleaned_messages)
      {JSON::Any.new(updated), true}
    end

    private def clean_message_fallbacks(msg : JSON::Any) : {JSON::Any, Bool, Bool}
      msg_hash = msg.as_h?
      return {msg, true, false} unless msg_hash
      return {msg, true, false} if msg_hash["role"]?.try(&.as_s?) == "system"

      content = msg_hash["content"]?.try(&.as_a?)
      return {msg, true, false} unless content

      filtered = content.reject { |block| block.as_h?.try(&.["type"]?.try(&.as_s?)) == "fallback" }
      return {msg, true, false} if filtered.size == content.size
      return {msg, false, true} if filtered.empty?

      updated_msg = msg_hash.dup
      updated_msg["content"] = JSON::Any.new(filtered)
      {JSON::Any.new(updated_msg), true, true}
    end

    # Build a retry body by merging a fallback entry over the original.
    private def build_retry_body(
      original : JSON::Any,
      fallback : FallbackParam,
      credit_token : String?,
    ) : {JSON::Any, Bool}
      hash = original.as_h.dup

      hash["model"] = JSON::Any.new(fallback.model)

      if max_tokens = fallback.max_tokens
        hash["max_tokens"] = JSON::Any.new(max_tokens.to_i64)
      end

      speed_inherited_fast = fallback.speed.nil? && hash["speed"]?.try(&.as_s?) == "fast"
      if speed = fallback.speed
        hash["speed"] = JSON::Any.new(speed)
      end

      apply_fallback_thinking(hash, fallback)
      apply_fallback_output_config(hash, fallback)

      if token = credit_token
        # Object form with best_effort: a failing redemption no longer 400s the
        # hop — the retry proceeds at normal price and reports outcome on
        # usage.fallback_credit. Matches official Python SDK middleware.
        hash["fallback_credit_token"] = JSON.parse(
          FallbackCreditTokenParam.new(token: token, mode: "best_effort").to_json
        )
      end

      {JSON::Any.new(hash), speed_inherited_fast}
    end

    private def apply_fallback_thinking(hash : Hash(String, JSON::Any), fallback : FallbackParam) : Nil
      if thinking = fallback.thinking
        hash["thinking"] = JSON.parse(thinking.to_json)
      elsif hash["thinking"]?.try(&.as_h?).try(&.["type"]?.try(&.as_s?)) == "between_tools"
        hash["thinking"] = JSON.parse(%({"type":"disabled"}))
      end
    end

    private def apply_fallback_output_config(hash : Hash(String, JSON::Any), fallback : FallbackParam) : Nil
      fallback_oc = fallback.output_config
      return unless fallback_oc

      fallback_hash = JSON.parse(fallback_oc.to_json).as_h
      if existing = hash["output_config"]?.try(&.as_h?)
        merged = existing.dup
        fallback_hash.each { |k, v| merged[k] = v }
        hash["output_config"] = JSON::Any.new(merged)
      else
        hash["output_config"] = JSON::Any.new(fallback_hash)
      end
    end
  end
end
