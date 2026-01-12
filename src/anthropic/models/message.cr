module Anthropic
  # Message struct for API responses
  #
  # Content blocks are typed - use pattern matching or type checks:
  # ```
  # message.content.each do |block|
  #   case block
  #   when TextContent
  #     puts block.text
  #   when ToolUseContent
  #     puts "Tool: #{block.name}"
  #   when ThinkingContent
  #     puts "Thinking: #{block.thinking}"
  #   end
  # end
  # ```
  struct Message
    include JSON::Serializable

    getter id : String
    getter type : String # Always "message"
    getter role : String # "assistant"

    @[JSON::Field(converter: Anthropic::ContentBlockArrayConverter)]
    getter content : Array(ContentBlock)

    getter model : String

    @[JSON::Field(key: "stop_reason")]
    getter stop_reason : String? # "end_turn" | "max_tokens" | "stop_sequence" | "tool_use" | "pause_turn" | "refusal"

    @[JSON::Field(key: "stop_sequence")]
    getter stop_sequence : String?

    getter usage : Usage

    # Check if tool use is requested
    def tool_use? : Bool
      stop_reason == "tool_use"
    end

    # Extract tool use blocks (typed)
    def tool_use_blocks : Array(ToolUseContent)
      content.compact_map { |block| block.as?(ToolUseContent) }
    end

    # Extract text blocks (typed)
    def text_blocks : Array(TextContent)
      content.compact_map { |block| block.as?(TextContent) }
    end

    # Extract thinking blocks (typed)
    def thinking_blocks : Array(ThinkingContent)
      content.compact_map { |block| block.as?(ThinkingContent) }
    end

    # Get combined text from all text blocks
    #
    # Returns empty string if no text blocks exist.
    #
    # ```
    # puts message.text
    # ```
    def text : String
      text_blocks.map(&.text).join
    end

    # Get parsed output for structured outputs
    #
    # When using structured outputs, Claude returns JSON in the text content.
    # This method parses that JSON into a JSON::Any for easy access.
    #
    # ```
    # output = message.parsed_output
    # puts output["summary"].as_s
    # puts output["score"].as_f
    # ```
    def parsed_output : JSON::Any?
      # Find first text block and parse its content as JSON
      text_block = content.find(&.is_a?(TextContent)).as?(TextContent)
      return nil unless text_block
      return nil if text_block.text.empty?

      JSON.parse(text_block.text)
    rescue JSON::ParseException
      nil
    end

    # Check if the response contains structured output
    def structured_output? : Bool
      !parsed_output.nil?
    end
  end

  # MessageParam struct for API requests
  struct MessageParam
    include JSON::Serializable

    getter role : String
    getter content : String | Array(ContentBlock)

    def initialize(role : String | Role, @content : String | Array(ContentBlock))
      @role = role.is_a?(Role) ? role.to_s : role
    end

    # Convenience constructor for simple text messages
    def self.user(text : String) : self
      new(role: Role::User, content: text)
    end

    def self.assistant(text : String) : self
      new(role: Role::Assistant, content: text)
    end
  end
end
