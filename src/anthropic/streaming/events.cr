module Anthropic
  # Base streaming event type
  # Note: JSON::Serializable is included in subclasses, not here,
  # because abstract structs cannot be instantiated by the JSON parser
  abstract struct StreamEvent
    abstract def type : String
  end

  # ==========================================================================
  # Streaming Delta Types (for content_block_delta events)
  # ==========================================================================

  # Text delta - streaming text content
  struct TextDelta
    include JSON::Serializable

    getter type : String = "text_delta"
    getter text : String

    def initialize(@text : String)
    end
  end

  # Input JSON delta - streaming tool input
  struct InputJsonDelta
    include JSON::Serializable

    getter type : String = "input_json_delta"

    @[JSON::Field(key: "partial_json")]
    getter partial_json : String

    def initialize(@partial_json : String)
    end
  end

  # Thinking delta - streaming thinking content
  struct ThinkingDelta
    include JSON::Serializable

    getter type : String = "thinking_delta"
    getter thinking : String

    def initialize(@thinking : String)
    end
  end

  # Signature delta - streaming signature
  struct SignatureDelta
    include JSON::Serializable

    getter type : String = "signature_delta"
    getter signature : String

    def initialize(@signature : String)
    end
  end

  # Citations delta - streaming citation
  struct CitationsDelta
    include JSON::Serializable

    getter type : String = "citations_delta"
    getter citation : CitationData

    struct CitationData
      include JSON::Serializable

      @[JSON::Field(key: "start_char_index")]
      getter start_char_index : Int32

      @[JSON::Field(key: "end_char_index")]
      getter end_char_index : Int32

      @[JSON::Field(key: "document_title", emit_null: false)]
      getter document_title : String?

      @[JSON::Field(key: "document_index", emit_null: false)]
      getter document_index : Int32?

      @[JSON::Field(key: "cited_text", emit_null: false)]
      getter cited_text : String?
    end
  end

  # Union of all delta types
  alias StreamDelta = TextDelta | InputJsonDelta | ThinkingDelta | SignatureDelta | CitationsDelta

  # Custom converter for StreamDelta discriminated union
  module StreamDeltaConverter
    def self.from_json(pull : JSON::PullParser) : StreamDelta
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s)

      case type
      when "text_delta"
        TextDelta.from_json(json.to_json)
      when "input_json_delta"
        InputJsonDelta.from_json(json.to_json)
      when "thinking_delta"
        ThinkingDelta.from_json(json.to_json)
      when "signature_delta"
        SignatureDelta.from_json(json.to_json)
      when "citations_delta"
        CitationsDelta.from_json(json.to_json)
      else
        # Fallback to text delta for unknown types
        TextDelta.new(text: "")
      end
    end
  end

  # Message start event
  struct MessageStartEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "message_start"
    getter message : Message
  end

  # Message delta event
  struct MessageDeltaEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "message_delta"
    getter delta : MessageDelta
    getter usage : DeltaUsage?

    struct MessageDelta
      include JSON::Serializable

      @[JSON::Field(key: "stop_reason")]
      getter stop_reason : String?

      @[JSON::Field(key: "stop_sequence")]
      getter stop_sequence : String?
    end
  end

  # Message stop event
  struct MessageStopEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "message_stop"
  end

  # Content block start event
  struct ContentBlockStartEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "content_block_start"
    getter index : Int32

    @[JSON::Field(key: "content_block", converter: Anthropic::ContentBlockConverter)]
    getter content_block : ContentBlock
  end

  # Content block delta event
  struct ContentBlockDeltaEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "content_block_delta"
    getter index : Int32

    @[JSON::Field(converter: Anthropic::StreamDeltaConverter)]
    getter delta : StreamDelta

    # Convenience method for text deltas
    def text : String?
      delta.as?(TextDelta).try(&.text)
    end

    # Convenience method for tool use deltas
    def partial_json : String?
      delta.as?(InputJsonDelta).try(&.partial_json)
    end

    # Convenience method for thinking deltas
    def thinking : String?
      delta.as?(ThinkingDelta).try(&.thinking)
    end

    # Check if this is a citation delta
    def citation? : Bool
      delta.is_a?(CitationsDelta)
    end

    # Get citation from delta (if this is a citation delta)
    def citation : Citation?
      if citations_delta = delta.as?(CitationsDelta)
        data = citations_delta.citation
        Citation.new(
          start_char: data.start_char_index,
          end_char: data.end_char_index,
          document_title: data.document_title,
          document_index: data.document_index,
          cited_text: data.cited_text
        )
      end
    end
  end

  # Content block stop event
  struct ContentBlockStopEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "content_block_stop"
    getter index : Int32
  end

  # Ping event
  struct PingEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "ping"
  end

  # Error event
  struct ErrorEvent < StreamEvent
    include JSON::Serializable

    @[JSON::Field(key: "type")]
    getter type : String = "error"
    getter error : APIErrorResponse

    struct APIErrorResponse
      include JSON::Serializable

      getter type : String
      getter message : String
    end
  end

  # Union of all event types for pattern matching
  alias AnyStreamEvent = MessageStartEvent | MessageDeltaEvent | MessageStopEvent |
                         ContentBlockStartEvent | ContentBlockDeltaEvent | ContentBlockStopEvent |
                         PingEvent | ErrorEvent
end
