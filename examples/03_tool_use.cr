require "../src/anthropic-cr"
require "dotenv"

# Tool use example: Complete tool execution loop
#
# Demonstrates:
# - Defining a tool with Schema DSL
# - Claude requesting tool use
# - Executing the tool and sending result back
# - Getting Claude's final response
#
# Run with:
#   crystal run examples/03_tool_use.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# Define a weather tool using Schema DSL
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get the current weather for a location",
  schema: {
    "location" => Anthropic::Schema.string("City name, e.g. San Francisco, CA"),
    "unit"     => Anthropic::Schema.enum("celsius", "fahrenheit", description: "Temperature unit"),
  },
  required: ["location"]
) do |input|
  location = input["location"].as_s
  unit = input["unit"]?.try(&.as_s) || "fahrenheit"
  "The weather in #{location} is sunny and 72 degrees #{unit}."
end

# --- First request: Ask about weather ---
puts "=== First Request ==="
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "What's the weather in San Francisco?"}],
  tools: [weather_tool]
)

puts "Stop reason: #{message.stop_reason}"

# Check if Claude wants to use a tool
if message.stop_reason == "tool_use"
  tool_use = message.tool_use_blocks.first

  puts "Tool requested: #{tool_use.name}"
  puts "Tool input: #{tool_use.input}"
  puts

  # Execute the tool
  tool_result = weather_tool.call(tool_use.input)
  puts "Tool result: #{tool_result}"
  puts

  # --- Second request: Send tool result back ---
  puts "=== Second Request (with tool result) ==="
  puts

  # Build the conversation with tool result
  message2 = client.messages.create(
    model: Anthropic::Model::CLAUDE_SONNET_4_5,
    max_tokens: 1024,
    messages: [
      Anthropic::MessageParam.user("What's the weather in San Francisco?"),
      Anthropic::MessageParam.new(
        role: Anthropic::Role::Assistant,
        content: message.content
      ),
      Anthropic::MessageParam.new(
        role: Anthropic::Role::User,
        content: [
          Anthropic::ToolResultContent.new(
            tool_use_id: tool_use.id,
            content: tool_result
          ),
        ] of Anthropic::ContentBlock
      ),
    ] of Anthropic::MessageParam
  )

  puts "Final response:"
  message2.content.each do |block|
    case block
    when Anthropic::TextContent
      puts block.text
    end
  end
else
  puts "Claude responded directly without using tools"
end
