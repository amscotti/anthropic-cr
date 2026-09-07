module Anthropic
  # Model ID constants for all available Claude models
  module Model
    # Latest rolling aliases.
    #
    # These intentionally point at the current default API names and may duplicate
    # the latest precise constants when Anthropic's rolling alias already resolves
    # to a single concrete model name.
    CLAUDE_SONNET = "claude-sonnet-5"
    CLAUDE_FABLE  = "claude-fable-5"
    CLAUDE_OPUS   = "claude-opus-5"
    CLAUDE_HAIKU  = "claude-haiku-4-5"

    # Claude Sonnet 5 — High-performance model for coding and agents.
    CLAUDE_SONNET_5 = "claude-sonnet-5"

    # Claude Fable 5.1 — Frontier intelligence for ambitious tasks.
    CLAUDE_FABLE_5_1 = "claude-fable-5-1"

    # Claude Mythos 5.1 — Most capable model for cybersecurity and biology research.
    CLAUDE_MYTHOS_5_1 = "claude-mythos-5-1"

    # Claude Fable 5 — Next generation of intelligence for the hardest knowledge work and coding.
    CLAUDE_FABLE_5 = "claude-fable-5"

    # Claude Mythos 5 — Most capable model for cybersecurity and biology research.
    CLAUDE_MYTHOS_5 = "claude-mythos-5"

    # Claude Opus 5 — Powerful intelligence for long-running agents and coding.
    CLAUDE_OPUS_5 = "claude-opus-5"

    # Claude 4.8
    CLAUDE_OPUS_4_8 = "claude-opus-4-8"

    # Claude 4.7 — Frontier intelligence for long-running agents and coding
    CLAUDE_OPUS_4_7 = "claude-opus-4-7"

    # Claude 4.6
    CLAUDE_OPUS_4_6   = "claude-opus-4-6"
    CLAUDE_SONNET_4_6 = "claude-sonnet-4-6"

    # Claude 4.5 models
    CLAUDE_OPUS_4_5   = "claude-opus-4-5-20251101"
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5-20250929"
    CLAUDE_HAIKU_4_5  = "claude-haiku-4-5-20251001"

    # Claude 4 models
    #
    # DEPRECATED: Claude Sonnet 4 and Opus 4 reach end-of-life on June 15th, 2026.
    # Please migrate to a newer model (Sonnet 4.5+ or Opus 4.5+).
    # See https://docs.anthropic.com/en/docs/resources/model-deprecations

    # @deprecated Will reach end-of-life on June 15th, 2026. Migrate to claude-sonnet-4-5 or newer.
    CLAUDE_SONNET_4 = "claude-sonnet-4-20250514"

    # @deprecated Will reach end-of-life on August 5th, 2026. Migrate to claude-opus-4-5 or newer.
    CLAUDE_OPUS_4_1 = "claude-opus-4-1-20250805"
  end

  # Shorthand helper for accessing model IDs via symbols
  #
  # ```
  # Anthropic::Model::CLAUDE_SONNET # => "claude-sonnet-5"
  # Anthropic::Model::CLAUDE_FABLE  # => "claude-fable-5"
  # Anthropic::Model::CLAUDE_OPUS   # => "claude-opus-5"
  # Anthropic::Model::CLAUDE_HAIKU  # => "claude-haiku-4-5"
  #
  # Anthropic.model_name(:sonnet) # => "claude-sonnet-5"
  # Anthropic.model_name(:fable)  # => "claude-fable-5"
  # Anthropic.model_name(:mythos) # => "claude-mythos-5"
  # Anthropic.model_name(:opus)   # => "claude-opus-5"
  # Anthropic.model_name(:opus_5) # => "claude-opus-5"
  # Anthropic.model_name(:haiku)  # => "claude-haiku-4-5-20251001"
  # ```
  MODEL_SHORTHANDS = {
    :sonnet     => Model::CLAUDE_SONNET_5,
    :sonnet_5   => Model::CLAUDE_SONNET_5,
    :fable      => Model::CLAUDE_FABLE_5,
    :fable_5    => Model::CLAUDE_FABLE_5,
    :fable_5_1  => Model::CLAUDE_FABLE_5_1,
    :mythos_5_1 => Model::CLAUDE_MYTHOS_5_1,
    :mythos     => Model::CLAUDE_MYTHOS_5,
    :mythos_5   => Model::CLAUDE_MYTHOS_5,
    :opus       => Model::CLAUDE_OPUS_5,
    :opus_5     => Model::CLAUDE_OPUS_5,
    :opus_4_8   => Model::CLAUDE_OPUS_4_8,
    :opus_4_7   => Model::CLAUDE_OPUS_4_7,
    :haiku      => Model::CLAUDE_HAIKU_4_5,
    :opus_4_6   => Model::CLAUDE_OPUS_4_6,
    :sonnet_4_6 => Model::CLAUDE_SONNET_4_6,
    :opus_4_5   => Model::CLAUDE_OPUS_4_5,
    :sonnet_4_5 => Model::CLAUDE_SONNET_4_5,
    :opus_4_1   => Model::CLAUDE_OPUS_4_1,
    :sonnet_4   => Model::CLAUDE_SONNET_4,
  } of Symbol => String

  def self.model_name(shorthand : Symbol) : String
    MODEL_SHORTHANDS[shorthand]? || raise ArgumentError.new(
      "Unknown model shorthand: #{shorthand}. " \
      "Valid options: #{MODEL_SHORTHANDS.keys.map(&.to_s).join(", ")}"
    )
  end

  struct CapabilitySupport
    include JSON::Serializable

    getter? supported : Bool
  end

  struct ThinkingTypes
    include JSON::Serializable

    getter adaptive : CapabilitySupport
    getter enabled : CapabilitySupport
  end

  struct ThinkingCapability
    include JSON::Serializable

    getter? supported : Bool
    getter types : ThinkingTypes
  end

  struct EffortCapability
    include JSON::Serializable

    getter high : CapabilitySupport
    getter low : CapabilitySupport
    getter max : CapabilitySupport
    getter medium : CapabilitySupport

    # Extra-high effort level (Claude Opus 4.7+).
    @[JSON::Field(emit_null: false)]
    getter xhigh : CapabilitySupport?

    getter? supported : Bool
  end

  struct ContextManagementCapability
    include JSON::Serializable

    @[JSON::Field(key: "clear_thinking_20251015", emit_null: false)]
    getter clear_thinking_20251015 : CapabilitySupport?

    @[JSON::Field(key: "clear_tool_uses_20250919", emit_null: false)]
    getter clear_tool_uses_20250919 : CapabilitySupport?

    @[JSON::Field(key: "compact_20260112", emit_null: false)]
    getter compact_20260112 : CapabilitySupport?

    getter? supported : Bool
  end

  struct ModelCapabilities
    include JSON::Serializable

    getter batch : CapabilitySupport
    getter citations : CapabilitySupport

    @[JSON::Field(key: "code_execution")]
    getter code_execution : CapabilitySupport

    @[JSON::Field(key: "context_management")]
    getter context_management : ContextManagementCapability

    getter effort : EffortCapability

    @[JSON::Field(key: "image_input")]
    getter image_input : CapabilitySupport

    @[JSON::Field(key: "pdf_input")]
    getter pdf_input : CapabilitySupport

    @[JSON::Field(key: "structured_outputs")]
    getter structured_outputs : CapabilitySupport

    getter thinking : ThinkingCapability
  end

  # Model information from the API
  #
  # Represents metadata about a specific Claude model returned by the Models API.
  struct ModelInfo
    include JSON::Serializable

    # Unique model identifier
    getter id : String

    # Type of resource (always "model")
    getter type : String

    # Human-readable model name
    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Timestamp when the model was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String?

    @[JSON::Field(emit_null: false)]
    getter capabilities : ModelCapabilities?

    @[JSON::Field(key: "max_input_tokens", emit_null: false)]
    getter max_input_tokens : Int32?

    @[JSON::Field(key: "max_tokens", emit_null: false)]
    getter max_tokens : Int32?
  end
end
