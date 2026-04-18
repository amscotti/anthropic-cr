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
  #
  # The API returns a variety of citation location types (char, page,
  # content_block, web_search_result, search_result). This struct keeps the
  # legacy char-location fields accessible via convenience methods while
  # retaining the full raw citation payload under `citation_data` for
  # non-char-location variants.
  struct CitationsDelta
    include JSON::Serializable

    getter type : String = "citations_delta"

    @[JSON::Field(key: "citation")]
    getter citation_data : JSON::Any

    # Returns the citation location type (e.g., "char_location",
    # "page_location", "content_block_location", "web_search_result_location",
    # "search_result_location"). Defaults to "char_location" when absent for
    # backwards compatibility.
    def citation_type : String
      citation_data["type"]?.try(&.as_s) || "char_location"
    end

    # Legacy struct-style accessor for char-location citations. Returns `nil`
    # when this delta does not carry a char-location citation.
    def citation : LegacyCitationData?
      return nil if (start = citation_data["start_char_index"]?).nil?
      return nil if (finish = citation_data["end_char_index"]?).nil?

      LegacyCitationData.new(
        start_char_index: start.as_i,
        end_char_index: finish.as_i,
        document_title: citation_data["document_title"]?.try(&.as_s?),
        document_index: citation_data["document_index"]?.try(&.as_i?),
        cited_text: citation_data["cited_text"]?.try(&.as_s?)
      )
    end

    # Legacy citation payload type preserved for backwards compatibility.
    struct LegacyCitationData
      getter start_char_index : Int32
      getter end_char_index : Int32
      getter document_title : String?
      getter document_index : Int32?
      getter cited_text : String?

      def initialize(
        @start_char_index : Int32,
        @end_char_index : Int32,
        @document_title : String? = nil,
        @document_index : Int32? = nil,
        @cited_text : String? = nil,
      )
      end
    end
  end

  # Compaction delta - streaming compaction content
  #
  # `encrypted_content` is populated when the API is configured to return
  # encrypted (confidential) compaction output instead of plaintext `content`.
  struct CompactionDelta
    include JSON::Serializable

    getter type : String = "compaction_delta"
    getter content : String?

    @[JSON::Field(key: "encrypted_content", emit_null: false)]
    getter encrypted_content : String?

    def initialize(@content : String? = nil, @encrypted_content : String? = nil)
    end
  end

  # Union of all delta types
  alias StreamDelta = TextDelta | InputJsonDelta | ThinkingDelta | SignatureDelta | CitationsDelta | CompactionDelta

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
      when "compaction_delta"
        CompactionDelta.from_json(json.to_json)
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

      @[JSON::Field(emit_null: false)]
      getter container : ContainerInfo?

      @[JSON::Field(key: "stop_reason")]
      getter stop_reason : String?

      @[JSON::Field(key: "stop_details", converter: Anthropic::StopDetailsConverter, emit_null: false)]
      getter stop_details : StopDetails?

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

    # Get a char-location citation from the delta (if present).
    #
    # Returns `nil` when this delta carries a non-char-location citation
    # variant (page, content_block, web_search_result, search_result). Use
    # `citation_data`/`citation_type` on the underlying `CitationsDelta` for
    # those variants.
    def citation : Citation?
      if citations_delta = delta.as?(CitationsDelta)
        return nil unless citations_delta.citation_type == "char_location"
        data = citations_delta.citation
        return nil if data.nil?

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
