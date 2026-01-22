require "../src/anthropic-cr"

# Ollama example: Use local models via Ollama's Anthropic-compatible API
#
# Based on: https://ollama.com/blog/claude
#
# Prerequisites:
#   1. Install Ollama: https://ollama.com
#   2. Start the server: ollama serve
#   3. Pull a model: ollama pull qwen3-coder
#
# Ollama exposes an Anthropic-compatible API endpoint that allows using
# any local model with this SDK.
#
# Notes:
#   - API key is required by the SDK but ignored by Ollama (use any value)
#   - Model name is just the Ollama model name (e.g., "qwen3-coder", "llama3.2")
#
# Run with:
#   crystal run examples/25_ollama.cr

# Configure client to use Ollama's local endpoint
client = Anthropic::Client.new(
  api_key: "ollama", # Required by SDK but ignored by Ollama
  base_url: "http://localhost:11434"
)

# --- Messages example (from Ollama blog) ---
puts "=== Messages Example ==="
puts

message = client.messages.create(
  model: "qwen3-coder",
  max_tokens: 1024,
  messages: [{role: "user", content: "Write a function to check if a number is prime"}]
)

puts message.content.first.as(Anthropic::TextContent).text
puts

# --- Tool calling example (from Ollama blog) ---
puts "=== Tool Calling Example ==="
puts

# Define a weather tool
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get the current weather in a location",
  schema: {
    "location" => Anthropic::Schema.string("The city and state, e.g. San Francisco, CA"),
  },
  required: ["location"]
) do |input|
  location = input["location"].as_s
  "The weather in #{location} is sunny and 72°F."
end

message = client.messages.create(
  model: "qwen3-coder",
  max_tokens: 1024,
  messages: [{role: "user", content: "What's the weather in San Francisco?"}],
  tools: [weather_tool]
)

message.content.each do |block|
  case block
  when Anthropic::ToolUseContent
    puts "Tool: #{block.name}"
    puts "Input: #{block.input}"
  end
end
