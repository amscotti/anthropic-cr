require "../src/anthropic-cr"
require "dotenv"

# Claude Opus 4.7 example: frontier-intelligence agent model
#
# Demonstrates features shipped with the Opus 4.7 release (April 2026):
# - The `CLAUDE_OPUS_4_7` model id (rolling `CLAUDE_OPUS` alias now points here)
# - The `xhigh` effort level
# - `BetaTokenTaskBudget` for session-wide token budgeting
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/34_opus_47.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Claude Opus 4.7"
puts "=" * 60
puts

# --- 1. Direct Opus 4.7 call ---
puts "1. Basic call with CLAUDE_OPUS_4_7"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_7,
  max_tokens: 1024,
  messages: [{role: "user", content: "Give me one-sentence advice for debugging a flaky test."}]
)

puts message.text
puts
puts "=" * 60
puts

# --- 2. xhigh effort via OutputConfig ---
puts "2. xhigh effort level (Opus 4.7)"
puts "-" * 60
puts

message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_7,
  max_tokens: 4096,
  output_config: Anthropic::OutputConfig.new(effort: "xhigh"),
  messages: [{role: "user", content: "Sketch an algorithm to detect cycles in a directed graph."}]
)

puts message.text
puts
puts "=" * 60
puts

# --- 3. Session-wide token budget ---
puts "3. BetaTokenTaskBudget: cap total tokens across contexts"
puts "-" * 60
puts

budget = Anthropic::BetaTokenTaskBudget.new(total: 150_000)
output_config = Anthropic::OutputConfig.new(effort: "high", task_budget: budget)

# NOTE: `task_budget` is part of the Opus 4.7 release and may require a
# rollout before the API accepts it on your account. Until then the server
# returns a 400 "Extra inputs are not permitted" error. We catch that case
# here so the rest of the example still runs.
begin
  message = client.beta.messages.create(
    model: Anthropic::Model::CLAUDE_OPUS_4_7,
    max_tokens: 2048,
    output_config: output_config,
    messages: [{role: "user", content: "Summarize the benefits of opus 4.7 in three bullet points."}]
  )

  puts message.text
  puts "Configured budget: #{budget.total} tokens"
rescue ex : Anthropic::BadRequestError
  puts "task_budget not yet accepted by the API on this account:"
  puts "  #{ex.message}"
  puts
  puts "The struct still serializes correctly for future use:"
  puts Anthropic::OutputConfig.new(effort: "xhigh", task_budget: budget).to_json
end
puts
puts "=" * 60
puts "Done!"
