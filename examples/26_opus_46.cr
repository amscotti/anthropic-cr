require "../src/anthropic-cr"
require "dotenv"

# Claude Opus 4.6 example: Adaptive thinking, effort control, and inference geo
#
# Demonstrates the new features available with Claude Opus 4.6:
# - Adaptive thinking (model decides how much to think)
# - Effort control via output_config
# - Inference geo for data residency
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/26_opus_46.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Claude Opus 4.6 Features"
puts "=" * 60
puts

# --- Adaptive Thinking ---
puts "1. Adaptive Thinking"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  thinking: Anthropic::ThinkingConfig.adaptive,
  messages: [
    {role: "user", content: "What is the square root of 144?"},
  ]
)

message.content.each do |block|
  case block
  when Anthropic::ThinkingContent
    puts "Thinking: #{block.thinking[0, 200]}..."
  when Anthropic::TextContent
    puts "Response: #{block.text}"
  end
end

puts
puts "=" * 60
puts

# --- Effort Control ---
puts "2. Effort Control (high effort)"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  thinking: Anthropic::ThinkingConfig.adaptive,
  output_config: Anthropic::OutputConfig.new(effort: "high"),
  messages: [
    {role: "user", content: "Write a haiku about Crystal programming."},
  ]
)

message.content.each do |block|
  case block
  when Anthropic::TextContent
    puts block.text
  end
end

puts
puts "=" * 60
puts

# --- Inference Geo ---
puts "3. Inference Geo (US region)"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  inference_geo: "us",
  messages: [
    {role: "user", content: "Hello! Where are you processing this request?"},
  ]
)

puts message.text
puts
puts "=" * 60
puts "Done!"
