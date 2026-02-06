module Anthropic
  # Beta namespace for accessing beta features
  #
  # Mirrors Ruby SDK pattern:
  # ```
  # client.beta.messages.create(
  #   betas: ["structured-outputs-2025-11-13"],
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

    # Access beta files API
    #
    # ```
    # file = client.beta.files.upload(Path["document.pdf"])
    # client.beta.files.delete(file.id)
    # ```
    def files : BetaFiles
      BetaFiles.new(@client)
    end
  end

  # Beta Messages API with explicit beta header support
  class BetaMessages
    def initialize(@client : Client)
    end

    # Create a tool runner for automatic tool execution
    #
    # ```
    # runner = client.beta.messages.tool_runner(
    #   model: "claude-sonnet-4-5-20250929",
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
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
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
      max_iterations : Int32 = 10,
      system : String? = nil,
      compaction : CompactionConfig? = nil,
      thinking : ThinkingConfig? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
    ) : ToolRunner
      ToolRunner.new(@client, model, max_tokens, messages, tools, max_iterations, system, compaction, thinking, output_config, inference_geo)
    end

    # Create a message with beta features
    #
    # ```
    # message = client.beta.messages.create(
    #   betas: ["structured-outputs-2025-11-13"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 1024,
    #   output_schema: my_schema,
    #   messages: [{role: "user", content: "Hello"}]
    # )
    # ```
    def create(
      betas : Array(String),
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Hash(String, String)? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      inference_geo : String? = nil,
    ) : Message
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      # Build output format if schema provided
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }

      # Build output_config when effort or output_format is provided
      output_config = if effort || output_format
                        OutputConfig.new(effort: effort, format: output_format)
                      else
                        nil
                      end

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
        thinking: thinking,
        output_format: effort ? nil : output_format,
        output_config: output_config,
        inference_geo: inference_geo
      )

      beta_headers = {"anthropic-beta" => betas.join(",")}
      response = @client.post("/v1/messages", params, beta_headers)
      Message.from_json(response.body)
    end

    # Stream a message with beta features
    #
    # ```
    # client.beta.messages.stream(
    #   betas: ["web-search-2025-03-05"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 1024,
    #   server_tools: [Anthropic::WebSearchTool.new],
    #   messages: [{role: "user", content: "Search for..."}]
    # ) do |event|
    #   # handle events
    # end
    # ```
    def stream(
      betas : Array(String),
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Hash(String, String)? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      inference_geo : String? = nil,
      &
    )
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      # Build output format if schema provided
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }

      # Build output_config when effort or output_format is provided
      output_config = if effort || output_format
                        OutputConfig.new(effort: effort, format: output_format)
                      else
                        nil
                      end

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
        thinking: thinking,
        output_format: effort ? nil : output_format,
        output_config: output_config,
        inference_geo: inference_geo
      )

      beta_headers = {"anthropic-beta" => betas.join(",")}

      @client.post_stream("/v1/messages", params, beta_headers) do |response|
        stream = MessageStream.new(response)
        stream.each { |event| yield event }
      end
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
  end
end
