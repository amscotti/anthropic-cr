require "../src/anthropic-cr"
require "dotenv"

# Streaming example: Stream Claude's response in real-time
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

# Method 1: Stream with block (yields each event)
client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
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

# Method 2: Using text iterator within the stream
puts "Using text iterator for just text:"
puts "-" * 50

text_buffer = ""
client.messages.stream(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 100,
  messages: [
    {role: "user", content: "Count from 1 to 5 in words."},
  ]
) do |event|
  if event.is_a?(Anthropic::ContentBlockDeltaEvent)
    if text = event.text
      text_buffer += text
    end
  end
end

puts text_buffer
puts "-" * 50
