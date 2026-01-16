require "../src/anthropic-cr"
require "dotenv"

# Basic message example: Single message and multi-turn conversation
#
# Demonstrates:
# - Creating a simple message
# - Multi-turn conversation by passing message history
#
# Run with:
#   crystal run examples/01_basic_message.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# --- First request: Simple message ---
puts "=== First Request ==="
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello!"}]
)

puts "Response:"
message.content.each do |block|
  case block
  when Anthropic::TextContent
    puts block.text
  end
end
puts

# --- Second request: Multi-turn conversation ---
puts "=== Second Request (Multi-turn) ==="
puts

# Include the conversation history
message2 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    {role: "user", content: "Hello!"},
    {role: "assistant", content: message.text},
    {role: "user", content: "What did I just say to you?"},
  ]
)

puts "Response:"
message2.content.each do |block|
  case block
  when Anthropic::TextContent
    puts block.text
  end
end
