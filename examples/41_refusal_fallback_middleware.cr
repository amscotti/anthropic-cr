require "../src/anthropic-cr"
require "dotenv"

# Client-side refusal fallbacks middleware example.
#
# `BetaRefusalFallbackMiddleware` retries a refused request down a client-side
# fallback chain. Use it with providers that don't support server-side
# fallbacks (see example 39 for the server-side variant). It is mutually
# exclusive with the request-body `fallbacks:` param.
#
# This example wires up the middleware and runs a benign request to confirm the
# chain executes correctly. A real refusal (which would trigger the fallback
# hop) requires content the primary model declines; see example 39 for that
# flow using server-side fallbacks.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/41_refusal_fallback_middleware.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new(
  middleware: [
    Anthropic::BetaRefusalFallbackMiddleware.new(
      [
        Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8),
      ],
      # The credit beta is attached automatically; you can override it here.
    ),
  ],
)

puts "Client-Side Refusal Fallback Middleware"
puts "=" * 60
puts

puts "1. Benign request through the fallback-aware client (live)"
puts "-" * 60
puts

message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 64,
  messages: [{role: "user", content: "Reply with the single word: ok"}],
)

puts "Model used: #{message.model}"
puts "Response: #{message.text}"
puts
puts "(No refusal occurred, so the fallback chain was not exercised. If the"
puts " primary model had refused with stop_reason 'refusal', the middleware"
puts " would have retried against claude-opus-4-8 carrying the credit token.)"
puts
puts "=" * 60
puts "Done!"
