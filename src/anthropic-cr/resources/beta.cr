module Anthropic
  # Beta namespace for accessing beta features
  #
  # Mirrors Ruby SDK pattern:
  # ```
  # client.beta.messages.create(
  #   betas: ["structured-outputs-2025-12-15"],
  #   ...
  # )
  # ```
  class Beta
    def initialize(@client : Client)
    end

    # Access beta messages API
    def messages : BetaMessages
      BetaMessages.new(@client)
    end

    # Access beta models API
    def models : BetaModels
      BetaModels.new(@client)
    end

    # Access beta files API
    #
    # ```
    # file = client.beta.files.upload(Path["document.pdf"])
    # client.beta.files.delete(file.id)
    # ```
    def files : BetaFiles
      BetaFiles.new(@client)
    end

    # Access beta skills API
    #
    # ```
    # skills = client.beta.skills.list
    # skill = client.beta.skills.retrieve("skill_abc123")
    # ```
    def skills : BetaSkills
      BetaSkills.new(@client)
    end
  end

  # Beta Messages API with explicit beta header support
  class BetaMessages
    def initialize(@client : Client)
    end

    def batches : BetaBatches
      BetaBatches.new(@client)
    end

    # Create a tool runner for automatic tool execution
    #
    # ```
    # runner = client.beta.messages.tool_runner(
    #   model: "claude-sonnet-4-6",
    #   max_tokens: 1024,
    #   messages: [Anthropic::MessageParam.user("What's the weather in Tokyo?")],
    #   tools: [weather_tool]
    # )
    #
    # runner.each_message { |msg| pp msg.content }
    # final = runner.final_message
    # ```
    #
    # With auto-compaction:
    # ```
    # compaction = Anthropic::CompactionConfig.enabled(threshold: 3000) { |before, after|
    #   puts "Compacted: #{before} -> #{after} tokens"
    # }
    #
    # runner = client.beta.messages.tool_runner(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   messages: messages,
    #   tools: tools,
    #   compaction: compaction
    # )
    # ```
    def tool_runner(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam),
      tools : Array(Tool),
      betas : Array(String) = [] of String,
      max_iterations : Int32 = 10,
      system : String? = nil,
      compaction : CompactionConfig? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      container : String | ContainerConfig? = nil,
    ) : ToolRunner
      ToolRunner.new(
        client: @client,
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        tools: tools,
        max_iterations: max_iterations,
        system: system,
        compaction: compaction,
        speed: speed,
        thinking: thinking,
        output_config: output_config,
        inference_geo: inference_geo,
        container: container,
        betas: betas,
        use_beta: true
      )
    end

    # Create a message with beta features
    #
    # ```
    # message = client.beta.messages.create(
    #   betas: ["structured-outputs-2025-12-15"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   output_schema: my_schema,
    #   messages: [{role: "user", content: "Hello"}]
    # )
    # ```
    def create(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
    ) : Message
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      # Build output format if schema provided
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }

      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaMessageCreateParams.new(
        model: model,
        max_tokens: max_tokens,
        messages: typed_messages,
        stream: false,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      )

      beta_headers = build_beta_headers(betas, server_tools, output_format, resolved_output_config, cache_control)
      response = @client.post("/v1/messages", params, beta_headers)
      Message.from_json(response.body)
    end

    # Stream a beta message with individual events
    #
    # ```
    # client.beta.messages.stream(
    #   betas: ["web-search-2025-03-05"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   server_tools: [Anthropic::WebSearchTool.new],
    #   messages: [{role: "user", content: "Search for..."}]
    # ) do |event|
    #   # handle events
    # end
    # ```
    def stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      &
    )
      open_stream(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        betas: betas,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tools,
        server_tools: server_tools,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_schema: output_schema,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      ) do |stream|
        stream.each { |event| yield event }
      end
    end

    # Open a beta streaming response and yield a richer stream helper object.
    def open_stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      &
    )
      typed_messages = normalize_messages(messages)
      tool_definitions = build_tool_definitions(tools, server_tools)
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }
      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaMessageCreateParams.new(
        model: model,
        max_tokens: max_tokens,
        messages: typed_messages,
        stream: true,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      )

      beta_headers = build_beta_headers(betas, server_tools, output_format, resolved_output_config, cache_control)

      @client.post_stream("/v1/messages", params, beta_headers) do |response|
        yield MessageStream.new(response)
      end
    end

    # Count tokens for a beta message request without sending it
    def count_tokens(
      model : String,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      speed : String? = nil,
    ) : TokenCountResponse
      typed_messages = normalize_messages(messages)
      tool_definitions = build_tool_definitions(tools, server_tools)
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }
      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaTokenCountParams.new(
        model: model,
        messages: typed_messages,
        system: system,
        tools: tool_definitions,
        tool_choice: tool_choice,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        speed: speed
      )

      beta_headers = build_beta_headers(
        betas,
        server_tools,
        output_format,
        resolved_output_config,
        cache_control,
        include_token_counting_beta: true
      )

      response = @client.post("/v1/messages/count_tokens?beta=true", params, beta_headers)
      TokenCountResponse.from_json(response.body)
    end

    def parse(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : TypedOutputSchema(T),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
    ) : ParsedMessage(T) forall T
      message = create(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        output_schema: output_schema,
        betas: betas,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tools,
        server_tools: server_tools,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      )

      ParsedMessage(T).new(message, message.parsed_output_as!(T))
    end

    def parse(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : OutputSchema,
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
    ) : ParsedMessage(JSON::Any)
      message = create(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        output_schema: output_schema,
        betas: betas,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tools,
        server_tools: server_tools,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      )

      ParsedMessage(JSON::Any).new(message, message.parsed_output_as!(JSON::Any))
    end

    # Convert NamedTuple messages to MessageParam array
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

    # Build combined tool definitions from user tools and server tools
    private def build_tool_definitions(
      tools : Array(Tool)?,
      server_tools : Array(ServerTool)?,
    ) : Array(ToolDefinition | ServerTool)?
      return nil if (tools.nil? || tools.empty?) && (server_tools.nil? || server_tools.empty?)

      result = [] of ToolDefinition | ServerTool

      tools.try &.each do |tool|
        result << tool.to_definition
      end

      server_tools.try &.each do |server_tool|
        result << server_tool
      end

      result.empty? ? nil : result
    end

    private def merge_output_config(
      output_config : OutputConfig?,
      effort : String?,
      output_format : OutputFormat?,
    ) : OutputConfig?
      return output_config unless effort || output_format

      OutputConfig.new(
        effort: output_config.try(&.effort) || effort,
        format: output_config.try(&.format) || output_format
      )
    end

    private def build_beta_headers(
      betas : Array(String),
      server_tools : Array(ServerTool)?,
      output_format : OutputFormat?,
      output_config : OutputConfig?,
      cache_control : CacheControl?,
      include_token_counting_beta : Bool = false,
    ) : Hash(String, String)?
      merged_betas = betas.dup

      if include_token_counting_beta
        merged_betas << TOKEN_COUNTING_BETA unless merged_betas.includes?(TOKEN_COUNTING_BETA)
      end

      if requires_extended_cache_beta?(cache_control)
        merged_betas << EXTENDED_CACHE_TTL_BETA unless merged_betas.includes?(EXTENDED_CACHE_TTL_BETA)
      end

      if output_format || output_config.try(&.format)
        merged_betas << STRUCTURED_OUTPUT_BETA unless merged_betas.includes?(STRUCTURED_OUTPUT_BETA)
      end

      Anthropic.beta_headers_for_tools(server_tools).each do |beta|
        merged_betas << beta unless merged_betas.includes?(beta)
      end

      return nil if merged_betas.empty?

      {"anthropic-beta" => merged_betas.join(",")}
    end

    private def requires_extended_cache_beta?(cache_control : CacheControl?) : Bool
      (cache_control.try(&.ttl) || 0) > 0
    end
  end
end
