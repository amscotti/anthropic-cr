require "../src/anthropic"
require "dotenv"
require "http/client"
require "json"

# Interactive Chatbot Example
#
# An interactive terminal chatbot that:
# - Streams responses in real-time
# - Supports multi-turn conversations
# - Uses Anthropic's web search API for real-time information
# - Has a calculator tool for math operations
#
# Tools:
# - web_search: Server-side tool (executed by Anthropic API)
# - calculator: Client-side tool (executed locally)
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/20_chatbot.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

# ============================================================================
# Chatbot Class
# ============================================================================

class Chatbot
  # Define client-side tools (calculator only - web search is server-side)
  def self.create_tools : Array(Anthropic::Tool)
    calculator_tool = Anthropic.tool(
      name: "calculator",
      description: "Perform mathematical calculations. Supports basic arithmetic.",
      schema: {
        "expression" => Anthropic::Schema.string("Math expression like '2 + 2' or '15 * 7'"),
      },
      required: ["expression"]
    ) do |input|
      expr = input["expression"].as_s
      result = case expr
               when /^(\d+(?:\.\d+)?)\s*\+\s*(\d+(?:\.\d+)?)$/
                 ($1.to_f + $2.to_f).to_s
               when /^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)$/
                 ($1.to_f - $2.to_f).to_s
               when /^(\d+(?:\.\d+)?)\s*\*\s*(\d+(?:\.\d+)?)$/
                 ($1.to_f * $2.to_f).to_s
               when /^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/
                 denom = $2.to_f
                 denom != 0 ? ($1.to_f / denom).to_s : "Error: Division by zero"
               else
                 "Error: Could not parse '#{expr}'"
               end
      puts "\n    [Calculator: #{expr} = #{result}]"
      result
    end

    [calculator_tool] of Anthropic::Tool
  end

  # Create server-side tools (web search via Anthropic API)
  def self.create_server_tools : Array(Anthropic::ServerTool)
    [Anthropic::WebSearchTool.new] of Anthropic::ServerTool
  end

  @client : Anthropic::Client
  @history : Array(Anthropic::MessageParam)
  @model : String
  @system_prompt : String
  @tools : Array(Anthropic::Tool)
  @server_tools : Array(Anthropic::ServerTool)

  def initialize(
    @model : String = Anthropic::Model::CLAUDE_SONNET_4_5,
    @system_prompt : String = "You are a helpful AI assistant with access to web search and calculator tools. Be concise but thorough. When you need current information, use the web_search tool.",
  )
    @client = Anthropic::Client.new
    @history = [] of Anthropic::MessageParam
    @tools = Chatbot.create_tools
    @server_tools = Chatbot.create_server_tools
  end

  # Send a message and stream the response
  def chat(user_message : String) : String
    # Add user message to history
    @history << Anthropic::MessageParam.user(user_message)

    response_text = ""
    loop do
      # Make streaming request
      collected_content = [] of Anthropic::ToolUseContent
      current_tool_use : Anthropic::ToolUseContent? = nil
      tool_json_buffer = ""
      current_tool_id = ""
      current_tool_name = ""

      @client.messages.stream(
        model: @model,
        max_tokens: 4096,
        system: @system_prompt,
        messages: @history,
        tools: @tools,
        server_tools: @server_tools
      ) do |event|
        case event
        when Anthropic::ContentBlockStartEvent
          case event.content_block
          when Anthropic::ToolUseContent
            # Client-side tool (calculator) - needs local execution
            tool_use = event.content_block.as(Anthropic::ToolUseContent)
            current_tool_id = tool_use.id
            current_tool_name = tool_use.name
            tool_json_buffer = ""
          when Anthropic::ServerToolUseContent
            # Server-side tool (web search) - handled by Anthropic
            server_tool = event.content_block.as(Anthropic::ServerToolUseContent)
            if server_tool.name == "web_search"
              puts "\n    [Web search in progress...]"
            end
          when Anthropic::WebSearchToolResultContent
            puts "    [Search results received]"
          end
        when Anthropic::ContentBlockDeltaEvent
          # Handle text streaming
          if text = event.text
            print text
            STDOUT.flush
            response_text += text
          end

          # Handle tool use JSON accumulation
          if partial = event.partial_json
            tool_json_buffer += partial
          end
        when Anthropic::ContentBlockStopEvent
          # Finalize client-side tool use block if we were building one
          if !current_tool_id.empty?
            begin
              parsed_input = tool_json_buffer.empty? ? JSON::Any.new({} of String => JSON::Any) : JSON.parse(tool_json_buffer)
              tool_use = Anthropic::ToolUseContent.new(
                id: current_tool_id,
                name: current_tool_name,
                input: parsed_input
              )
              collected_content << tool_use
            rescue
              # JSON parse failed, skip this tool
            end
            current_tool_id = ""
            current_tool_name = ""
          end
          # Note: Server tools (web_search) don't need local execution
        when Anthropic::MessageDeltaEvent
          # Check if we need to handle tools
          if event.delta.stop_reason == "tool_use"
            # Will process tools after stream ends
          end
        end
      end

      # Check if we have client-side tools to execute
      # Note: Server tools (web_search) are executed by Anthropic automatically
      if collected_content.empty?
        # No client-side tool use - we have our final response
        # Add assistant response to history
        text_content = [Anthropic::TextContent.new(text: response_text).as(Anthropic::ContentBlock)]
        @history << Anthropic::MessageParam.new(
          role: Anthropic::Role::Assistant,
          content: text_content
        )
        break
      end

      # Execute client-side tools (calculator) and continue conversation
      puts # newline after any streamed text

      # Add assistant message with tool uses to history
      assistant_content = collected_content.map { |tool| tool.as(Anthropic::ContentBlock) }
      @history << Anthropic::MessageParam.new(
        role: Anthropic::Role::Assistant,
        content: assistant_content
      )

      # Execute client-side tools and collect results
      tool_results = collected_content.map do |tool_use|
        tool = @tools.find { |tool_def| tool_def.name == tool_use.name }
        result = if tool
                   tool.call(tool_use.input)
                 else
                   "Error: Unknown tool '#{tool_use.name}'"
                 end

        Anthropic::ToolResultContent.new(
          tool_use_id: tool_use.id,
          content: result
        ).as(Anthropic::ContentBlock)
      end

      # Add tool results to history
      @history << Anthropic::MessageParam.new(
        role: Anthropic::Role::User,
        content: tool_results
      )

      # Continue the loop to get Claude's response to tool results
      response_text = "" # Reset for next response
    end

    response_text
  end

  # Clear conversation history
  def clear_history
    @history.clear
    puts "Conversation history cleared."
  end

  # Show conversation stats
  def stats
    user_msgs = @history.count { |msg| msg.role == Anthropic::Role::User }
    asst_msgs = @history.count { |msg| msg.role == Anthropic::Role::Assistant }
    puts "Messages: #{user_msgs} user, #{asst_msgs} assistant"
  end
end

# ============================================================================
# Main Loop
# ============================================================================

puts "=" * 60
puts "  Interactive Chatbot with Streaming & Tools"
puts "=" * 60
puts
puts "Commands:"
puts "  /clear  - Clear conversation history"
puts "  /stats  - Show conversation statistics"
puts "  /quit   - Exit the chatbot"
puts
puts "Try asking:"
puts "  - \"What's 127 * 43?\"  (uses calculator)"
puts "  - \"What's the latest news about Crystal programming?\"  (uses web search)"
puts "  - \"Tell me about yourself\""
puts
puts "=" * 60
puts

bot = Chatbot.new

loop do
  print "\nYou: "
  STDOUT.flush

  input = gets
  break if input.nil?

  input = input.strip
  next if input.empty?

  case input.downcase
  when "/quit", "/exit", "/q"
    puts "Goodbye!"
    break
  when "/clear"
    bot.clear_history
    next
  when "/stats"
    bot.stats
    next
  when "/help"
    puts "Commands: /clear, /stats, /quit"
    next
  end

  print "\nClaude: "
  STDOUT.flush

  begin
    bot.chat(input)
    puts # Final newline after response
  rescue ex : Anthropic::APIError
    puts "\nError: #{ex.message}"
  rescue ex
    puts "\nUnexpected error: #{ex.message}"
  end
end
