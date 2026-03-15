require "../src/anthropic-cr"
require "dotenv"

# Open Stream example: use a richer MessageStream helper within a block
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/31_open_stream.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Open Stream Example"
puts "=" * 60
puts

client.messages.open_stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 256,
  messages: [
    {role: "user", content: "Write a short two-line poem about Crystal language design."},
  ]
) do |stream|
  puts "Text chunks:"
  puts "-" * 60
  stream.text.each do |chunk|
    print chunk
    STDOUT.flush
  end
  puts
  puts "-" * 60
  puts

  final_message = stream.final_message
  if final_message
    puts "Final text: #{final_message.text}"
    puts "Stop reason: #{final_message.stop_reason}"
    puts "Output tokens: #{final_message.usage.output_tokens}"
  end
end

puts
puts "You can use `stream` for simple event-by-event handling, or `open_stream`"
puts "when you want helpers like `text`, `collect_text`, and `final_message`."
