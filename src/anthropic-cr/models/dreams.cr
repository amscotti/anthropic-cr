module Anthropic
  # Failure detail for a Dream whose `status` is `failed`.
  struct BetaDreamError
    include JSON::Serializable

    getter message : String
    getter type : String
  end

  # Model identifier and configuration applied to every dream pipeline stage.
  #
  # Same wire shape as the Agents API ModelConfig. On create you may also pass a
  # bare model id string; responses always return this object form.
  struct BetaDreamModelConfig
    include JSON::Serializable

    # Model identifier, e.g. "claude-opus-4-7". 1-256 characters.
    getter id : String

    # Inference speed mode: "standard" or "fast". Not all models support `fast`.
    @[JSON::Field(emit_null: false)]
    getter speed : String?

    def initialize(@id : String, @speed : String? = nil)
    end
  end

  # An input memory store the dream reads from. The dream never mutates this store.
  struct BetaDreamMemoryStoreInput
    include JSON::Serializable

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    getter type : String = "memory_store"

    def initialize(@memory_store_id : String)
      @type = "memory_store"
    end
  end

  # Input session transcripts the dream reads.
  struct BetaDreamSessionsInput
    include JSON::Serializable

    @[JSON::Field(key: "session_ids")]
    getter session_ids : Array(String)

    getter type : String = "sessions"

    def initialize(@session_ids : Array(String))
      @type = "sessions"
    end
  end

  # Discriminated union of dream input sources.
  alias BetaDreamInput = BetaDreamMemoryStoreInput | BetaDreamSessionsInput

  # An output memory store the dream writes consolidated memories into.
  struct BetaDreamOutput
    include JSON::Serializable

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    getter type : String = "memory_store"
  end

  # Alias matching Ruby/OpenAPI naming for the same memory-store output shape.
  alias BetaDreamMemoryStoreOutput = BetaDreamOutput

  # Cumulative token usage for the dream across every pipeline stage.
  struct BetaDreamUsage
    include JSON::Serializable

    @[JSON::Field(key: "cache_creation_input_tokens")]
    getter cache_creation_input_tokens : Int32

    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int32

    @[JSON::Field(key: "input_tokens")]
    getter input_tokens : Int32

    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int32
  end

  # Converter for a single BetaDreamInput discriminated by `"type"`.
  module BetaDreamInputConverter
    def self.from_json(pull : JSON::PullParser) : BetaDreamInput
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s)
      raw = json.to_json

      case type
      when "memory_store"
        BetaDreamMemoryStoreInput.from_json(raw)
      when "sessions"
        BetaDreamSessionsInput.from_json(raw)
      else
        raise JSON::ParseException.new(
          "Unknown BetaDreamInput type: #{type.inspect}",
          pull.line_number,
          pull.column_number
        )
      end
    end

    def self.to_json(value : BetaDreamInput, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Converter for arrays of BetaDreamInput.
  module BetaDreamInputArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaDreamInput)
      result = [] of BetaDreamInput
      pull.read_array do
        result << BetaDreamInputConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BetaDreamInput), builder : JSON::Builder)
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end

  # An asynchronous memory-consolidation job (Dreams API, research preview).
  #
  # Reads a memory store plus session transcripts and writes consolidated
  # memories into a new output memory store. Wire shapes are volatile.
  #
  # Lifecycle statuses: `"pending"`, `"running"`, `"completed"`, `"failed"`, `"canceled"`.
  struct BetaDream
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "ended_at", emit_null: false)]
    getter ended_at : String?

    @[JSON::Field(emit_null: false)]
    getter error : BetaDreamError?

    @[JSON::Field(converter: Anthropic::BetaDreamInputArrayConverter)]
    getter inputs : Array(BetaDreamInput)

    @[JSON::Field(emit_null: false)]
    getter instructions : String?

    getter model : BetaDreamModelConfig

    getter outputs : Array(BetaDreamOutput)

    @[JSON::Field(key: "session_id", emit_null: false)]
    getter session_id : String?

    # Lifecycle status: pending | running | completed | failed | canceled
    getter status : String

    getter type : String

    getter usage : BetaDreamUsage

    def pending? : Bool
      status == "pending"
    end

    def running? : Bool
      status == "running"
    end

    def completed? : Bool
      status == "completed"
    end

    def failed? : Bool
      status == "failed"
    end

    def canceled? : Bool
      status == "canceled"
    end
  end

  # Page-cursor list response for dreams (`data` + `next_page`).
  struct BetaDreamListResponse
    include JSON::Serializable

    getter data : Array(BetaDream)

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?
  end
end
