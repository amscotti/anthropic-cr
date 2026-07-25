require "../src/anthropic-cr"
require "dotenv"

# Server-side fallbacks example (July 2026 release).
#
# When a model refuses a request for policy reasons, the server-side fallbacks
# feature lets the API automatically retry the request against a fallback model
# chain in a single round-trip. Requires the `server-side-fallback-2026-07-01`
# beta header, which the SDK attaches automatically when `fallbacks:` is set.
#
# This example sends a benign request with a fallback chain configured. Even
# though no refusal triggers here, a successful response confirms the request
# shape (the `fallbacks` param + beta header) is accepted by the API. To see an
# actual fallback, point the primary model at content it would refuse.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/39_fallbacks.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Server-Side Fallbacks"
puts "=" * 60
puts

# --- 1. Non-streaming with an explicit fallback chain ---
puts "1. Non-streaming request with explicit fallbacks"
puts "-" * 60
puts

# The SDK auto-attaches server-side-fallback-2026-07-01 when `fallbacks:` is set.
message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 256,
  fallbacks: [
    Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8),
  ],
  messages: [{role: "user", content: "In one sentence, explain what a semaphore is."}]
)

puts "Model used: #{message.model}"
puts message.text

# If a fallback actually fired, the response would carry a `fallback` content
# block and per-hop `usage.iterations`.
if fallback = message.content.find { |block| block.is_a?(Anthropic::FallbackContent) }
  fb = fallback.as(Anthropic::FallbackContent)
  puts
  category = fb.trigger.category || "unspecified"
  puts "Fallback fired: #{fb.from.model} -> #{fb.to.model} (category: #{category})"
end
puts
puts "=" * 60
puts

# --- 2. Server-defined default fallback chain ---
puts "2. Non-streaming request with fallbacks: \"default\""
puts "-" * 60
puts

default_message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 128,
  fallbacks: "default",
  messages: [{role: "user", content: "Name one benefit of static typing in one sentence."}]
)

puts "Model used: #{default_message.model}"
puts default_message.text
puts
puts "=" * 60
puts

# --- 3. Streaming with a fallback chain ---
puts "3. Streaming request with fallbacks configured"
puts "-" * 60
puts

client.beta.messages.stream(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 128,
  fallbacks: [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
  messages: [{role: "user", content: "Name one benefit of static typing."}]
) do |event|
  if event.is_a?(Anthropic::ContentBlockDeltaEvent) && (text = event.text)
    print text
  end
end
puts
puts
puts "=" * 60
puts

# --- 4. Object-form credit token (for a manual retry after a refusal) ---
# Demonstrates the request shape only. A real token comes from a prior
# refusal's stop_details.fallback_credit_token.
puts "4. Object-form fallback_credit_token request shape"
puts "-" * 60
puts
puts "  fallback_credit_token: FallbackCreditTokenParam.new("
puts "    token: \"fct_from_prior_refusal\","
puts "    mode: \"best_effort\","
puts "  )"
puts
puts "Requires anthropic-beta: #{Anthropic::FALLBACK_CREDIT_BETA_2026_07_01}"
puts "Bare string form still works and selects mode: strict."
puts
puts "=" * 60
puts "Done!"
