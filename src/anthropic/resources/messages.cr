module Anthropic
  # Union type for all tools (user-defined and server-side)
  alias AnyTool = Tool | ServerTool

  # Messages API resource
  #
  # Note: Unlike the Ruby SDK which accepts all tools in a single `tools` array,
  # this SDK uses separate `tools` and `server_tools` parameters. This design:
  # - Provides better type safety and IDE autocompletion
  # - Automatically manages required beta headers for server tools
  # - Is more explicit about tool types being used
  class Messages
    def initialize(@client : Client)
    end

    # Create a message (non-streaming)
    #
    # ```
    # # Basic message
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 1024,
    #   messages: [{role: "user", content: "Hello!"}]
    # )
    #
    # # With extended thinking
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 4096,
    #   thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 2000),
    #   messages: [{role: "user", content: "Solve this problem..."}]
    # )
    #
    # # With web search
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 1024,
    #   tools: [Anthropic::WebSearchTool.new],
    #   messages: [{role: "user", content: "What's the latest AI news?"}]
    # )
    # ```
    def create(
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
    ) : Message
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = MessageCreateParams.new(
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
        thinking: thinking
      )

      # Build beta headers for server tools (web search requires beta)
      beta_headers = build_beta_headers(server_tools)

      response = @client.post("/v1/messages", params, beta_headers)
      Message.from_json(response.body)
    end

    # Stream a message with block
    #
    # ```
    # client.messages.stream(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   max_tokens: 1024,
    #   messages: [{role: "user", content: "Tell me a story"}]
    # ) do |event|
    #   case event
    #   when Anthropic::ContentBlockDeltaEvent
    #     print event.text
    #   end
    # end
    # ```
    def stream(
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
      &
    )
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = MessageCreateParams.new(
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
        thinking: thinking
      )

      # Build beta headers for server tools
      beta_headers = build_beta_headers(server_tools)

      @client.post_stream("/v1/messages", params, beta_headers) do |response|
        stream = MessageStream.new(response)
        stream.each { |event| yield event }
      end
    end

    # Note: Iterator-based streaming (returning MessageStream) is not implemented yet
    # due to HTTP connection lifecycle limitations. Use block-based streaming above.

    # Access batches sub-resource
    def batches : Batches
      Batches.new(@client)
    end

    # Count tokens for a message without sending it
    #
    # Useful for estimating costs before making a request.
    #
    # ```
    # count = client.messages.count_tokens(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
    #   messages: [{role: "user", content: "Hello, Claude!"}],
    #   system: "You are a helpful assistant."
    # )
    # puts "Input tokens: #{count.input_tokens}"
    # ```
    def count_tokens(
      model : String,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      thinking : ThinkingConfig? = nil,
    ) : TokenCountResponse
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = TokenCountParams.new(
        model: model,
        messages: typed_messages,
        system: system,
        tools: tool_definitions,
        tool_choice: tool_choice,
        thinking: thinking
      )

      # Build beta headers for server tools
      beta_headers = build_beta_headers(server_tools)

      response = @client.post("/v1/messages/count_tokens", params, beta_headers)
      TokenCountResponse.from_json(response.body)
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

    # Build beta headers based on server tools used
    private def build_beta_headers(server_tools : Array(ServerTool)?) : Hash(String, String)?
      return nil if server_tools.nil? || server_tools.empty?

      betas = [] of String

      server_tools.each do |tool|
        case tool
        when WebSearchTool
          betas << WEB_SEARCH_BETA unless betas.includes?(WEB_SEARCH_BETA)
        end
      end

      return nil if betas.empty?

      {"anthropic-beta" => betas.join(",")}
    end
  end
end
