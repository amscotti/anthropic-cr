module Anthropic
  # Model ID constants for all available Claude models
  module Model
    # Latest rolling aliases.
    #
    # These intentionally point at the current default API names and may duplicate
    # the latest precise constants when Anthropic's rolling alias already resolves
    # to a single concrete model name.
    CLAUDE_OPUS   = "claude-opus-4-6"
    CLAUDE_SONNET = "claude-sonnet-4-6"
    CLAUDE_HAIKU  = "claude-haiku-4-5"

    # Claude 4.6
    CLAUDE_OPUS_4_6   = "claude-opus-4-6"
    CLAUDE_SONNET_4_6 = "claude-sonnet-4-6"

    # Claude 4.5 models
    CLAUDE_OPUS_4_5   = "claude-opus-4-5-20251101"
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5-20250929"
    CLAUDE_HAIKU_4_5  = "claude-haiku-4-5-20251001"

    # Claude 4 models
    CLAUDE_SONNET_4 = "claude-sonnet-4-20250514"
    CLAUDE_OPUS_4_1 = "claude-opus-4-1-20250805"
    CLAUDE_OPUS_4   = "claude-opus-4-20250514"
  end

  # Shorthand helper for accessing model IDs via symbols
  #
  # ```
  # Anthropic::Model::CLAUDE_OPUS   # => "claude-opus-4-6"
  # Anthropic::Model::CLAUDE_SONNET # => "claude-sonnet-4-6"
  # Anthropic::Model::CLAUDE_HAIKU  # => "claude-haiku-4-5"
  #
  # Anthropic.model_name(:opus)       # => "claude-opus-4-6"
  # Anthropic.model_name(:sonnet)     # => "claude-sonnet-4-6"
  # Anthropic.model_name(:haiku)      # => "claude-haiku-4-5-20251001"
  # Anthropic.model_name(:opus_4_5)   # => "claude-opus-4-5-20251101"
  # Anthropic.model_name(:sonnet_4_5) # => "claude-sonnet-4-5-20250929"
  # ```
  def self.model_name(shorthand : Symbol) : String
    case shorthand
    when :opus       then Model::CLAUDE_OPUS_4_6
    when :sonnet     then Model::CLAUDE_SONNET_4_6
    when :haiku      then Model::CLAUDE_HAIKU_4_5
    when :opus_4_6   then Model::CLAUDE_OPUS_4_6
    when :sonnet_4_6 then Model::CLAUDE_SONNET_4_6
    when :opus_4_5   then Model::CLAUDE_OPUS_4_5
    when :sonnet_4_5 then Model::CLAUDE_SONNET_4_5
    when :opus_4_1   then Model::CLAUDE_OPUS_4_1
    when :opus_4     then Model::CLAUDE_OPUS_4
    when :sonnet_4   then Model::CLAUDE_SONNET_4
    else
      raise ArgumentError.new(
        "Unknown model shorthand: #{shorthand}. " \
        "Valid options: :opus, :sonnet, :haiku, :opus_4_6, :sonnet_4_6, :opus_4_5, :sonnet_4_5, " \
        ":opus_4_1, :opus_4, :sonnet_4"
      )
    end
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
