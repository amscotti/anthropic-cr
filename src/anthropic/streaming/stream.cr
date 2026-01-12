module Anthropic
  # MessageStream class for handling Server-Sent Events (SSE) from streaming API
  class MessageStream
    include Enumerable(AnyStreamEvent)

    @response : HTTP::Client::Response

    def initialize(@response)
    end

    # Iterate through all events in the stream
    def each(& : AnyStreamEvent -> _)
      event_type = ""

      @response.body_io.each_line do |line|
        # Skip empty lines and comments
        next if line.empty?
        next if line.starts_with?(":")

        # Parse event type line
        if line.starts_with?("event: ")
          event_type = line[7..]
          next
        end

        # Parse data line
        if line.starts_with?("data: ")
          data = line[6..]
          next if data == "[DONE]"

          event = parse_event(event_type, data)
          yield event if event
        end
      end
    end

    # Convenience iterator for text only
    def text : TextIterator
      TextIterator.new(self)
    end

    # Collect all text into a single string
    def collect_text : String
      text.to_a.join
    end

    # Get final message after consuming the entire stream
    def final_message : Message?
      message = nil
      each do |event|
        case event
        when MessageStartEvent
          message = event.message
        when MessageDeltaEvent
          # Message will be updated via deltas
        end
      end
      message
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

    private def parse_event(event_type : String, data : String) : AnyStreamEvent?
      case event_type
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
        nil # Unknown event type, skip
      end
    rescue ex : JSON::ParseException
      nil # Malformed JSON, skip
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
        current_tool_name : String? = nil

        @stream.each do |event|
          case event
          when ContentBlockStartEvent
            if tool_use = event.content_block.as?(ToolUseContent)
              current_tool_name = tool_use.name
            end
          when ContentBlockDeltaEvent
            if partial = event.partial_json
              yield({index: event.index, name: current_tool_name, partial_json: partial})
            end
          when ContentBlockStopEvent
            current_tool_name = nil
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
