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
  #   model: "claude-sonnet-4-6",
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
    @speed : String?
    @thinking : ThinkingConfig?
    @output_config : OutputConfig?
    @inference_geo : String?
    @container : String | ContainerConfig?
    @betas : Array(String)
    @use_beta : Bool

    # Stateful iteration tracking
    @current_messages : Array(MessageParam)
    @iteration : Int32 = 0
    @finished : Bool = false
    @last_response : Message? = nil
    @initial_container : String | ContainerConfig?

    # Mid-conversation tool changes queued for the next request, local
    # dispatch overrides (`nil` stops a tool from running), and a pending
    # explicit compaction request.
    @pending_tool_changes : Array(ContentBlock) = [] of ContentBlock
    @tool_overrides : Hash(String, Tool?) = {} of String => Tool?
    @pending_compaction : CompactionParam? = nil

    def initialize(
      @client : Client,
      @model : String,
      @max_tokens : Int32,
      messages : Array(MessageParam),
      @tools : Array(Tool),
      @max_iterations : Int32 = 10,
      @system : String? = nil,
      @compaction : CompactionConfig? = nil,
      @speed : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
      @container : String | ContainerConfig? = nil,
      @betas : Array(String) = [] of String,
      @use_beta : Bool = false,
    )
      @initial_messages = messages.dup
      @current_messages = messages.dup
      @initial_container = @container
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
      @container = @initial_container
      @pending_tool_changes.clear
      @tool_overrides.clear
      @pending_compaction = nil
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

      last_stop_reason = @last_response.try(&.stop_reason)

      # A pending explicit compaction runs before queued tool changes
      # flush, so a successful compaction returns early with the changes
      # still queued for the follow-up turn. Compaction turns don't burn
      # an iteration. The API can't compact a conversation that ends
      # mid-turn, so a paused turn resumes first.
      if compaction = @pending_compaction
        unless resume_stop_reason?(last_stop_reason)
          if compacted = compaction_turn(compaction)
            return compacted
          end
        end
      end

      @iteration += 1
      if @iteration > @max_iterations
        @finished = true
        return nil
      end

      # A paused turn goes back as the last message, so queued tool
      # changes wait for the request after it.
      send_pending_tool_changes unless last_stop_reason == "pause_turn"
      inline_beta = history_has_tool_changes?

      # Check for compaction before making request
      if should_compact?(@current_messages)
        @current_messages = compact_messages(@current_messages)
      end

      response = create_message(
        @current_messages,
        max_tokens: @max_tokens,
        tools: @tools,
        system: @system,
        speed: @speed,
        thinking: @thinking,
        output_config: @output_config,
        inference_geo: @inference_geo,
        container: @container,
        betas: inline_beta ? with_inline_tools_beta : nil
      )

      @last_response = response
      update_container(response.container_id)

      # A paused turn is sent back unchanged so the server continues it.
      # No tool calls run; the loop proceeds with the resumed history.
      if resume_stop_reason?(response.stop_reason)
        @current_messages << MessageParam.new(
          role: Role::Assistant,
          content: parse_response_content(response)
        )
        return response
      end

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

    # Offer more tools from the next request on.
    #
    # Sends the tools' full definitions in `tool_addition` blocks with the
    # next request, leaving the runner's `tools` and the prompt cache
    # alone. A `Tool` runs under its name straight away, replacing a
    # same-name tool even for a call already in the message being handled;
    # a raw `ToolDefinition` is never run here and stops a same-name tool
    # from running. Needs the `inline-tools-2026-09-15` beta (attached
    # automatically when changes are sent). Requires a beta runner
    # (`use_beta: true`).
    #
    # Queued changes only take effect on manual `next_message` loops: the
    # `each_*`, `final_message`, and `run_until_finished` entry points
    # reset the runner first, dropping anything queued before the run.
    #
    # ```
    # runner.add_tools(my_tool)
    # ```
    def add_tools(*tools : Tool | ToolDefinition)
      unless @use_beta
        raise ArgumentError.new("add_tools requires a beta tool runner (use_beta: true)")
      end

      tools.each do |tool|
        definition, runnable = case tool
                               when Tool
                                 {tool.to_definition, tool}
                               else
                                 {tool.as(ToolDefinition), nil}
                               end
        @tool_overrides[definition.name] = runnable
        @pending_tool_changes << ToolAdditionContent.new(
          tool: ToolChangeToolDefinition.new(
            definition: JSON.parse(definition.to_json)
          )
        ).as(ContentBlock)
      end
    end

    # Withdraw tools from the next request on.
    #
    # Sends `tool_removal` blocks with the next request. The tools stop
    # being run straight away, so a call to one gets the "not found" error
    # result. Needs the `inline-tools-2026-09-15` beta (attached
    # automatically when changes are sent). Requires a beta runner
    # (`use_beta: true`).
    #
    # Queued changes only take effect on manual `next_message` loops: the
    # `each_*`, `final_message`, and `run_until_finished` entry points
    # reset the runner first, dropping anything queued before the run.
    #
    # ```
    # runner.remove_tools("legacy_tool")
    # ```
    def remove_tools(*tools : Tool | String)
      unless @use_beta
        raise ArgumentError.new("remove_tools requires a beta tool runner (use_beta: true)")
      end

      tools.each do |tool|
        name = tool.is_a?(Tool) ? tool.name : tool.to_s
        @tool_overrides[name] = nil
        @pending_tool_changes << ToolRemovalContent.new(
          tool: ToolChangeToolReference.new(name: name)
        ).as(ContentBlock)
      end
    end

    # Compact the conversation before the model's next turn.
    #
    # Once the current turn has finished, including any tool calls, the
    # runner asks the API for a summary and replaces its messages with the
    # compaction response, which is returned like any other message.
    # Requires a beta runner (`use_beta: true`) and the
    # `compact-2026-09-04` beta (attached automatically).
    #
    # Only takes effect on manual `next_message` loops: the `each_*`,
    # `final_message`, and `run_until_finished` entry points reset the
    # runner first, dropping a request queued before the run.
    #
    # ```
    # runner.compact_before_next_turn
    # ```
    def compact_before_next_turn(compaction : CompactionParam? = nil)
      unless @use_beta
        raise ArgumentError.new("compact_before_next_turn requires a beta tool runner (use_beta: true)")
      end

      @pending_compaction = compaction || SummarizeCompaction.new
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
      container: String | ContainerConfig?,
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
        container:        @container,
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
    # A pending explicit compaction runs silently as a single
    # non-streaming turn (no events are yielded for it); the replaced
    # conversation then streams normally.
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
      last_stop_reason : String? = nil

      loop do
        # Explicit compaction runs as a single non-streaming turn before
        # queued tool changes flush; the replaced conversation then
        # streams normally. Compaction turns don't burn an iteration.
        # The API can't compact a conversation that ends mid-turn, so a
        # paused turn resumes first.
        if compaction = @pending_compaction
          compaction_turn(compaction) unless resume_stop_reason?(last_stop_reason)
        end

        @iteration += 1
        if @iteration > @max_iterations
          @finished = true
          break
        end

        # A paused turn goes back as the last message, so queued tool
        # changes wait for the request after it.
        send_pending_tool_changes unless last_stop_reason == "pause_turn"
        inline_beta = history_has_tool_changes?

        # Check for compaction before making request
        if should_compact?(@current_messages)
          @current_messages = compact_messages(@current_messages)
        end

        # Accumulate the full message (thinking, text, tool uses) so
        # resumes and tool turns replay complete content.
        snapshot = SnapshotBuilder.new

        stream_messages(
          @current_messages,
          max_tokens: @max_tokens,
          tools: @tools,
          system: @system,
          speed: @speed,
          thinking: @thinking,
          output_config: @output_config,
          inference_geo: @inference_geo,
          container: @container,
          betas: inline_beta ? with_inline_tools_beta : nil
        ) do |event|
          # Yield every event to the caller
          block.call(event)

          snapshot.apply(event)
          track_streaming_container(event)
        end

        final = snapshot.message
        stop_reason = final.try(&.stop_reason)
        last_stop_reason = stop_reason

        # A paused turn resumes: send it back unchanged so the server
        # continues it.
        if resume_stop_reason?(stop_reason) && final
          @current_messages << MessageParam.new(
            role: Role::Assistant,
            content: final.content
          )
          next
        end

        # Tools run only on tool_use turns; any other stop reason ends
        # the loop without executing, even if blocks are present.
        tool_uses = final.try(&.tool_use_blocks) || [] of ToolUseContent
        if stop_reason == "tool_use" && !tool_uses.empty? && final
          # Execute tools
          tool_results = execute_tools(tool_uses)

          @current_messages << MessageParam.new(
            role: Role::Assistant,
            content: final.content
          )

          @current_messages << MessageParam.new(
            role: Role::User,
            content: tool_results.map(&.as(ContentBlock))
          )
        else
          @finished = true
          break
        end
      end
    end

    # Stop reasons for unfinished turns. `pause_turn` pauses a
    # long-running turn; `compaction` hands the turn back before the
    # model answers (pause after compaction). Sending the turn back
    # unchanged continues it.
    RESUME_STOP_REASONS = ["pause_turn", "compaction"]

    private def resume_stop_reason?(stop_reason : String?) : Bool
      !!stop_reason && RESUME_STOP_REASONS.includes?(stop_reason)
    end

    # Flush queued tool changes as a trailing system message.
    #
    # Returns whether anything was sent (the request then needs the
    # inline-tools beta).
    private def send_pending_tool_changes : Bool
      return false if @pending_tool_changes.empty?

      @current_messages << MessageParam.new(
        role: Role::System,
        content: @pending_tool_changes.dup
      )
      @pending_tool_changes.clear
      true
    end

    # Whether the current history carries tool-change blocks. Derived
    # from the messages so a failed turn's retry still attaches the
    # inline-tools beta for the already-flushed blocks.
    private def history_has_tool_changes? : Bool
      @current_messages.any? do |message|
        content = message.content
        next false if content.is_a?(String)

        content.any? { |block| block.is_a?(ToolAdditionContent) || block.is_a?(ToolRemovalContent) }
      end
    end

    # Runner betas plus the inline-tools beta for tool-change requests.
    private def with_inline_tools_beta : Array(String)
      betas = @betas.dup
      betas << INLINE_TOOLS_2026_09_15_BETA unless betas.includes?(INLINE_TOOLS_2026_09_15_BETA)
      betas
    end

    # Run one explicit compaction turn.
    #
    # Returns the compaction response after replacing the conversation
    # with it, or `nil` when the server returned no summary (the caller
    # then proceeds with a normal turn). The pending request clears only
    # once the turn succeeds, so a transport failure preserves it for
    # the next turn's retry.
    private def compaction_turn(compaction : CompactionParam) : Message?
      unless @use_beta
        raise ArgumentError.new("compact_before_next_turn requires a beta tool runner (use_beta: true)")
      end

      # Compaction turns sample no reply, so a structured-output format
      # is incompatible with them; effort and task budgets carry over.
      output_config = @output_config
      if (config = output_config) && config.format
        output_config = OutputConfig.new(effort: config.effort, task_budget: config.task_budget)
      end

      response = create_message(
        @current_messages,
        max_tokens: @max_tokens,
        tools: @tools,
        system: @system,
        speed: @speed,
        thinking: @thinking,
        output_config: output_config,
        inference_geo: @inference_geo,
        container: @container,
        compaction: compaction
      )
      @pending_compaction = nil

      @last_response = response
      update_container(response.container_id)

      summary = response.content.compact_map { |block| block.as?(CompactionContent) }.first?
      has_summary = summary && (!(summary.content || "").empty? || !(summary.encrypted_content || "").empty?)
      if has_summary
        @current_messages = [MessageParam.new(role: Role::Assistant, content: response.content)]
        response
      else
        Log.for("anthropic-cr.tool_runner").warn { "Compaction produced no summary; keeping the conversation as it is." }
        nil
      end
    end

    # Get response content as ContentBlock array (content is already typed)
    private def parse_response_content(response : Message) : Array(ContentBlock)
      response.content
    end

    private def execute_tools(tool_uses : Array(ToolUseContent)) : Array(ToolResultContent)
      # Mid-conversation tool_removal / tool_addition only affect local dispatch;
      # removed tools take the same unknown-tool path as never-declared tools.
      available = ToolDispatch.available_tool_names(@current_messages, @tools.map(&.name))

      tool_uses.map do |tool_use|
        tool = if @tool_overrides.has_key?(tool_use.name)
                 @tool_overrides[tool_use.name]
               elsif available.includes?(tool_use.name)
                 @tools.find { |available_tool| available_tool.name == tool_use.name }
               end

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
        count = count_tokens(messages)
        count.input_tokens > threshold
      rescue ex : APIError | IO::Error | Socket::Error | OpenSSL::Error
        # If token counting fails, don't compact
        false
      end
    end

    # Compact messages by asking Claude to summarize the conversation
    private def compact_messages(messages : Array(MessageParam)) : Array(MessageParam)
      return messages if messages.size < 3

      # Get token count before compaction
      tokens_before = begin
        count_tokens(messages).input_tokens
      rescue ex : APIError | IO::Error | Socket::Error | OpenSSL::Error
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
      summary_response = create_message(
        [
          MessageParam.user(
            "Please provide a concise summary of this conversation that preserves " \
            "all important context, tool usage, and results. Focus on key information " \
            "needed to continue the conversation:\n\n#{conversation_text}"
          ),
        ],
        max_tokens: 2048,
        tools: nil,
        system: nil,
        speed: @speed,
        thinking: nil,
        output_config: nil,
        inference_geo: nil,
        container: @container
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
        count_tokens(compacted).input_tokens
      rescue ex : APIError | IO::Error | Socket::Error | OpenSSL::Error
        0
      end

      @compaction.try(&.on_compact).try(&.call(tokens_before, tokens_after))

      compacted
    end

    # Track container reassignment during streaming. Content
    # accumulation lives in `SnapshotBuilder`.
    private def track_streaming_container(event : AnyStreamEvent) : Nil
      case event
      when MessageStartEvent
        update_container(event.message.container_id)
      when MessageDeltaEvent
        update_container(event.delta.container.try(&.id))
      end
    end

    private def create_message(
      messages : Array(MessageParam),
      max_tokens : Int32,
      tools : Array(Tool)?,
      system : String?,
      speed : String?,
      thinking : ThinkingConfig?,
      output_config : OutputConfig?,
      inference_geo : String?,
      container : String | ContainerConfig?,
      betas : Array(String)? = nil,
      compaction : CompactionParam? = nil,
    ) : Message
      if @use_beta
        @client.beta.messages.create(
          betas: betas || @betas,
          model: @model,
          max_tokens: max_tokens,
          messages: messages,
          tools: tools,
          system: system,
          speed: speed,
          thinking: thinking,
          output_config: output_config,
          inference_geo: inference_geo,
          container: container,
          compaction: compaction,
          extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::BETA_TOOL_RUNNER)
        )
      else
        @client.messages.create(
          model: @model,
          max_tokens: max_tokens,
          messages: messages,
          tools: tools,
          system: system,
          thinking: thinking,
          output_config: output_config,
          inference_geo: inference_geo,
          container: non_beta_container_id(container),
          extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::BETA_TOOL_RUNNER)
        )
      end
    end

    private def stream_messages(
      messages : Array(MessageParam),
      max_tokens : Int32,
      tools : Array(Tool)?,
      system : String?,
      speed : String?,
      thinking : ThinkingConfig?,
      output_config : OutputConfig?,
      inference_geo : String?,
      container : String | ContainerConfig?,
      betas : Array(String)? = nil,
      &block : AnyStreamEvent ->
    )
      if @use_beta
        @client.beta.messages.stream(
          betas: betas || @betas,
          model: @model,
          max_tokens: max_tokens,
          messages: messages,
          tools: tools,
          system: system,
          speed: speed,
          thinking: thinking,
          output_config: output_config,
          inference_geo: inference_geo,
          container: container,
          extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::BETA_TOOL_RUNNER)
        ) do |event|
          block.call(event)
        end
      else
        @client.messages.stream(
          model: @model,
          max_tokens: max_tokens,
          messages: messages,
          tools: tools,
          system: system,
          thinking: thinking,
          output_config: output_config,
          inference_geo: inference_geo,
          container: non_beta_container_id(container),
          extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::BETA_TOOL_RUNNER)
        ) do |event|
          block.call(event)
        end
      end
    end

    private def count_tokens(messages : Array(MessageParam)) : TokenCountResponse
      if @use_beta
        @client.beta.messages.count_tokens(
          betas: history_has_tool_changes? ? with_inline_tools_beta : @betas,
          model: @model,
          messages: messages,
          tools: @tools,
          system: @system,
          thinking: @thinking,
          output_config: @output_config,
          inference_geo: @inference_geo,
          container: @container,
          speed: @speed
        )
      else
        @client.messages.count_tokens(
          model: @model,
          messages: messages,
          tools: @tools,
          system: @system,
          thinking: @thinking,
          output_config: @output_config,
          inference_geo: @inference_geo
        )
      end
    end

    private def update_container(container_id : String?)
      return unless container_id

      @container = container_id
    end

    private def non_beta_container_id(container : String | ContainerConfig?) : String?
      case container
      when String
        container
      else
        nil
      end
    end
  end

  # Shared helpers for folding mid-conversation tool_removal / tool_addition
  # blocks over the locally runnable tool set (mirrors official SDK tool dispatch).
  #
  # Only `role: "system"` messages carry these blocks. Only a `tool_reference`
  # can name a locally runnable tool — MCP references execute server-side and
  # are ignored. `mid_conv_system` content is walked one level deep.
  module ToolDispatch
    extend self

    # Fold mid-conversation tool_removal / tool_addition over `tool_names`.
    #
    # Removal of an absent name is a set no-op. Addition is unconditional; the
    # runner still requires a registry hit to execute a tool.
    def available_tool_names(messages : Array(MessageParam), tool_names : Enumerable(String)) : Set(String)
      available = Set(String).new
      tool_names.each { |name| available.add(name) }

      messages.each do |message|
        content = message.content
        next if content.is_a?(String)

        if message.role == "system"
          content.each do |block|
            apply_tool_change(block, available)
          end
        elsif message.role == "assistant"
          # A compaction block's tool changes carry the tool set in
          # effect at the end of the compacted range.
          content.each do |block|
            next unless block.is_a?(CompactionContent)

            block.tool_changes.try &.each do |change|
              case change
              when ToolAdditionContent, ToolRemovalContent
                apply_tool_change(change, available)
              end
            end
          end
        end
      end

      available
    end

    private def apply_tool_change(block : ContentBlock, available : Set(String)) : Nil
      case block
      when ToolRemovalContent, ToolAdditionContent
        apply_tool_reference_change(block, available)
      when MidConversationSystemContent
        block.content.each do |inner|
          case inner
          when ToolRemovalContent, ToolAdditionContent
            apply_tool_reference_change(inner, available)
          end
        end
      end
    end

    private def apply_tool_reference_change(
      block : ToolRemovalContent | ToolAdditionContent,
      available : Set(String),
    ) : Nil
      name = referenced_tool_name(block.tool)
      return unless name

      case block
      when ToolRemovalContent
        available.delete(name)
      when ToolAdditionContent
        available.add(name)
      end
    end

    # Locally runnable tool name for a tool-change reference, or nil for
    # MCP / unknown references (forward compatibility).
    private def referenced_tool_name(ref : ToolChangeReference) : String?
      case ref
      when ToolChangeToolReference
        ref.name
      else
        nil
      end
    end
  end
end
