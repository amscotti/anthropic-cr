require "../src/anthropic-cr"
require "dotenv"

# Amazon Bedrock Mantle example
#
# Mantle exposes native Anthropic paths (/v1/messages) behind AWS auth.
# SigV4 uses service name `bedrock-mantle` (not `bedrock`).
#
# Prefer the anthropic-cr-bedrock profile created for SDK development:
#
#   export AWS_PROFILE=anthropic-cr-bedrock
#   export AWS_REGION=us-east-1
#
# Or pass aws_profile: / aws_region: explicitly.
#
# Base URL defaults to:
#   https://bedrock-mantle.{region}.api.aws/anthropic
# Override with ANTHROPIC_BEDROCK_MANTLE_BASE_URL if needed.
#
# Note: Mantle may not be enabled on every account. Access / entitlement
# errors from AWS are expected when the feature is not available.
#
# Run with:
#   crystal run examples/46_bedrock_mantle.cr

Dotenv.load if File.exists?(".env")

profile = ENV["AWS_PROFILE"]? || "anthropic-cr-bedrock"
region = ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]? || "us-east-1"
model = ENV["MANTLE_MODEL"]? || ENV["BEDROCK_MODEL"]? || "claude-haiku-4-5-20251001"

puts "Anthropic on Amazon Bedrock Mantle"
puts "=" * 60
puts "profile=#{profile} region=#{region}"
puts "model=#{model}"
puts "base=https://bedrock-mantle.#{region}.api.aws/anthropic"
puts

client = Anthropic::Bedrock::MantleClient.new(
  aws_profile: profile,
  aws_region: region,
)

puts "1. Non-streaming messages.create (native /v1/messages)"
puts "-" * 60

begin
  message = client.messages.create(
    model: model,
    max_tokens: 128,
    messages: [{role: "user", content: "In one short sentence, say hello from Bedrock Mantle."}],
  )
  puts "model: #{message.model}"
  puts "stop:  #{message.stop_reason}"
  puts "text:  #{message.text}"
  puts "usage: in=#{message.usage.input_tokens} out=#{message.usage.output_tokens}"
rescue ex : Anthropic::APIError
  puts "API error: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  puts "  Mantle may not be enabled for this account/region."
  puts "  Ensure the AWS profile can call bedrock-mantle and model access is granted."
rescue ex : ArgumentError
  puts "Config error: #{ex.message}"
end

puts
puts "2. Streaming messages.stream (native SSE, if Mantle supports it)"
puts "-" * 60

begin
  print "stream: "
  client.messages.stream(
    model: model,
    max_tokens: 64,
    messages: [{role: "user", content: "Say hi in three words."}],
  ) do |event|
    if event.is_a?(Anthropic::ContentBlockDeltaEvent)
      if text = event.text
        print text
        STDOUT.flush
      end
    end
  end
  puts
rescue ex : Anthropic::APIError
  puts "API error: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  puts "  Streaming may fail if Mantle is not enabled; non-streaming is the primary path."
rescue ex : ArgumentError
  puts "Config error: #{ex.message}"
end

puts
puts "Done."
