require "../src/anthropic-cr"
require "dotenv"

# Legacy Text Completions example
#
# The Text Completions API is a legacy API; prefer `client.messages` for
# new code (see examples/01_basic_message.cr). Future models and features
# are not compatible with Text Completions.
#
# NOTE: the API server has deprecated `/v1/complete` and may answer with a
# `BadRequestError` ("endpoint has been deprecated") depending on the key.
# The resource is kept for parity with the official SDKs, which still ship
# it, and the typed error below shows how that surfaces.
#
# Run with:
#   crystal run examples/47_completions.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

begin
  completion = client.completions.create(
    model: "claude-haiku-4-5-20251001",
    prompt: "\n\nHuman: Name three Crystal language features.\n\nAssistant:",
    max_tokens_to_sample: 128
  )

  puts "Completion: #{completion.completion}"
  puts "Stop reason: #{completion.stop_reason}"

  print "\nStreaming: "
  client.completions.stream(
    model: "claude-haiku-4-5-20251001",
    prompt: "\n\nHuman: Count to five.\n\nAssistant:",
    max_tokens_to_sample: 64
  ) do |chunk|
    print chunk.completion
  end
  puts
rescue ex : Anthropic::BadRequestError
  puts "Server rejected the legacy endpoint: #{ex.message}"
end
