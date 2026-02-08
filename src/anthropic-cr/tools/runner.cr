module Anthropic
  # Configuration for automatic message compaction
  #
  # When enabled, the tool runner will automatically compress conversation
  # history when token usage exceeds the specified threshold.
  #
  # ```
  # compaction = Anthropic::CompactionConfig.new(
  #   enabled: true,
  #   context_token_threshold: 3000,
  #   on_compact: ->(before : Int32, after : Int32) {
  #     puts "Compacted: #{before} -> #{after} tokens"
  #   }
  # )
  # ```
  class CompactionConfig
    property? enabled : Bool
    property context_token_threshold : Int32
    property on_compact : Proc(Int32, Int32, Nil)?

    def initialize(
      @enabled : Bool = false,
      @context_token_threshold : Int32 = 10000,
      @on_compact : Proc(Int32, Int32, Nil)? = nil,
    )
    end

    # Create enabled compaction config with callback
    def self.enabled(
      threshold : Int32 = 10000,
      &on_compact : Int32, Int32 -> Nil
    ) : self
      new(
        enabled: true,
        context_token_threshold: threshold,
        on_compact: on_compact
      )
    end
  end

  # Automatic tool execution loop
  #
  # Runs a conversation with Claude where tools are automatically executed
  # and their results are fed back to Claude until the conversation completes.
  #
  # Supports auto-compaction to manage conversation length in extended sessions.
  #
  # ```
  # # Basic usage - iterate all messages
  # runner = client.beta.messages.tool_runner(
  #   model: "claude-sonnet-4-5-20250929",
  #   max_tokens: 1024,
  #   messages: [Anthropic::MessageParam.user("What's the weather?")],
  #   tools: [weather_tool]
  # )
  # runner.each_message { |msg| pp msg.content }
  #
  # # Step-by-step control
  # runner = client.beta.messages.tool_runner(...)
  # while msg = runner.next_message
  #   pp msg.content
  #   if some_condition
  #     runner.feed_messages([MessageParam.user("Actually, also check...")])
  #   end
  # end
  #
  # # Streaming with tool execution
  # runner.each_streaming do |event|
  #   case event
  #   when Anthropic::ContentBlockDeltaEvent
  #     print event.text # event.text is a streaming helper, not Message#text
  #   end
  # end
  # ```
  class ToolRunner
    @client : Client
    @model : String
    @max_tokens : Int32
    @initial_messages : Array(MessageParam)
    @tools : Array(Tool)
    @max_iterations : Int32
    @system : String?
    @compaction : CompactionConfig?
    @thinking : ThinkingConfig?
    @output_config : OutputConfig?
    @inference_geo : String?

    # Stateful iteration tracking
    @current_messages : Array(MessageParam)
    @iteration : Int32 = 0
    @finished : Bool = false
    @last_response : Message? = nil

    def initialize(
      @client : Client,
      @model : String,
      @max_tokens : Int32,
      messages : Array(MessageParam),
      @tools : Array(Tool),
      @max_iterations : Int32 = 10,
      @system : String? = nil,
      @compaction : CompactionConfig? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
    )
      @initial_messages = messages.dup
      @current_messages = messages.dup
    end

    # Check if the runner has finished (no more tool calls or max iterations reached)
    def finished? : Bool
      @finished
    end

    # Reset the runner to its initial state
    def reset
      @current_messages = @initial_messages.dup
      @iteration = 0
      @finished = false
      @last_response = nil
    end

    # Iterate through messages, auto-executing tools
    #
    # Yields each message response, including those with tool use.
    # Continues until max_iterations is reached or Claude stops using tools.
    #
    # If compaction is enabled, automatically compresses conversation when
    # token usage exceeds the configured threshold.
    #
    # Note: This resets the runner state before iterating.
    def each_message(&)
      reset
      while msg = next_message
        yield msg
      end
    end

    # Get the next message in the tool execution loop
    #
    # Returns nil when the loop is complete (no more tool calls or max iterations).
    # Use this for fine-grained control over the execution loop.
    #
    # ```
    # while msg = runner.next_message
    #   pp msg.content
    #   # Optionally inject messages
    #   runner.feed_messages([...]) if some_condition
    # end
    # ```
    def next_message : Message?
      return nil if @finished

      @iteration += 1
      if @iteration > @max_iterations
        @finished = true
        return nil
      end

      # Check for compaction before making request
      if should_compact?(@current_messages)
        @current_messages = compact_messages(@current_messages)
      end

      response = @client.messages.create(
        model: @model,
        max_tokens: @max_tokens,
        messages: @current_messages,
        tools: @tools,
        system: @system,
        thinking: @thinking,
        output_config: @output_config,
        inference_geo: @inference_geo
      )

      @last_response = response

      # Check if tool use is requested
      unless response.tool_use?
        @finished = true
        return response
      end

      # Execute tools and build results
      tool_results = execute_tools(response.tool_use_blocks)

      # Add assistant response and tool results to conversation
      assistant_content = parse_response_content(response)

      @current_messages << MessageParam.new(
        role: Role::Assistant,
        content: assistant_content
      )

      @current_messages << MessageParam.new(
        role: Role::User,
        content: tool_results.map(&.as(ContentBlock))
      )

      response
    end

    # Add messages to the conversation mid-loop
    #
    # Use this to inject additional context or instructions during tool execution.
    # Messages are added after the current tool results.
    #
    # ```
    # while msg = runner.next_message
    #   # Check content and inject more messages if needed
    #   runner.feed_messages([
    #     Anthropic::MessageParam.user("Here's additional context: ..."),
    #   ])
    # end
    # ```
    def feed_messages(messages : Array(MessageParam))
      @current_messages.concat(messages)
      # Reset finished state since we have new input
      @finished = false if @finished && !messages.empty?
    end

    # Add a single message to the conversation
    def feed_message(message : MessageParam)
      feed_messages([message])
    end

    # Get final message after all tool execution
    #
    # Runs the entire conversation and returns the last message.
    def final_message : Message
      last_message = nil
      each_message { |msg| last_message = msg }
      last_message || raise "No message returned"
    end

    # Run until finished and return all messages
    #
    # Executes the entire tool loop and returns all messages generated.
    #
    # ```
    # messages = runner.run_until_finished
    # messages.each { |msg| pp msg.content }
    # ```
    def run_until_finished : Array(Message)
      messages = [] of Message
      each_message { |msg| messages << msg }
      messages
    end

    # Get current runner parameters (read-only)
    #
    # Useful for inspecting or logging the current state.
    def params : NamedTuple(
      model: String,
      max_tokens: Int32,
      messages: Array(MessageParam),
      current_messages: Array(MessageParam),
      tools: Array(Tool),
      max_iterations: Int32,
      iteration: Int32,
      system: String?,
      finished: Bool,
    )
      {
        model:            @model,
        max_tokens:       @max_tokens,
        messages:         @initial_messages,
        current_messages: @current_messages,
        tools:            @tools,
        max_iterations:   @max_iterations,
        iteration:        @iteration,
        system:           @system,
        finished:         @finished,
      }
    end

    # Get the current accumulated messages (including tool results)
    def current_messages : Array(MessageParam)
      @current_messages.dup
    end

    # Get the last response received
    def last_response : Message?
      @last_response
    end

    # Iterate through streaming events while auto-executing tools
    #
    # Similar to each_message but yields streaming events in real-time.
    # Tool execution still happens between streaming responses.
    #
    # ```
    # runner.each_streaming do |event|
    #   case event
    #   when Anthropic::ContentBlockDeltaEvent
    #     if text = event.text
    #       print text
    #     end
    #   end
    # end
    # ```
    def each_streaming(&block : AnyStreamEvent ->)
      reset

      loop do
        @iteration += 1
        break if @iteration > @max_iterations

        # Check for compaction before making request
        if should_compact?(@current_messages)
          @current_messages = compact_messages(@current_messages)
        end

        # Collect tool uses during streaming
        collected_tool_uses = [] of ToolUseContent
        current_tool_id = ""
        current_tool_name = ""
        tool_json_buffer = ""
        response_text = ""

        @client.messages.stream(
          model: @model,
          max_tokens: @max_tokens,
          messages: @current_messages,
          tools: @tools,
          system: @system,
          thinking: @thinking,
          output_config: @output_config,
          inference_geo: @inference_geo
        ) do |event|
          # Yield every event to the caller
          block.call(event)

          # Also track tool uses for execution
          case event
          when ContentBlockStartEvent
            if event.content_block["type"]?.try(&.as_s) == "tool_use"
              current_tool_id = event.content_block["id"]?.try(&.as_s) || ""
              current_tool_name = event.content_block["name"]?.try(&.as_s) || ""
              tool_json_buffer = ""
            end
          when ContentBlockDeltaEvent
            if text = event.text
              response_text += text
            end
            if partial = event.partial_json
              tool_json_buffer += partial
            end
          when ContentBlockStopEvent
            if !current_tool_id.empty?
              begin
                parsed_input = tool_json_buffer.empty? ? JSON::Any.new({} of String => JSON::Any) : JSON.parse(tool_json_buffer)
                collected_tool_uses << ToolUseContent.new(
                  id: current_tool_id,
                  name: current_tool_name,
                  input: parsed_input
                )
              rescue JSON::ParseException
                # JSON parse failed, skip
              end
              current_tool_id = ""
              current_tool_name = ""
            end
          end
        end

        # If no tool uses, we're done
        if collected_tool_uses.empty?
          @finished = true
          break
        end

        # Execute tools
        tool_results = execute_tools(collected_tool_uses)

        # Build assistant content from collected data
        assistant_content = [] of ContentBlock
        unless response_text.empty?
          assistant_content << TextContent.new(text: response_text).as(ContentBlock)
        end
        collected_tool_uses.each do |tool_use|
          assistant_content << tool_use.as(ContentBlock)
        end

        @current_messages << MessageParam.new(
          role: Role::Assistant,
          content: assistant_content
        )

        @current_messages << MessageParam.new(
          role: Role::User,
          content: tool_results.map(&.as(ContentBlock))
        )
      end
    end

    # Get response content as ContentBlock array (content is already typed)
    private def parse_response_content(response : Message) : Array(ContentBlock)
      response.content
    end

    private def execute_tools(tool_uses : Array(ToolUseContent)) : Array(ToolResultContent)
      tool_uses.map do |tool_use|
        tool = @tools.find { |available_tool| available_tool.name == tool_use.name }

        if tool
          begin
            result = tool.call(tool_use.input)
            ToolResultContent.new(
              tool_use_id: tool_use.id,
              content: result
            )
          rescue ex
            ToolResultContent.new(
              tool_use_id: tool_use.id,
              content: "Error: #{ex.message}",
              is_error: true
            )
          end
        else
          ToolResultContent.new(
            tool_use_id: tool_use.id,
            content: "Unknown tool: #{tool_use.name}",
            is_error: true
          )
        end
      end
    end

    # Check if compaction is needed based on token count
    private def should_compact?(messages : Array(MessageParam)) : Bool
      return false unless @compaction.try(&.enabled?)

      threshold = @compaction.try(&.context_token_threshold) || 10000

      # Count tokens using the API
      begin
        count = @client.messages.count_tokens(
          model: @model,
          messages: messages,
          tools: @tools,
          system: @system
        )
        count.input_tokens > threshold
      rescue ex : APIError | IO::Error | Socket::Error
        # If token counting fails, don't compact
        false
      end
    end

    # Compact messages by asking Claude to summarize the conversation
    private def compact_messages(messages : Array(MessageParam)) : Array(MessageParam)
      return messages if messages.size < 3

      # Get token count before compaction
      tokens_before = begin
        @client.messages.count_tokens(
          model: @model,
          messages: messages,
          tools: @tools,
          system: @system
        ).input_tokens
      rescue ex : APIError | IO::Error | Socket::Error
        0
      end

      # Build conversation text for summarization
      conversation_text = messages.map do |msg|
        role = msg.role.to_s.capitalize
        content_text = case c = msg.content
                       when String
                         c
                       when Array
                         c.compact_map do |block|
                           block.as?(TextContent).try(&.text)
                         end.join("\n")
                       else
                         ""
                       end
        "#{role}: #{content_text}"
      end.join("\n\n")

      # Ask Claude to summarize
      summary_response = @client.messages.create(
        model: @model,
        max_tokens: 2048,
        messages: [
          MessageParam.user(
            "Please provide a concise summary of this conversation that preserves " \
            "all important context, tool usage, and results. Focus on key information " \
            "needed to continue the conversation:\n\n#{conversation_text}"
          ),
        ]
      )

      # Extract text from first text block
      text_block = summary_response.content.find(&.is_a?(TextContent)).as?(TextContent)
      summary_text = text_block.try(&.text) || ""

      # Create compacted messages: system summary + last user message
      compacted = [
        MessageParam.user("[Conversation Summary]\n#{summary_text}"),
        MessageParam.assistant("I understand. I have the context from our previous conversation. How can I help you continue?"),
      ] of MessageParam

      # Keep the last exchange if it exists
      if messages.size >= 2
        last_two = messages[-2..-1]
        compacted.concat(last_two)
      end

      # Get token count after compaction and call callback
      tokens_after = begin
        @client.messages.count_tokens(
          model: @model,
          messages: compacted,
          tools: @tools,
          system: @system
        ).input_tokens
      rescue ex : APIError | IO::Error | Socket::Error
        0
      end

      @compaction.try(&.on_compact).try(&.call(tokens_before, tokens_after))

      compacted
    end
  end
end
