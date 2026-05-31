module Anthropic
  # Request parameter for diagnostics (beta)
  struct DiagnosticsParam
    include JSON::Serializable

    @[JSON::Field(key: "previous_message_id")]
    getter previous_message_id : String?

    def initialize(@previous_message_id : String? = nil)
    end
  end

  # Response object for cache diagnostics (beta)
  struct Diagnostics
    include JSON::Serializable

    @[JSON::Field(key: "cache_miss_reason", emit_null: false)]
    getter cache_miss_reason : CacheMissReason?

    def initialize(@cache_miss_reason : CacheMissReason? = nil)
    end
  end

  # Cache miss reason detail for diagnostics
  struct CacheMissReason
    include JSON::Serializable

    getter type : String # "model_changed" | "system_changed" | "tools_changed" | "messages_changed" | "previous_message_not_found" | "unavailable"

    @[JSON::Field(key: "cache_missed_input_tokens")]
    getter cache_missed_input_tokens : Int32

    def initialize(@type : String, @cache_missed_input_tokens : Int32)
    end
  end
end
