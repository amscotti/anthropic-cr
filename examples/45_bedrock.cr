require "../src/anthropic-cr"
require "dotenv"

# Amazon Bedrock Runtime example
#
# Uses Anthropic::Bedrock::Client with AWS SigV4. Prefer the
# anthropic-cr-bedrock profile created for SDK development:
#
#   export AWS_PROFILE=anthropic-cr-bedrock
#   export AWS_REGION=us-east-1
#
# Or pass aws_profile: / aws_region: explicitly.
#
# Prefer inference profile model IDs (us.anthropic.* / global.anthropic.*).
# Bare anthropic.* on-demand IDs often fail with "use an inference profile".
#
# Run with:
#   crystal run examples/45_bedrock.cr

Dotenv.load if File.exists?(".env")

profile = ENV["AWS_PROFILE"]? || "anthropic-cr-bedrock"
region = ENV["AWS_REGION"]? || ENV["AWS_DEFAULT_REGION"]? || "us-east-1"
model = ENV["BEDROCK_MODEL"]? || "us.anthropic.claude-haiku-4-5-20251001-v1:0"

puts "Anthropic on Amazon Bedrock"
puts "=" * 60
puts "profile=#{profile} region=#{region}"
puts "model=#{model}"
puts

client = Anthropic::Bedrock::Client.new(
  aws_profile: profile,
  aws_region: region,
)

puts "1. Non-streaming messages.create"
puts "-" * 60

begin
  message = client.messages.create(
    model: model,
    max_tokens: 128,
    messages: [{role: "user", content: "In one short sentence, say hello from Amazon Bedrock."}],
  )
  puts "model: #{message.model}"
  puts "stop:  #{message.stop_reason}"
  puts "text:  #{message.text}"
  puts "usage: in=#{message.usage.input_tokens} out=#{message.usage.output_tokens}"
rescue ex : Anthropic::APIError
  puts "API error: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  puts "  Ensure the AWS profile can invoke this model and that model access is enabled."
rescue ex : ArgumentError
  puts "Config error: #{ex.message}"
end

puts
puts "2. Streaming messages.stream (optional)"
puts "-" * 60
puts "Skip with SKIP_BEDROCK_STREAM=1 if needed."

unless ENV["SKIP_BEDROCK_STREAM"]?
  begin
    print "stream: "
    client.messages.stream(
      model: model,
      max_tokens: 128,
      messages: [{role: "user", content: "In one short sentence, say hello from Bedrock streaming."}],
    ) do |event|
      if event.is_a?(Anthropic::ContentBlockDeltaEvent) && (text = event.text)
        print text
      end
    end
    puts
  rescue ex : Anthropic::APIError
    puts "API error: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
    puts "  (FTU / model-access blocks apply to streaming the same as non-streaming.)"
  rescue ex : ArgumentError
    puts "Config error: #{ex.message}"
  end
else
  puts "Skipped (SKIP_BEDROCK_STREAM set)."
end

puts
puts "Done."
