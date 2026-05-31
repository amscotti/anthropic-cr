require "../src/anthropic-cr"
require "dotenv"

# Prompt Cache Diagnostics Example
#
# Shows how to use the `cache-diagnosis-2026-04-07` beta to diagnose cache
# misses by specifying a `previous_message_id` on the creation request and
# retrieving diagnostic metadata.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file.
#
# Run with:
#   crystal run examples/33_prompt_cache_diagnostics.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Prompt Cache Diagnostics Example"
puts "=" * 60
puts

# 1. Send an initial message using the beta namespace
puts "Sending initial message..."
message1 = client.beta.messages.create(
  betas: [Anthropic::CACHE_DIAGNOSTICS_BETA],
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 256,
  diagnostics: Anthropic::DiagnosticsParam.new(previous_message_id: nil),
  messages: [
    {role: "user", content: "Tell me a very brief fact about standard webhooks."},
  ]
)
puts "Message 1 ID: #{message1.id}"
puts "Response: #{message1.text.strip}"
puts

# 2. Send a second message requesting cache diagnostics compared to message 1
puts "Sending second message with diagnostics enabled..."
message2 = client.beta.messages.create(
  betas: [Anthropic::CACHE_DIAGNOSTICS_BETA],
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 256,
  diagnostics: Anthropic::DiagnosticsParam.new(previous_message_id: message1.id),
  messages: [
    {role: "user", content: "Tell me a very brief fact about standard webhooks."},
    {role: "assistant", content: message1.text},
    {role: "user", content: "Can you elaborate on how verification prevents replay attacks?"},
  ]
)

puts "Message 2 ID: #{message2.id}"
puts "Response: #{message2.text.strip}"
puts

if diagnostics = message2.diagnostics
  puts "🔍 Caching Diagnostics:"
  puts "-" * 40
  if miss_reason = diagnostics.cache_miss_reason
    puts "Cache Miss Type:  #{miss_reason.type}"
    puts "Missed Tokens:    #{miss_reason.cache_missed_input_tokens}"
  else
    puts "No cache miss diagnosed (Cache hit!)."
  end
else
  puts "No cache diagnostics returned in response."
end

puts "=" * 60
