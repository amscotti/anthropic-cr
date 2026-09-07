module Anthropic
  # [Legacy] Text Completion object returned by the Completions API.
  #
  # The Text Completions API is a legacy API; prefer the Messages API for
  # new code. Future models and features are not compatible with Text
  # Completions. See the migration guide in the Anthropic docs for guidance
  # on moving from Text Completions to Messages.
  struct Completion
    include JSON::Serializable

    # Unique identifier for the completion.
    getter id : String

    # The resulting completion text (up to `max_tokens_to_sample` tokens).
    getter completion : String

    # Model that completed the prompt.
    getter model : String

    # Reason generation stopped (`nil` while streaming intermediate chunks).
    @[JSON::Field(key: "stop_reason", emit_null: false)]
    getter stop_reason : String?

    # Object type. Always `"completion"`.
    getter type : String = "completion"
  end
end
