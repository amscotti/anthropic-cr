require "../src/anthropic-cr"
require "dotenv"

# System prompt example: Guide Claude's behavior with system prompts
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/05_system_prompt.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Example: Claude as a pirate..."
puts "-" * 50

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 500,
  system: "You are a friendly pirate captain. Respond to all questions in pirate speak, using phrases like 'arr', 'matey', and 'ahoy'. Keep responses brief.",
  messages: [
    {role: "user", content: "How do I install a Ruby gem?"},
  ]
)

message.text_blocks.each { |block| puts block.text }
puts "-" * 50
puts

puts "Example: Temperature variation (creative vs analytical)..."
puts

# Low temperature (analytical)
puts "Low temperature (0.2) - more focused:"
puts "-" * 50
analytical = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 100,
  temperature: 0.2,
  messages: [
    {role: "user", content: "What is 2+2?"},
  ]
)
analytical.text_blocks.each { |block| puts block.text }
puts "-" * 50
puts

# High temperature (creative)
puts "High temperature (1.0) - more creative:"
puts "-" * 50
creative = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 100,
  temperature: 1.0,
  messages: [
    {role: "user", content: "Give me a creative name for a coffee shop."},
  ]
)
creative.text_blocks.each { |block| puts block.text }
puts "-" * 50
