module Anthropic
  # Model ID constants for all available Claude models
  module Model
    # Claude 4.6
    CLAUDE_OPUS_4_6 = "claude-opus-4-6"

    # Claude 4.5 models
    CLAUDE_OPUS_4_5   = "claude-opus-4-5-20251101"
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5-20250929"
    CLAUDE_HAIKU_4_5  = "claude-haiku-4-5-20251001"

    # Claude 4 models
    CLAUDE_SONNET_4 = "claude-sonnet-4-20250514"
    CLAUDE_OPUS_4   = "claude-opus-4-20250514"

    # Legacy Claude 3 models
    CLAUDE_3_7_SONNET = "claude-3-7-sonnet-20250219"
    CLAUDE_3_5_HAIKU  = "claude-3-5-haiku-20241022"
    CLAUDE_3_OPUS     = "claude-3-opus-20240229"
    CLAUDE_3_HAIKU    = "claude-3-haiku-20240307"
  end

  # Shorthand helper for accessing model IDs via symbols
  #
  # ```
  # Anthropic.model_name(:opus)     # => "claude-opus-4-6"
  # Anthropic.model_name(:sonnet)   # => "claude-sonnet-4-5-20250929"
  # Anthropic.model_name(:haiku)    # => "claude-haiku-4-5-20251001"
  # Anthropic.model_name(:opus_4_5) # => "claude-opus-4-5-20251101"
  # ```
  def self.model_name(shorthand : Symbol) : String
    case shorthand
    when :opus      then Model::CLAUDE_OPUS_4_6
    when :opus_4_5  then Model::CLAUDE_OPUS_4_5
    when :sonnet    then Model::CLAUDE_SONNET_4_5
    when :haiku     then Model::CLAUDE_HAIKU_4_5
    when :opus_4    then Model::CLAUDE_OPUS_4
    when :sonnet_4  then Model::CLAUDE_SONNET_4
    when :opus_3_7  then Model::CLAUDE_3_7_SONNET
    when :haiku_3_5 then Model::CLAUDE_3_5_HAIKU
    when :opus_3    then Model::CLAUDE_3_OPUS
    when :haiku_3   then Model::CLAUDE_3_HAIKU
    else
      raise ArgumentError.new(
        "Unknown model shorthand: #{shorthand}. " \
        "Valid options: :opus, :opus_4_5, :sonnet, :haiku, :opus_4, :sonnet_4, " \
        ":opus_3_7, :haiku_3_5, :opus_3, :haiku_3"
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
