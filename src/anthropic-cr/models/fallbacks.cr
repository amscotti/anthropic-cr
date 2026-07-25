module Anthropic
  # One entry in the top-level `fallbacks:` array on a message request.
  #
  # Each entry names a model to try if the primary model refuses. The four
  # override fields (`max_tokens`, `output_config`, `speed`, `thinking`) replace
  # the top-level field **for that attempt only**.
  #
  # Requires the `server-side-fallback-2026-07-01` beta header (auto-attached
  # when `fallbacks:` is set). The older `server-side-fallback-2026-06-01`
  # header is still accepted by the API.
  #
  # ```
  # message = client.beta.messages.create(
  #   model: Anthropic::Model::CLAUDE_FABLE_5,
  #   max_tokens: 1024,
  #   fallbacks: [
  #     Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8),
  #     Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_SONNET_5),
  #   ],
  #   messages: [{role: "user", content: "..."}]
  # )
  #
  # # Or use the server-defined default chain for the primary model:
  # message = client.beta.messages.create(
  #   model: Anthropic::Model::CLAUDE_FABLE_5,
  #   max_tokens: 1024,
  #   fallbacks: "default",
  #   messages: [{role: "user", content: "..."}]
  # )
  # ```
  struct FallbackParam
    include JSON::Serializable

    getter model : String

    @[JSON::Field(key: "max_tokens", emit_null: false)]
    getter max_tokens : Int32?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(emit_null: false)]
    getter speed : String?

    @[JSON::Field(emit_null: false)]
    getter thinking : ThinkingConfig?

    def initialize(
      @model : String,
      @max_tokens : Int32? = nil,
      @output_config : OutputConfig? = nil,
      @speed : String? = nil,
      @thinking : ThinkingConfig? = nil,
    )
    end
  end

  # The `fallbacks` request param: either an explicit chain of
  # `FallbackParam` entries, or the string `"default"` to request the
  # primary model's server-defined default fallback configuration.
  alias FallbacksParam = Array(FallbackParam) | String

  # Only valid string form of `fallbacks` (server-defined default chain).
  FALLBACKS_DEFAULT = "default"

  # Serializes `FallbacksParam` as either a JSON array or the string `"default"`.
  #
  # Non-`"default"` strings are rejected: official SDKs type the string arm as
  # `Literal["default"]` only.
  module FallbacksParamConverter
    def self.from_json(pull : JSON::PullParser) : FallbacksParam?
      case pull.kind
      when .null?
        pull.read_null
        nil
      when .string?
        value = pull.read_string
        unless value == FALLBACKS_DEFAULT
          raise JSON::ParseException.new(
            "Invalid fallbacks string #{value.inspect}; only #{FALLBACKS_DEFAULT.inspect} is allowed",
            pull.line_number,
            pull.column_number
          )
        end
        value
      when .begin_array?
        Array(FallbackParam).new(pull)
      else
        raise JSON::ParseException.new(
          "Expected Array(FallbackParam) or String for fallbacks, got #{pull.kind}",
          pull.line_number,
          pull.column_number
        )
      end
    end

    def self.to_json(value : FallbacksParam?, builder : JSON::Builder)
      case value
      when Nil
        builder.null
      when String
        unless value == FALLBACKS_DEFAULT
          raise ArgumentError.new(
            "Invalid fallbacks string #{value.inspect}; only #{FALLBACKS_DEFAULT.inspect} is allowed (or pass Array(FallbackParam))"
          )
        end
        builder.string(value)
      when Array
        value.to_json(builder)
      end
    end
  end

  # Object form of `fallback_credit_token`: the token plus a redemption mode.
  #
  # Requires `anthropic-beta: fallback-credit-2026-07-01`. Without that header
  # the field accepts the bare string only. The bare string and the mode-less
  # object are equivalent (both select `strict`).
  #
  # - `strict` (default / bare-string behavior): a failing redemption is a 400
  #   and the retry is not served.
  # - `best_effort`: the retry is served either way; outcome is reported on
  #   `usage.fallback_credit`.
  struct FallbackCreditTokenParam
    include JSON::Serializable

    getter token : String

    # `"strict"` or `"best_effort"`. Nil selects strict (same as bare string).
    @[JSON::Field(emit_null: false)]
    getter mode : String?

    def initialize(@token : String, @mode : String? = nil)
    end
  end

  # Request-side `fallback_credit_token`: bare string or object with mode.
  alias FallbackCreditToken = String | FallbackCreditTokenParam

  # Serializes `FallbackCreditToken` as either a JSON string or object.
  module FallbackCreditTokenConverter
    def self.from_json(pull : JSON::PullParser) : FallbackCreditToken?
      case pull.kind
      when .null?
        pull.read_null
        nil
      when .string?
        pull.read_string
      when .begin_object?
        FallbackCreditTokenParam.new(pull)
      else
        raise JSON::ParseException.new(
          "Expected String or FallbackCreditTokenParam for fallback_credit_token, got #{pull.kind}",
          pull.line_number,
          pull.column_number
        )
      end
    end

    def self.to_json(value : FallbackCreditToken?, builder : JSON::Builder)
      case value
      when Nil
        builder.null
      when String
        builder.string(value)
      when FallbackCreditTokenParam
        value.to_json(builder)
      end
    end
  end

  # Identifies one model in a fallback hop (the declining `from` or serving `to`).
  struct FallbackInfo
    include JSON::Serializable

    getter model : String

    def initialize(@model : String)
    end
  end

  # The trigger for a fallback hop. Currently only the `refusal` trigger type
  # exists; `category` is one of `cyber`, `bio`, `frontier_llm`,
  # `reasoning_extraction`, or `nil`.
  struct FallbackRefusalTrigger
    include JSON::Serializable

    getter type : String = "refusal"

    @[JSON::Field(emit_null: false)]
    getter category : String?

    def initialize(@category : String? = nil)
      @type = "refusal"
    end
  end

  # A `fallback` content block marking a model boundary in a message's content.
  #
  # Surfaced via a `content_block_start` / `content_block_stop` pair during
  # streaming (it carries no deltas). When the accumulator sees a `fallback`
  # block start, the serving model becomes `block.to.model`.
  struct FallbackContent
    include JSON::Serializable

    getter type : String = "fallback"

    getter from : FallbackInfo

    getter to : FallbackInfo

    getter trigger : FallbackRefusalTrigger

    def initialize(@from : FallbackInfo, @to : FallbackInfo, @trigger : FallbackRefusalTrigger = FallbackRefusalTrigger.new)
      @type = "fallback"
    end
  end

  # Per-hop usage entry found in `usage.iterations` when a fallback chain ran.
  #
  # `type: "message"` marks a declined (refused) hop; `type: "fallback_message"`
  # marks the hop that ultimately served the response.
  struct FallbackMessageIterationUsage
    include JSON::Serializable

    getter type : String

    # The model for this hop. The declined (`type: "message"`) hop may omit this.
    @[JSON::Field(emit_null: false)]
    getter model : String?

    @[JSON::Field(key: "input_tokens")]
    getter input_tokens : Int32

    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int32

    @[JSON::Field(key: "cache_read_input_tokens", emit_null: false)]
    getter cache_read_input_tokens : Int32?

    @[JSON::Field(key: "cache_creation_input_tokens", emit_null: false)]
    getter cache_creation_input_tokens : Int32?

    @[JSON::Field(key: "cache_creation", emit_null: false)]
    getter cache_creation : CacheCreation?

    def fallback_message? : Bool
      type == "fallback_message"
    end

    def declined? : Bool
      type == "message"
    end
  end

  # The reprice was applied: the retry is billed as if the conversation
  # had been on the retry model all along.
  struct FallbackCreditRedeemed
    include JSON::Serializable

    getter type : String = "redeemed"

    def initialize
      @type = "redeemed"
    end
  end

  # No reprice was applied; `reason` says why.
  #
  # Known reasons (closed enum from the API): `body_mismatch`,
  # `continuation_excluded`, `continuation_only`, `expired`,
  # `invalid_target_model`, `not_enabled`, `reprice_unavailable`,
  # `temporarily_unavailable`, `variant_fields_present`, `wrong_organization`,
  # `wrong_platform`, `wrong_workspace`.
  struct FallbackCreditNotApplied
    include JSON::Serializable

    getter type : String = "not_applied"

    getter reason : String

    # Request fields to remove before retrying so the token can redeem.
    # Present exactly when `reason` is `variant_fields_present`.
    @[JSON::Field(key: "remove_to_redeem", emit_null: false)]
    getter remove_to_redeem : Array(String)?

    def initialize(@reason : String, @remove_to_redeem : Array(String)? = nil)
      @type = "not_applied"
    end
  end

  # Discriminated union for `usage.fallback_credit.status`.
  alias FallbackCreditStatus = FallbackCreditRedeemed | FallbackCreditNotApplied

  # Converter for the `status` field of `FallbackCreditUsage`.
  module FallbackCreditStatusConverter
    def self.from_json(pull : JSON::PullParser) : FallbackCreditStatus
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s) || ""
      raw = json.to_json

      case type
      when "redeemed"
        FallbackCreditRedeemed.from_json(raw)
      when "not_applied"
        FallbackCreditNotApplied.from_json(raw)
      else
        raise JSON::ParseException.new(
          "Unknown fallback_credit status type: #{type.inspect}",
          0,
          0
        )
      end
    end

    def self.to_json(value : FallbackCreditStatus, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Outcome of the `fallback_credit_token` presented on a request.
  #
  # Present on `usage.fallback_credit` when a credit token was supplied.
  struct FallbackCreditUsage
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::FallbackCreditStatusConverter)]
    getter status : FallbackCreditStatus

    def initialize(@status : FallbackCreditStatus)
    end

    def redeemed? : Bool
      status.is_a?(FallbackCreditRedeemed)
    end

    def not_applied? : Bool
      status.is_a?(FallbackCreditNotApplied)
    end
  end

  # Returns true when `fallbacks` is a non-empty chain or the string `"default"`.
  #
  # Any other string (including empty) is treated as absent so we do not
  # auto-attach the server-side fallback beta for typos like `"defaults"`.
  # Serialization via `FallbacksParamConverter` also rejects non-`"default"`
  # strings with `ArgumentError`.
  def self.fallbacks_present?(fallbacks : FallbacksParam?) : Bool
    case fallbacks
    when String
      fallbacks == FALLBACKS_DEFAULT
    when Array
      !fallbacks.empty?
    else
      false
    end
  end
end
