require "../src/anthropic-cr"
require "dotenv"

# Streaming example: compare `stream` and `open_stream`
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/02_streaming.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Streaming response from Claude..."
puts "-" * 50

# Method 1: `stream` yields each parsed event
client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 1024,
  messages: [
    {role: "user", content: "Write a haiku about Crystal programming."},
  ]
) do |event|
  # Print text deltas as they arrive
  if event.is_a?(Anthropic::ContentBlockDeltaEvent)
    if text = event.text
      print text
      STDOUT.flush
    end
  end
end

puts
puts "-" * 50
puts

# Method 2: `open_stream` yields a MessageStream helper
puts "Using open_stream for helpers like collect_text and final_message:"
puts "-" * 50

client.messages.open_stream(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 100,
  messages: [
    {role: "user", content: "Count from 1 to 5 in words."},
  ]
) do |stream|
  text_buffer = stream.collect_text
  final_message = stream.final_message

  puts text_buffer
  puts
  puts "Final stop reason: #{final_message.try(&.stop_reason) || "unknown"}"
end
puts "-" * 50
