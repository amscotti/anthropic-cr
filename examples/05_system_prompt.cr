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
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 500,
  system: "You are a friendly pirate captain. Respond to all questions in pirate speak, using phrases like 'arr', 'matey', and 'ahoy'. Keep responses brief.",
  messages: [
    {role: "user", content: "How do I install a Ruby gem?"},
  ]
)

message.text_blocks.each { |block| puts block.text }
puts "-" * 50
puts

puts "Example: Output effort variation (concise vs thorough)..."
puts

# Low effort (concise / fast)
puts "Low effort - concise answer:"
puts "-" * 50
concise = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 200,
  system: "Answer directly in one short sentence.",
  output_config: Anthropic::OutputConfig.new(effort: "low"),
  messages: [
    {role: "user", content: "What is 2+2?"},
  ]
)
concise.text_blocks.each { |block| puts block.text }
puts "-" * 50
puts

# High effort (detailed / creative)
puts "High effort - creative brainstorming:"
puts "-" * 50
detailed = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 300,
  system: "You are a brand strategist who explains the story behind each name.",
  output_config: Anthropic::OutputConfig.new(effort: "high"),
  messages: [
    {role: "user", content: "Give me a creative name for a coffee shop."},
  ]
)
detailed.text_blocks.each { |block| puts block.text }
puts "-" * 50
