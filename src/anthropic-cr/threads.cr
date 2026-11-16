module Anthropic
  # Internal sentinel distinguishing omitted optional update arguments from explicit `nil`.
  struct UnsetValue
    INSTANCE = new
  end

  UNSET = UnsetValue::INSTANCE

  # Snapshot of mutable thread conversation state for reset/restore in `ToolRunner`.
  struct ThreadStateSnapshot
    getter stored_messages : Array(MessageParam)
    getter staged_messages : Array(MessageParam)
    getter anchor_mode : BetaMessageThread::AnchorMode
    getter previous_message_id : String?
    getter last_recorded_reply_id : String?
    getter container : String | ContainerConfig?

    def initialize(
      @stored_messages : Array(MessageParam),
      @staged_messages : Array(MessageParam),
      @anchor_mode : BetaMessageThread::AnchorMode,
      @previous_message_id : String?,
      @last_recorded_reply_id : String?,
      @container : String | ContainerConfig?,
    )
    end
  end

  # Stateful helper managing a server-side Beta Message Thread (`message-threads-2026-08-12`).
  #
  # Tracks conversation turns across requests, sending full history with
  # `thread: {"type": "create"}` on the first turn (or on replay recovery) and
  # only incremental messages with `thread: {"type": "continue", "previous_message_id": ...}`
  # on subsequent turns while omitting create-only fields (`system`, `tools`).
  class BetaMessageThread
    enum AnchorMode
      Create
      Continue
      Unthreaded
    end

    VALID_UNSUPPORTED_BEHAVIORS = {"error", "continue_unthreaded"}

    getter client : Client
    getter previous_message_id : String?
    getter unsupported_request_behavior : String

    @model : String
    @max_tokens : Int32
    @betas : Array(String)
    @system : SystemPrompt?
    @tools : Array(Tool)?
    @server_tools : Array(ServerTool)?
    @tool_choice : ToolChoice?
    @stop_sequences : Array(String)?
    @metadata : Metadata?
    @service_tier : String?
    @speed : String?
    @thinking : ThinkingConfig?
    @cache_control : CacheControl?
    @output_schema : BaseOutputSchema?
    @effort : String?
    @output_config : OutputConfig?
    @inference_geo : String?
    @context_management : ContextManagementConfig?
    @container : String | ContainerConfig?
    @mcp_servers : Array(MCPServerDefinition)?
    @fallbacks : FallbacksParam?
    @fallback_credit_token : FallbackCreditToken?
    @user_profile_id : String?
    @workspace_id : String?
    @extra_headers : Hash(String, String)?
    @diagnostics : DiagnosticsParam?
    @compaction : CompactionParam?

    @stored_messages : Array(MessageParam)
    @staged_messages : Array(MessageParam)
    @anchor_mode : AnchorMode = AnchorMode::Create
    @last_recorded_reply_id : String? = nil
    @create_system_fingerprint : String? = nil
    @create_tools_fingerprint : String? = nil
    @turn_in_progress : Bool = false

    # Create a new deep-copied `Array(MessageParam)` without sharing inner arrays.
    def self.deep_copy_messages(messages : Enumerable(MessageParam)) : Array(MessageParam)
      arr = messages.to_a
      return [] of MessageParam if arr.empty?

      Array(MessageParam).from_json(arr.to_json)
    end

    # Strip `cache_control` from content blocks inside historical messages when replaying.
    def self.strip_cache_control(messages : Enumerable(MessageParam)) : Array(MessageParam)
      messages.map { |msg| strip_message_cache_control(msg) }
    end

    private def self.strip_message_cache_control(msg : MessageParam) : MessageParam
      raw = JSON.parse(msg.to_json)
      hash = raw.as_h?
      return msg unless hash

      blocks = hash["content"]?.try(&.as_a?)
      return msg unless blocks

      changed = false
      cleaned_blocks = blocks.map do |block|
        block_hash = block.as_h?
        if block_hash && block_hash.has_key?("cache_control")
          changed = true
          updated = block_hash.dup
          updated.delete("cache_control")
          JSON::Any.new(updated)
        else
          block
        end
      end

      return msg unless changed

      updated_msg = hash.dup
      updated_msg["content"] = JSON::Any.new(cleaned_blocks)
      MessageParam.from_json(JSON::Any.new(updated_msg).to_json)
    end

    def initialize(
      @client : Client,
      @model : String,
      @max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)) = [] of MessageParam,
      betas : Array(String) = [] of String,
      @system : SystemPrompt? = nil,
      tools : Enumerable(Tool)? = nil,
      server_tools : Enumerable(ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Metadata? = nil,
      @service_tier : String? = nil,
      @speed : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @cache_control : CacheControl? = nil,
      @output_schema : BaseOutputSchema? = nil,
      @effort : String? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
      @context_management : ContextManagementConfig? = nil,
      @container : String | ContainerConfig? = nil,
      @mcp_servers : Array(MCPServerDefinition)? = nil,
      @fallbacks : FallbacksParam? = nil,
      @fallback_credit_token : FallbackCreditToken? = nil,
      @user_profile_id : String? = nil,
      @workspace_id : String? = nil,
      @extra_headers : Hash(String, String)? = nil,
      @diagnostics : DiagnosticsParam? = nil,
      @compaction : CompactionParam? = nil,
      @unsupported_request_behavior : String = "error",
      stored_messages : Array(MessageParam)? = nil,
      staged_messages : Array(MessageParam)? = nil,
      @anchor_mode : AnchorMode = AnchorMode::Create,
      @previous_message_id : String? = nil,
      @last_recorded_reply_id : String? = nil,
    )
      unless @client.supports_message_threads?
        raise ::NotImplementedError.new("Message threads are not supported by #{@client.class}")
      end

      unless VALID_UNSUPPORTED_BEHAVIORS.includes?(@unsupported_request_behavior)
        raise ArgumentError.new(
          "Invalid unsupported_request_behavior #{@unsupported_request_behavior.inspect}; " \
          "expected \"error\" or \"continue_unthreaded\""
        )
      end

      @betas = betas.dup
      @tools = tools.try(&.map(&.as(Tool)))
      @server_tools = server_tools.try(&.map(&.as(ServerTool)))
      @stored_messages = stored_messages ? self.class.deep_copy_messages(stored_messages) : [] of MessageParam
      @staged_messages = if staged_messages
                           self.class.deep_copy_messages(staged_messages)
                         else
                           self.class.deep_copy_messages(normalize_messages(messages))
                         end
    end

    # Return a deep copy of all messages accumulated on the thread (stored + staged).
    def messages : Array(MessageParam)
      self.class.deep_copy_messages(@stored_messages + @staged_messages)
    end

    # Snapshot of the thread's current configuration and accumulated messages.
    def params
      {
        model:                        @model,
        max_tokens:                   @max_tokens,
        messages:                     messages,
        betas:                        @betas.dup,
        system:                       @system,
        tools:                        @tools,
        server_tools:                 @server_tools,
        tool_choice:                  @tool_choice,
        stop_sequences:               @stop_sequences,
        metadata:                     @metadata,
        service_tier:                 @service_tier,
        speed:                        @speed,
        thinking:                     @thinking,
        cache_control:                @cache_control,
        output_schema:                @output_schema,
        effort:                       @effort,
        output_config:                @output_config,
        inference_geo:                @inference_geo,
        context_management:           @context_management,
        container:                    @container,
        mcp_servers:                  @mcp_servers,
        fallbacks:                    @fallbacks,
        fallback_credit_token:        @fallback_credit_token,
        user_profile_id:              @user_profile_id,
        workspace_id:                 @workspace_id,
        extra_headers:                @extra_headers,
        diagnostics:                  @diagnostics,
        compaction:                   @compaction,
        unsupported_request_behavior: @unsupported_request_behavior,
        previous_message_id:          @previous_message_id,
      }
    end

    # Stage one or more messages onto the thread for the next turn.
    def append(*items : MessageParam | Message | String | NamedTuple(role: String, content: String)) : self
      items.each { |item| append_single(item) }
      self
    end

    def append(items : Array(MessageParam)) : self
      items.each { |item| append_single(item) }
      self
    end

    def append(items : Array(Message)) : self
      items.each { |item| append_single(item) }
      self
    end

    def append(items : Array(NamedTuple(role: String, content: String))) : self
      items.each { |item| append_single(item) }
      self
    end

    # Update persistent thread parameters for subsequent turns.
    #
    # Rejects changing `system` or `tools`/`server_tools` once a thread is
    # actively continuing from `previous_message_id`; use inline tool-change
    # blocks or `fork` to change those mid-conversation.
    def update(
      model : String | UnsetValue = UNSET,
      max_tokens : Int32 | UnsetValue = UNSET,
      betas : Array(String) | UnsetValue = UNSET,
      system : SystemPrompt? | UnsetValue = UNSET,
      tools : Enumerable(Tool)? | UnsetValue = UNSET,
      server_tools : Enumerable(ServerTool)? | UnsetValue = UNSET,
      tool_choice : ToolChoice? | UnsetValue = UNSET,
      stop_sequences : Array(String)? | UnsetValue = UNSET,
      metadata : Metadata? | UnsetValue = UNSET,
      service_tier : String? | UnsetValue = UNSET,
      speed : String? | UnsetValue = UNSET,
      thinking : ThinkingConfig? | UnsetValue = UNSET,
      cache_control : CacheControl? | UnsetValue = UNSET,
      output_schema : BaseOutputSchema? | UnsetValue = UNSET,
      effort : String? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      inference_geo : String? | UnsetValue = UNSET,
      context_management : ContextManagementConfig? | UnsetValue = UNSET,
      container : String | ContainerConfig? | UnsetValue = UNSET,
      mcp_servers : Array(MCPServerDefinition)? | UnsetValue = UNSET,
      fallbacks : FallbacksParam? | UnsetValue = UNSET,
      fallback_credit_token : FallbackCreditToken? | UnsetValue = UNSET,
      user_profile_id : String? | UnsetValue = UNSET,
      workspace_id : String? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? | UnsetValue = UNSET,
      diagnostics : DiagnosticsParam? | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
    ) : self
      validate_create_only_updates(system, tools, server_tools)
      apply_core_updates(model, max_tokens, betas, system, tools, server_tools, tool_choice, stop_sequences, metadata, service_tier, speed, thinking)
      apply_output_and_context_updates(cache_control, output_schema, effort, output_config, inference_geo, context_management, container, mcp_servers)
      apply_runtime_updates(fallbacks, fallback_credit_token, user_profile_id, workspace_id, extra_headers, diagnostics, compaction)
      self
    end

    # Return an independent copy of this thread starting a fresh server thread (`create`).
    def fork : BetaMessageThread
      BetaMessageThread.new(
        client: @client,
        model: @model,
        max_tokens: @max_tokens,
        betas: @betas,
        system: @system,
        tools: @tools.try(&.dup),
        server_tools: @server_tools.try(&.dup),
        tool_choice: @tool_choice,
        stop_sequences: @stop_sequences.try(&.dup),
        metadata: @metadata,
        service_tier: @service_tier,
        speed: @speed,
        thinking: @thinking,
        cache_control: @cache_control,
        output_schema: @output_schema,
        effort: @effort,
        output_config: @output_config,
        inference_geo: @inference_geo,
        context_management: @context_management,
        container: @container,
        mcp_servers: @mcp_servers.try(&.dup),
        fallbacks: @fallbacks,
        fallback_credit_token: @fallback_credit_token,
        user_profile_id: @user_profile_id,
        workspace_id: @workspace_id,
        extra_headers: @extra_headers.try(&.dup),
        diagnostics: @diagnostics,
        compaction: @compaction,
        unsupported_request_behavior: @unsupported_request_behavior,
        stored_messages: @stored_messages,
        staged_messages: @staged_messages,
        anchor_mode: @anchor_mode.unthreaded? ? AnchorMode::Unthreaded : AnchorMode::Create,
        previous_message_id: nil,
        last_recorded_reply_id: @last_recorded_reply_id
      )
    end

    # Send the next turn on the thread (optionally staging additional messages first).
    def send(
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send([] of MessageParam, betas, compaction, output_config, extra_headers)
    end

    def send(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send(extra.to_a, betas, compaction, output_config, extra_headers)
    end

    def send(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send(messages, betas, compaction, output_config, extra_headers)
    end

    # Alias for `send` mirroring `Messages#create`.
    def create(
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send([] of MessageParam, betas, compaction, output_config, extra_headers)
    end

    def create(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send(extra.to_a, betas, compaction, output_config, extra_headers)
    end

    def create(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : Message
      perform_send(messages, betas, compaction, output_config, extra_headers)
    end

    # Send a turn and parse structured output into `T`.
    def parse(
      output_schema : TypedOutputSchema(T),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(T) forall T
      message = perform_send_for_schema([] of MessageParam, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(T).new(message, message.parsed_output_as!(T))
    end

    def parse(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      output_schema : TypedOutputSchema(T),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(T) forall T
      message = perform_send_for_schema(extra.to_a, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(T).new(message, message.parsed_output_as!(T))
    end

    def parse(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : TypedOutputSchema(T),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(T) forall T
      message = perform_send_for_schema(messages, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(T).new(message, message.parsed_output_as!(T))
    end

    # Send a turn and parse structured output as `JSON::Any`.
    def parse(
      output_schema : OutputSchema,
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(JSON::Any)
      message = perform_send_for_schema([] of MessageParam, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(JSON::Any).new(message, message.parsed_output_as!(JSON::Any))
    end

    def parse(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      output_schema : OutputSchema,
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(JSON::Any)
      message = perform_send_for_schema(extra.to_a, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(JSON::Any).new(message, message.parsed_output_as!(JSON::Any))
    end

    def parse(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : OutputSchema,
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
    ) : ParsedMessage(JSON::Any)
      message = perform_send_for_schema(messages, output_schema, betas, compaction, output_config, extra_headers)
      ParsedMessage(JSON::Any).new(message, message.parsed_output_as!(JSON::Any))
    end

    # Stream a turn on the thread, yielding SSE events and committing the reply
    # (or saving partial progress if interrupted after `message_start`).
    def stream(
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : AnyStreamEvent ->
    ) : Nil
      perform_stream([] of MessageParam, betas, compaction, output_config, extra_headers, &block)
    end

    def stream(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : AnyStreamEvent ->
    ) : Nil
      perform_stream(extra.to_a, betas, compaction, output_config, extra_headers, &block)
    end

    def stream(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : AnyStreamEvent ->
    ) : Nil
      perform_stream(messages, betas, compaction, output_config, extra_headers, &block)
    end

    # Open a streaming response on the thread, yielding the `MessageStream`.
    def open_stream(
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : MessageStream ->
    ) : Nil
      perform_open_stream([] of MessageParam, betas, compaction, output_config, extra_headers, &block)
    end

    def open_stream(
      *extra : MessageParam | Message | String | NamedTuple(role: String, content: String),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : MessageStream ->
    ) : Nil
      perform_open_stream(extra.to_a, betas, compaction, output_config, extra_headers, &block)
    end

    def open_stream(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) | UnsetValue = UNSET,
      compaction : CompactionParam? | UnsetValue = UNSET,
      output_config : OutputConfig? | UnsetValue = UNSET,
      extra_headers : Hash(String, String)? = nil,
      &block : MessageStream ->
    ) : Nil
      perform_open_stream(messages, betas, compaction, output_config, extra_headers, &block)
    end

    # Create a `ToolRunner` driven by this thread.
    def tool_runner(max_iterations : Int32 = 10) : ToolRunner
      ToolRunner.new(
        client: @client,
        model: @model,
        max_tokens: @max_tokens,
        messages: messages,
        tools: @tools || [] of Tool,
        max_iterations: max_iterations,
        system: @system,
        speed: @speed,
        thinking: @thinking,
        output_config: @output_config,
        inference_geo: @inference_geo,
        container: @container,
        betas: @betas,
        use_beta: true,
        server_tools: @server_tools,
        thread: self
      )
    end

    # Replace conversation history cleanly and start a fresh thread (`create`).
    # Used by `ToolRunner` after explicit server compaction succeeds or on `set_messages_params(messages: ...)`.
    def reset_history(messages : Array(MessageParam)) : Nil
      @stored_messages.clear
      @staged_messages = self.class.deep_copy_messages(messages)
      @anchor_mode = @anchor_mode.unthreaded? ? AnchorMode::Unthreaded : AnchorMode::Create
      @previous_message_id = nil
      @last_recorded_reply_id = nil
      @create_system_fingerprint = nil
      @create_tools_fingerprint = nil
    end

    # Capture current history & anchor state so `ToolRunner#reset` can restore it.
    def capture_state : ThreadStateSnapshot
      ThreadStateSnapshot.new(
        stored_messages: self.class.deep_copy_messages(@stored_messages),
        staged_messages: self.class.deep_copy_messages(@staged_messages),
        anchor_mode: @anchor_mode,
        previous_message_id: @previous_message_id,
        last_recorded_reply_id: @last_recorded_reply_id,
        container: @container
      )
    end

    # Restore history & anchor state from a previously captured snapshot.
    def restore_state(snapshot : ThreadStateSnapshot) : Nil
      @stored_messages = self.class.deep_copy_messages(snapshot.stored_messages)
      @staged_messages = self.class.deep_copy_messages(snapshot.staged_messages)
      @anchor_mode = snapshot.anchor_mode
      @previous_message_id = snapshot.previous_message_id
      @last_recorded_reply_id = snapshot.last_recorded_reply_id
      @container = snapshot.container
    end

    private def perform_send_for_schema(
      extra,
      output_schema : BaseOutputSchema,
      betas : Array(String) | UnsetValue,
      compaction : CompactionParam? | UnsetValue,
      output_config : OutputConfig? | UnsetValue,
      extra_headers : Hash(String, String)?,
    ) : Message
      base_oc = output_config.is_a?(UnsetValue) ? @output_config : output_config
      format = OutputFormat.from_output_schema(output_schema)
      merged_oc = OutputConfig.new(
        effort: base_oc.try(&.effort) || @effort,
        format: base_oc.try(&.format) || format,
        task_budget: base_oc.try(&.task_budget)
      )
      perform_send(extra, betas, compaction, merged_oc, extra_headers)
    end

    private def perform_send(
      extra,
      betas : Array(String) | UnsetValue,
      compaction : CompactionParam? | UnsetValue,
      output_config : OutputConfig? | UnsetValue,
      extra_headers : Hash(String, String)?,
    ) : Message
      pre_size = begin_turn(extra)

      reply = execute_with_recovery do
        params, headers = build_turn_request(
          stream: false,
          betas_override: betas,
          compaction_override: compaction,
          output_config_override: output_config,
          extra_headers_override: extra_headers
        )
        response = @client.post("/v1/messages", params, headers, beta: true)
        Message.from_json(response.body)
      end

      commit_reply(reply)
      reply
    rescue ex
      abort_turn(pre_size) if pre_size
      raise ex
    end

    private def perform_stream(
      extra,
      betas : Array(String) | UnsetValue,
      compaction : CompactionParam? | UnsetValue,
      output_config : OutputConfig? | UnsetValue,
      extra_headers : Hash(String, String)?,
      &block : AnyStreamEvent ->
    ) : Nil
      pre_size = begin_turn(extra)
      snapshot = SnapshotBuilder.new
      stream_ref : MessageStream? = nil
      started = false
      stopped = false

      begin
        execute_with_recovery do
          snapshot = SnapshotBuilder.new
          stream_ref = nil
          started = false
          stopped = false

          params, headers = build_turn_request(
            stream: true,
            betas_override: betas,
            compaction_override: compaction,
            output_config_override: output_config,
            extra_headers_override: extra_headers
          )

          @client.post_stream("/v1/messages", params, headers) do |response|
            stream = MessageStream.new(response)
            stream_ref = stream
            stream.each do |event|
              started = true if event.is_a?(MessageStartEvent)
              stopped = true if event.is_a?(MessageStopEvent)
              snapshot.apply(event)
              block.call(event)
            end
          end
        end
      ensure
        effective_started = started || (stream_ref.try(&.message_started?) || false)
        effective_stopped = stopped || (stream_ref.try(&.message_stopped?) || false)
        msg = snapshot.message || stream_ref.try(&.partial_message)
        finalize_streamed_turn(effective_started, effective_stopped, msg, pre_size)
      end
    end

    private def perform_open_stream(
      extra,
      betas : Array(String) | UnsetValue,
      compaction : CompactionParam? | UnsetValue,
      output_config : OutputConfig? | UnsetValue,
      extra_headers : Hash(String, String)?,
      &block : MessageStream ->
    ) : Nil
      pre_size = begin_turn(extra)
      stream_ref : MessageStream? = nil

      begin
        execute_with_recovery do
          stream_ref = nil
          params, headers = build_turn_request(
            stream: true,
            betas_override: betas,
            compaction_override: compaction,
            output_config_override: output_config,
            extra_headers_override: extra_headers
          )

          @client.post_stream("/v1/messages", params, headers) do |response|
            stream = MessageStream.new(response)
            stream_ref = stream
            block.call(stream)
          end
        end
      ensure
        if stream = stream_ref
          started = stream.message_started?
          stopped = stream.message_stopped?
          msg = stopped ? stream.final_message : stream.partial_message
          finalize_streamed_turn(started, stopped, msg, pre_size)
        else
          abort_turn(pre_size)
        end
      end
    end

    private def finalize_streamed_turn(
      started : Bool,
      stopped : Bool,
      msg : Message?,
      pre_size : Int32,
    ) : Nil
      if !started
        abort_turn(pre_size)
        return
      end

      if stopped && msg
        commit_reply(msg)
      else
        commit_incomplete_stream(msg)
      end
      @turn_in_progress = false
    end

    private def execute_with_recovery(&)
      after_not_found = false

      loop do
        return yield
      rescue ex : ThreadNotFoundError
        after_not_found = recover_not_found!(ex, after_not_found)
      rescue ex : ThreadAlreadyContinuedError | ThreadContinueInFlightError
        recover_continue_conflict!(ex)
      rescue ex : ThreadUnsupportedRequestError
        recover_unsupported_request!(ex)
      end
    end

    private def recover_not_found!(ex : ThreadNotFoundError, after_not_found : Bool) : Bool
      if @anchor_mode.continue?
        @anchor_mode = AnchorMode::Create
        @previous_message_id = nil
        return true
      end

      if after_not_found && @unsupported_request_behavior == "continue_unthreaded"
        @anchor_mode = AnchorMode::Unthreaded
        @previous_message_id = nil
        return after_not_found
      end

      raise ex
    end

    private def recover_continue_conflict!(ex : APIError) : Nil
      raise ex unless @anchor_mode.continue?

      @anchor_mode = AnchorMode::Create
      @previous_message_id = nil
    end

    private def recover_unsupported_request!(ex : ThreadUnsupportedRequestError) : Nil
      if @unsupported_request_behavior != "continue_unthreaded" || @anchor_mode.unthreaded?
        raise ex
      end

      @anchor_mode = AnchorMode::Unthreaded
      @previous_message_id = nil
    end

    private def begin_turn(extra) : Int32
      if @turn_in_progress
        raise RuntimeError.new("A turn is already in progress on this BetaMessageThread")
      end

      @turn_in_progress = true
      pre_size = @staged_messages.size
      extra.each { |item| append_single(item) }
      pre_size
    end

    private def abort_turn(pre_size : Int32) : Nil
      @staged_messages = @staged_messages[0...pre_size]
      @turn_in_progress = false
    end

    private def commit_reply(reply : Message) : Nil
      if reply.stop_reason == "refusal"
        unless @anchor_mode.unthreaded?
          @anchor_mode = AnchorMode::Create
          @previous_message_id = nil
        end
        @staged_messages.clear
        @turn_in_progress = false
        return
      end

      adopt_container(reply.container_id)
      @stored_messages.concat(@staged_messages)
      @stored_messages << MessageParam.new(role: Role::Assistant, content: reply.content)
      @staged_messages.clear
      @last_recorded_reply_id = reply.id

      if fallback_response?(reply) && !@anchor_mode.unthreaded?
        @anchor_mode = AnchorMode::Create
        @previous_message_id = nil
      elsif !@anchor_mode.unthreaded? && !reply.id.empty?
        @anchor_mode = AnchorMode::Continue
        @previous_message_id = reply.id
      end

      @turn_in_progress = false
    end

    private def commit_incomplete_stream(partial : Message?) : Nil
      adopt_container(partial.try(&.container_id))

      partial_blocks = filter_partial_blocks(partial.try(&.content))
      if !partial_blocks.empty?
        @stored_messages.concat(@staged_messages)
        @stored_messages << MessageParam.new(role: Role::Assistant, content: partial_blocks)
        @staged_messages.clear
      end

      unless @anchor_mode.unthreaded?
        @anchor_mode = AnchorMode::Create
        @previous_message_id = nil
      end
      @turn_in_progress = false
    end

    private def filter_partial_blocks(blocks : Array(ContentBlock)?) : Array(ContentBlock)
      return [] of ContentBlock unless blocks

      blocks.select do |block|
        if text = block.as?(TextContent)
          !text.text.empty?
        else
          true
        end
      end
    end

    private def fallback_response?(reply : Message) : Bool
      has_iter = reply.usage.iterations.try(&.any? { |iter| iter.type == "fallback_message" }) || false
      has_iter || reply.content.any?(FallbackContent)
    end

    private def adopt_container(container_id : String?) : Nil
      return if container_id.nil? || container_id.empty?

      current = @container
      if current.nil? || current.is_a?(ContainerConfig) || (current.is_a?(String) && current.empty?)
        @container = container_id
      end
    end

    private def build_turn_request(
      stream : Bool,
      betas_override : Array(String) | UnsetValue,
      compaction_override : CompactionParam? | UnsetValue,
      output_config_override : OutputConfig? | UnsetValue,
      extra_headers_override : Hash(String, String)?,
    ) : {BetaMessageCreateParams, Hash(String, String)?}
      effective_betas = betas_override.is_a?(UnsetValue) ? @betas : betas_override
      effective_compaction = compaction_override.is_a?(UnsetValue) ? @compaction : compaction_override
      base_output_config = output_config_override.is_a?(UnsetValue) ? @output_config : output_config_override

      output_format = effective_compaction ? nil : @output_schema.try { |schema| OutputFormat.from_output_schema(schema) }
      resolved_oc = merge_output_config(base_output_config, @effort, output_format)
      if effective_compaction && (config = resolved_oc) && config.format
        resolved_oc = (config.effort || config.task_budget) ? OutputConfig.new(effort: config.effort, task_budget: config.task_budget) : nil
      end

      tool_definitions = build_tool_definitions
      wire_thread : BetaThreadParam? = nil
      wire_system : SystemPrompt? = @system
      wire_tools : Array(ToolDefinition | ServerTool)? = tool_definitions
      wire_messages : Array(MessageParam)

      case @anchor_mode
      when .create?
        @create_system_fingerprint = fingerprint_system(@system)
        @create_tools_fingerprint = fingerprint_tools(tool_definitions)
        wire_thread = BetaThreadCreateParams.new
        wire_messages = self.class.strip_cache_control(@stored_messages) +
                        self.class.deep_copy_messages(@staged_messages)
      when .continue?
        prev_id = @previous_message_id || raise RuntimeError.new("Missing previous_message_id for thread continuation")
        wire_thread = BetaThreadContinueParams.new(prev_id)
        wire_system = nil
        wire_tools = nil
        wire_messages = self.class.deep_copy_messages(@staged_messages)
      else
        wire_messages = self.class.strip_cache_control(@stored_messages) +
                        self.class.deep_copy_messages(@staged_messages)
      end

      params = BetaMessageCreateParams.new(
        model: @model,
        max_tokens: @max_tokens,
        messages: wire_messages,
        stream: stream,
        system: wire_system,
        tools: wire_tools,
        tool_choice: @tool_choice,
        stop_sequences: @stop_sequences,
        metadata: @metadata,
        service_tier: @service_tier,
        speed: @speed,
        thinking: @thinking,
        cache_control: @cache_control,
        output_format: resolved_oc ? nil : output_format,
        output_config: resolved_oc,
        inference_geo: @inference_geo,
        context_management: @context_management,
        container: @container,
        mcp_servers: @mcp_servers,
        fallbacks: @fallbacks,
        fallback_credit_token: @fallback_credit_token,
        diagnostics: @diagnostics,
        compaction: effective_compaction,
        thread: wire_thread
      )

      headers = build_turn_headers(
        stream: stream,
        betas: effective_betas,
        output_format: output_format,
        output_config: resolved_oc,
        compaction: effective_compaction,
        wire_thread: wire_thread,
        extra_headers_override: extra_headers_override
      )

      {params, headers}
    end

    private def build_turn_headers(
      stream : Bool,
      betas : Array(String),
      output_format : OutputFormat?,
      output_config : OutputConfig?,
      compaction : CompactionParam?,
      wire_thread : BetaThreadParam?,
      extra_headers_override : Hash(String, String)?,
    ) : Hash(String, String)?
      merged_betas = betas.dup
      if Anthropic.fallbacks_present?(@fallbacks) || @fallback_credit_token.is_a?(String)
        merged_betas << SERVER_SIDE_FALLBACK_BETA unless merged_betas.includes?(SERVER_SIDE_FALLBACK_BETA)
      end
      if @fallback_credit_token.is_a?(FallbackCreditTokenParam)
        merged_betas << FALLBACK_CREDIT_BETA_2026_07_01 unless merged_betas.includes?(FALLBACK_CREDIT_BETA_2026_07_01)
      end

      headers = Anthropic.resolve_beta_headers(
        betas: merged_betas,
        server_tools: @server_tools,
        cache_control: @cache_control,
        diagnostics: @diagnostics,
        output_format: output_format,
        output_config: output_config,
        include_user_profiles: !@user_profile_id.nil?,
        thinking: @thinking,
        compaction: compaction,
        thread: wire_thread,
        beta: true
      )

      if uid = @user_profile_id
        headers = (headers || {} of String => String).merge({"anthropic-user-profile-id" => uid})
      end
      headers = Anthropic.merge_workspace_header(headers, @workspace_id)
      headers = Anthropic.merge_toolset_helper_headers(headers, @server_tools)
      headers = StainlessHelper.merge_helper_header(headers, StainlessHelper::MESSAGE_THREAD)
      headers = StainlessHelper.merge_method_header(headers, "stream") if stream
      headers = merge_extra_headers(headers, @extra_headers)
      merge_extra_headers(headers, extra_headers_override)
    end

    private def merge_extra_headers(
      headers : Hash(String, String)?,
      extra : Hash(String, String)?,
    ) : Hash(String, String)?
      return headers if extra.nil? || extra.empty?

      base = (headers || {} of String => String).dup
      extra.each do |key, value|
        if key.downcase == StainlessHelper::HEADER
          base = StainlessHelper.merge_helper_header(base, value)
        else
          base[key] = value
        end
      end
      base
    end

    private def build_tool_definitions : Array(ToolDefinition | ServerTool)?
      combine_tool_definitions(@tools, @server_tools)
    end

    private def merge_output_config(
      output_config : OutputConfig?,
      effort : String?,
      output_format : OutputFormat?,
    ) : OutputConfig?
      return output_config unless effort || output_format

      OutputConfig.new(
        effort: output_config.try(&.effort) || effort,
        format: output_config.try(&.format) || output_format,
        task_budget: output_config.try(&.task_budget)
      )
    end

    private def validate_create_only_updates(
      system : SystemPrompt? | UnsetValue,
      tools : Enumerable(Tool)? | UnsetValue,
      server_tools : Enumerable(ServerTool)? | UnsetValue,
    ) : Nil
      return unless @anchor_mode.continue?

      unless system.is_a?(UnsetValue)
        if fingerprint_system(system) != (@create_system_fingerprint || fingerprint_system(@system))
          raise ArgumentError.new(
            "Cannot modify `system` on a continued BetaMessageThread; fork the thread to change it"
          )
        end
      end

      unless tools.is_a?(UnsetValue) && server_tools.is_a?(UnsetValue)
        next_tools = tools.is_a?(UnsetValue) ? @tools : tools
        next_server = server_tools.is_a?(UnsetValue) ? @server_tools : server_tools
        defs = combine_tool_definitions(next_tools, next_server)
        if fingerprint_tools(defs) != (@create_tools_fingerprint || fingerprint_tools(build_tool_definitions))
          raise ArgumentError.new(
            "Cannot modify `tools` on a continued BetaMessageThread; use inline `tool_addition`/`tool_removal` blocks or fork"
          )
        end
      end
    end

    private def combine_tool_definitions(
      tools : Enumerable(Tool)?,
      server_tools : Enumerable(ServerTool)?,
    ) : Array(ToolDefinition | ServerTool)?
      result = [] of ToolDefinition | ServerTool
      tools.try &.each { |tool| result << tool.to_definition }
      server_tools.try &.each { |server_tool| result << server_tool }
      result.empty? ? nil : result
    end

    private def fingerprint_system(system : SystemPrompt?) : String
      system.to_json
    end

    private def fingerprint_tools(defs : Array(ToolDefinition | ServerTool)?) : String
      defs.to_json
    end

    private def append_single(item : MessageParam | Message | String | NamedTuple(role: String, content: String)) : Nil
      case item
      when Message
        return if @last_recorded_reply_id && item.id == @last_recorded_reply_id

        @staged_messages.concat(
          self.class.deep_copy_messages([MessageParam.new(role: item.role, content: item.content)])
        )
      when MessageParam
        @staged_messages.concat(self.class.deep_copy_messages([item]))
      when String
        @staged_messages << MessageParam.user(item)
      when NamedTuple(role: String, content: String)
        @staged_messages << MessageParam.new(role: item[:role], content: item[:content])
      end
    end

    private def normalize_messages(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
    ) : Array(MessageParam)
      case messages
      when Array(MessageParam)
        messages
      else
        messages.map { |msg| MessageParam.new(role: msg[:role], content: msg[:content]) }
      end
    end

    private def apply_core_updates(
      model, max_tokens, betas, system, tools, server_tools,
      tool_choice, stop_sequences, metadata, service_tier, speed, thinking,
    ) : Nil
      @model = model unless model.is_a?(UnsetValue)
      @max_tokens = max_tokens unless max_tokens.is_a?(UnsetValue)
      @betas = betas.dup unless betas.is_a?(UnsetValue)
      @system = system unless system.is_a?(UnsetValue)
      @tools = tools.try(&.map(&.as(Tool))) unless tools.is_a?(UnsetValue)
      @server_tools = server_tools.try(&.map(&.as(ServerTool))) unless server_tools.is_a?(UnsetValue)
      @tool_choice = tool_choice unless tool_choice.is_a?(UnsetValue)
      @stop_sequences = stop_sequences unless stop_sequences.is_a?(UnsetValue)
      @metadata = metadata unless metadata.is_a?(UnsetValue)
      @service_tier = service_tier unless service_tier.is_a?(UnsetValue)
      @speed = speed unless speed.is_a?(UnsetValue)
      @thinking = thinking unless thinking.is_a?(UnsetValue)
    end

    private def apply_output_and_context_updates(
      cache_control, output_schema, effort, output_config, inference_geo,
      context_management, container, mcp_servers,
    ) : Nil
      @cache_control = cache_control unless cache_control.is_a?(UnsetValue)
      @output_schema = output_schema unless output_schema.is_a?(UnsetValue)
      @effort = effort unless effort.is_a?(UnsetValue)
      @output_config = output_config unless output_config.is_a?(UnsetValue)
      @inference_geo = inference_geo unless inference_geo.is_a?(UnsetValue)
      @context_management = context_management unless context_management.is_a?(UnsetValue)
      @container = container unless container.is_a?(UnsetValue)
      @mcp_servers = mcp_servers unless mcp_servers.is_a?(UnsetValue)
    end

    private def apply_runtime_updates(
      fallbacks, fallback_credit_token, user_profile_id, workspace_id,
      extra_headers, diagnostics, compaction,
    ) : Nil
      @fallbacks = fallbacks unless fallbacks.is_a?(UnsetValue)
      @fallback_credit_token = fallback_credit_token unless fallback_credit_token.is_a?(UnsetValue)
      @user_profile_id = user_profile_id unless user_profile_id.is_a?(UnsetValue)
      @workspace_id = workspace_id unless workspace_id.is_a?(UnsetValue)
      @extra_headers = extra_headers unless extra_headers.is_a?(UnsetValue)
      @diagnostics = diagnostics unless diagnostics.is_a?(UnsetValue)
      @compaction = compaction unless compaction.is_a?(UnsetValue)
    end
  end
end
