require "../src/anthropic-cr"
require "dotenv"

# Token Counting Example
#
# Count tokens before sending a message to estimate costs.
# Useful for:
# - Pre-flight cost estimation
# - Validating message size fits context window
# - Comparing different prompt strategies
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/21_token_counting.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Token Counting Example"
puts "=" * 60
puts

# Example 1: Basic token counting
puts "Example 1: Basic Message"
puts "-" * 60

count = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  messages: [{role: "user", content: "Hello, Claude! How are you today?"}]
)

puts "Input tokens: #{count.input_tokens}"
puts

# Example 2: With system prompt
puts "Example 2: With System Prompt"
puts "-" * 60

count = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  system: "You are a helpful assistant who speaks like a pirate.",
  messages: [{role: "user", content: "Tell me about the weather."}]
)

puts "Input tokens (with system): #{count.input_tokens}"
puts

# Example 3: Multi-turn conversation
puts "Example 3: Multi-turn Conversation"
puts "-" * 60

messages = [
  Anthropic::MessageParam.user("What is 2 + 2?"),
  Anthropic::MessageParam.assistant("2 + 2 equals 4."),
  Anthropic::MessageParam.user("And what is that multiplied by 3?"),
]

count = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  messages: messages
)

puts "Input tokens (multi-turn): #{count.input_tokens}"
puts

# Example 4: With tools
puts "Example 4: With Tool Definitions"
puts "-" * 60

weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get the current weather for a location",
  schema: {
    "location" => Anthropic::Schema.string("City name"),
    "units"    => Anthropic::Schema.enum("celsius", "fahrenheit"),
  },
  required: ["location"]
) { |_| "" }

count_without_tools = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  messages: [{role: "user", content: "What's the weather in Tokyo?"}]
)

count_with_tools = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  messages: [{role: "user", content: "What's the weather in Tokyo?"}],
  tools: [weather_tool]
)

puts "Without tools: #{count_without_tools.input_tokens} tokens"
puts "With tools:    #{count_with_tools.input_tokens} tokens"
puts "Tool overhead: #{count_with_tools.input_tokens - count_without_tools.input_tokens} tokens"
puts

# Example 5: Large context estimation
puts "Example 5: Large Context"
puts "-" * 60

# Create a larger context
large_context = "This is a paragraph of text. " * 100

count = client.messages.count_tokens(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  messages: [{role: "user", content: large_context}]
)

puts "Large context tokens: #{count.input_tokens}"

# Estimate costs (example pricing - check current rates)
# Sonnet: $3 per 1M input tokens
estimated_cost = (count.input_tokens / 1_000_000.0) * 3.0
puts "Estimated input cost: $#{sprintf("%.6f", estimated_cost)}"
puts

puts "=" * 60
puts "Token counting helps you estimate costs before sending requests!"
