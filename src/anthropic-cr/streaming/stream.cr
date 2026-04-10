module Anthropic
  # MessageStream class for handling Server-Sent Events (SSE) from streaming API
  #
  # Events are buffered on first iteration so that helper methods like
  # `text`, `collect_text`, `final_message`, `thinking`, and `citations`
  # can be called in any order and multiple times.
  class MessageStream
    include Enumerable(AnyStreamEvent)

    @response : HTTP::Client::Response
    @buffered_events : Array(AnyStreamEvent)?
    @snapshot : SnapshotBuilder?

    private class SnapshotBuilder
      @message_data : Hash(String, JSON::Any)?
      @tool_input_buffers = {} of Int32 => String

      def apply(event : AnyStreamEvent)
        case event
        when MessageStartEvent
          @message_data = JSON.parse(event.message.to_json).as_h
        when MessageDeltaEvent
          apply_message_delta(event)
        when ContentBlockStartEvent
          apply_content_block_start(event)
        when ContentBlockDeltaEvent
          apply_content_block_delta(event)
        end
      end

      def message : Message?
        data = @message_data
        return nil unless data

        Message.from_json(JSON::Any.new(data).to_json)
      end

      private def apply_message_delta(event : MessageDeltaEvent)
        data = @message_data
        return unless data

        if stop_reason = event.delta.stop_reason
          data["stop_reason"] = JSON::Any.new(stop_reason)
        end

        if stop_details = event.delta.stop_details
          data["stop_details"] = JSON.parse(stop_details.to_json)
        end

        if stop_sequence = event.delta.stop_sequence
          data["stop_sequence"] = JSON::Any.new(stop_sequence)
        end

        if container = event.delta.container
          data["container"] = JSON.parse(container.to_json)
        end

        if usage = data["usage"]?.try(&.as_h)
          if delta_usage = event.usage
            usage["output_tokens"] = JSON::Any.new(delta_usage.output_tokens)
          end
        end
      end

      private def apply_content_block_start(event : ContentBlockStartEvent)
        blocks = content_blocks
        return unless blocks

        block_json = JSON.parse(event.content_block.to_json)

        if event.index == blocks.size
          blocks << block_json
        elsif event.index < blocks.size
          blocks[event.index] = block_json
        end
      end

      private def apply_content_block_delta(event : ContentBlockDeltaEvent)
        block = content_block(event.index)
        return unless block

        case delta = event.delta
        when TextDelta
          append_string_field(block, "text", delta.text)
        when InputJsonDelta
          buffer = @tool_input_buffers[event.index]? || ""
          buffer += delta.partial_json
          @tool_input_buffers[event.index] = buffer

          begin
            block["input"] = JSON.parse(buffer)
          rescue JSON::ParseException
          end
        when ThinkingDelta
          append_string_field(block, "thinking", delta.thinking)
        when SignatureDelta
          block["signature"] = JSON::Any.new(delta.signature)
        when CitationsDelta
          append_citation(block, delta)
        when CompactionDelta
          append_string_field(block, "content", delta.content.to_s) if delta.content
        end
      end

      private def append_citation(block : Hash(String, JSON::Any), delta : CitationsDelta)
        citation = Citation.new(
          start_char: delta.citation.start_char_index,
          end_char: delta.citation.end_char_index,
          document_title: delta.citation.document_title,
          document_index: delta.citation.document_index,
          cited_text: delta.citation.cited_text
        )

        citations = block["citations"]?.try(&.as_a) || begin
          list = [] of JSON::Any
          block["citations"] = JSON::Any.new(list)
          list
        end

        citations << JSON.parse(citation.to_json)
      end

      private def append_string_field(block : Hash(String, JSON::Any), field : String, fragment : String)
        current = block[field]?.try(&.as_s) || ""
        block[field] = JSON::Any.new(current + fragment)
      end

      private def content_blocks : Array(JSON::Any)?
        @message_data.try { |data| data["content"]?.try(&.as_a) }
      end

      private def content_block(index : Int32) : Hash(String, JSON::Any)?
        content_blocks.try(&.[index]?).try(&.as_h)
      end
    end

    def initialize(@response)
    end

    # Iterate through all events in the stream.
    #
    # On the first call this reads from the response IO and buffers all
    # events. Subsequent calls replay from the buffer so that helpers
    # like `text`, `collect_text`, and `final_message` can be used in
    # any order and multiple times.
    def each(& : AnyStreamEvent -> _)
      events.each { |event| yield event }
    end

    # Convenience iterator for text only
    def text : TextIterator
      TextIterator.new(self)
    end

    # Collect all text into a single string
    def collect_text : String
      text.to_a.join
    end

    # Get final message after consuming the entire stream.
    #
    # Safe to call after `text`, `collect_text`, or any other helper --
    # events are buffered and replayed.
    def final_message : Message?
      ensure_snapshot.message
    end

    # Iterate only tool use deltas
    def tool_use_deltas : ToolUseIterator
      ToolUseIterator.new(self)
    end

    # Get accumulated thinking content
    def thinking : ThinkingIterator
      ThinkingIterator.new(self)
    end

    # Iterate through citations
    def citations : CitationIterator
      CitationIterator.new(self)
    end

    # Return the buffered events, reading from the response IO on
    # first access.
    private def events : Array(AnyStreamEvent)
      @buffered_events ||= read_events_from_io
    end

    # Build (or return cached) snapshot for final_message.
    private def ensure_snapshot : SnapshotBuilder
      @snapshot ||= begin
        snapshot = SnapshotBuilder.new
        events.each { |event| snapshot.apply(event) }
        snapshot
      end
    end

    # Read all events from the response IO exactly once.
    private def read_events_from_io : Array(AnyStreamEvent)
      result = [] of AnyStreamEvent
      event_type = ""
      data_lines = [] of String

      @response.body_io.each_line do |raw_line|
        line = raw_line.ends_with?('\r') ? raw_line[0...-1] : raw_line

        if line.empty?
          emit_event(event_type, data_lines) { |event| result << event }
          event_type = ""
          data_lines.clear
          next
        end

        next if line.starts_with?(":")

        if line.starts_with?("event: ")
          event_type = line[7..]
        elsif line.starts_with?("data: ")
          data_lines << line[6..]
        end
      end

      emit_event(event_type, data_lines) { |event| result << event }
      result
    end

    private def emit_event(event_type : String, data_lines : Array(String), & : AnyStreamEvent -> _)
      return if data_lines.empty?

      data = data_lines.join("\n")
      return if data == "[DONE]"

      event = parse_event(event_type, data)
      yield event if event
    end

    private def parse_event(event_type : String, data : String) : AnyStreamEvent?
      resolved_type = event_type

      if resolved_type.empty?
        resolved_type = JSON.parse(data)["type"]?.try(&.as_s) || ""
      end

      case resolved_type
      when "message_start"
        MessageStartEvent.from_json(data)
      when "message_delta"
        MessageDeltaEvent.from_json(data)
      when "message_stop"
        MessageStopEvent.from_json(data)
      when "content_block_start"
        ContentBlockStartEvent.from_json(data)
      when "content_block_delta"
        ContentBlockDeltaEvent.from_json(data)
      when "content_block_stop"
        ContentBlockStopEvent.from_json(data)
      when "ping"
        PingEvent.from_json(data)
      when "error"
        ErrorEvent.from_json(data)
      else
        nil
      end
    rescue ex : JSON::ParseException
      nil
    end

    # Iterator that yields only text deltas from ContentBlockDeltaEvent
    class TextIterator
      include Enumerable(String)

      def initialize(@stream : MessageStream)
      end

      def each(& : String -> _)
        @stream.each do |event|
          if event.is_a?(ContentBlockDeltaEvent) && (text = event.text)
            yield text
          end
        end
      end
    end

    # Iterator for tool use deltas
    class ToolUseIterator
      include Enumerable(NamedTuple(index: Int32, name: String?, partial_json: String))

      def initialize(@stream : MessageStream)
      end

      def each(& : NamedTuple(index: Int32, name: String?, partial_json: String) -> _)
        tool_names = {} of Int32 => String

        @stream.each do |event|
          case event
          when ContentBlockStartEvent
            if tool_use = event.content_block.as?(ToolUseContent)
              tool_names[event.index] = tool_use.name
            end
          when ContentBlockDeltaEvent
            if partial = event.partial_json
              yield({index: event.index, name: tool_names[event.index]?, partial_json: partial})
            end
          when ContentBlockStopEvent
            tool_names.delete(event.index)
          end
        end
      end
    end

    # Iterator for thinking content
    class ThinkingIterator
      include Enumerable(String)

      def initialize(@stream : MessageStream)
      end

      def each(& : String -> _)
        @stream.each do |event|
          case event
          when ContentBlockDeltaEvent
            if thinking = event.thinking
              yield thinking
            end
          end
        end
      end
    end

    # Iterator for citations
    class CitationIterator
      include Enumerable(Citation)

      def initialize(@stream : MessageStream)
      end

      def each(& : Citation -> _)
        @stream.each do |event|
          case event
          when ContentBlockDeltaEvent
            if citation = event.citation
              yield citation
            end
          end
        end
      end
    end
  end
end
