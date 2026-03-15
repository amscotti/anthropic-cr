module Anthropic
  # Model ID constants for all available Claude models
  module Model
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
  end
end
