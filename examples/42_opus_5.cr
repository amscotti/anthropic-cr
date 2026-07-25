require "../src/anthropic-cr"
require "dotenv"

# Claude Opus 5 example: powerful intelligence for long-running agents and coding.
#
# Demonstrates:
# - The `CLAUDE_OPUS_5` model id (rolling `CLAUDE_OPUS` / `:opus` now point here)
# - The precise `:opus_5` shorthand
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/42_opus_5.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Claude Opus 5"
puts "=" * 60
puts

# --- 1. Direct Opus 5 call ---
puts "1. Basic call with CLAUDE_OPUS_5"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_5,
  max_tokens: 256,
  messages: [{role: "user", content: "In one sentence, what makes a great long-running agent?"}]
)

puts "Model used: #{message.model}"
puts message.text
puts
puts "=" * 60
puts

# --- 2. Rolling alias and shorthand ---
puts "2. Rolling alias CLAUDE_OPUS and :opus / :opus_5 shorthands"
puts "-" * 60
puts

puts "Anthropic::Model::CLAUDE_OPUS  => #{Anthropic::Model::CLAUDE_OPUS}"
puts "Anthropic::Model::CLAUDE_OPUS_5 => #{Anthropic::Model::CLAUDE_OPUS_5}"
puts "Anthropic.model_name(:opus)   => #{Anthropic.model_name(:opus)}"
puts "Anthropic.model_name(:opus_5) => #{Anthropic.model_name(:opus_5)}"
puts "Anthropic.model_name(:opus_4_8) => #{Anthropic.model_name(:opus_4_8)}"
puts
puts "=" * 60
puts

# --- 3. Streaming with Opus 5 ---
puts "3. Streaming a response from Opus 5"
puts "-" * 60
puts

client.messages.stream(
  model: Anthropic::Model::CLAUDE_OPUS_5,
  max_tokens: 128,
  messages: [{role: "user", content: "Count from 1 to 5, one per line."}]
) do |event|
  if event.is_a?(Anthropic::ContentBlockDeltaEvent) && (text = event.text)
    print text
  end
end
puts
puts
puts "=" * 60
puts "Done!"
