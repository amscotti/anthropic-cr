module Anthropic
  # One entry in the top-level `fallbacks:` array on a message request.
  #
  # Each entry names a model to try if the primary model refuses. The four
  # override fields (`max_tokens`, `output_config`, `speed`, `thinking`) replace
  # the top-level field **for that attempt only**.
  #
  # Requires the `server-side-fallback-2026-06-01` beta header.
  #
  # ```
  # message = client.beta.messages.create(
  #   betas: [Anthropic::SERVER_SIDE_FALLBACK_BETA],
  #   model: Anthropic::Model::CLAUDE_FABLE_5,
  #   max_tokens: 1024,
  #   fallbacks: [
  #     Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8),
  #     Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_SONNET_5),
  #   ],
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
end
