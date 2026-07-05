require "../src/anthropic-cr"
require "dotenv"

# Claude Sonnet 5 & Fable 5 example: the latest generation of Claude models.
#
# Demonstrates the models added in the June/July 2026 release:
# - `CLAUDE_SONNET_5` ("claude-sonnet-5") — high-performance model for coding and agents
# - `CLAUDE_FABLE_5`  ("claude-fable-5")  — next-gen intelligence for the hardest knowledge work
# - `CLAUDE_MYTHOS_5` ("claude-mythos-5") — most capable for cybersecurity & biology research
#
# The rolling `CLAUDE_SONNET` / `CLAUDE_FABLE` aliases now point at these.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/37_sonnet_5_fable_5.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Claude Sonnet 5 & Fable 5"
puts "=" * 60
puts

# --- 1. Basic Sonnet 5 call ---
puts "1. Basic call with CLAUDE_SONNET_5 (rolling alias :sonnet)"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5,
  max_tokens: 256,
  messages: [{role: "user", content: "In one sentence, what makes Crystal's type system appealing?"}]
)

puts "Model used: #{message.model}"
puts message.text
puts
puts "=" * 60
puts

# --- 2. The :sonnet shorthand now resolves to Sonnet 5 ---
puts "2. Shorthand helper Anthropic.model_name(:sonnet)"
puts "-" * 60
puts

puts "Anthropic.model_name(:sonnet) => #{Anthropic.model_name(:sonnet)}"
puts "Anthropic.model_name(:fable)  => #{Anthropic.model_name(:fable)}"
puts "Anthropic.model_name(:mythos) => #{Anthropic.model_name(:mythos)}"
puts
puts "=" * 60
puts

# --- 3. Fable 5 — frontier knowledge work ---
puts "3. Fable 5 (CLAUDE_FABLE_5) call"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 256,
  messages: [{role: "user", content: "Give one concise, non-obvious tip for designing a rate limiter."}]
)

puts "Model used: #{message.model}"
puts message.text
puts
puts "=" * 60
puts

# --- 4. Streaming with Sonnet 5 ---
puts "4. Streaming a response from Sonnet 5"
puts "-" * 60
puts

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_5,
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
