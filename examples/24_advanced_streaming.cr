require "../src/anthropic-cr"
require "dotenv"

# Advanced Streaming Example
#
# Demonstrates advanced streaming patterns including:
# - Thinking stream with extended thinking
# - Event type filtering
# - Collecting specific content types
# - Progress tracking
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/24_advanced_streaming.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Advanced Streaming Example"
puts "=" * 60
puts

# Example 1: Thinking Stream with Progress
puts "Example 1: Extended Thinking with Progress Tracking"
puts "-" * 60
puts

thinking_chunks = 0
text_chunks = 0
thinking_text = ""
response_text = ""

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 2000),
  messages: [{role: "user", content: "What are the prime factors of 2310?"}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    case event.content_block
    when Anthropic::ThinkingContent
      print "Thinking: "
    when Anthropic::TextContent
      puts " done! (#{thinking_chunks} chunks)"
      puts
      print "Response: "
    end
  when Anthropic::ContentBlockDeltaEvent
    case event.delta
    when Anthropic::ThinkingDelta
      thinking_chunks += 1
      thinking_text += event.delta.as(Anthropic::ThinkingDelta).thinking
      print "." # Progress indicator
    when Anthropic::TextDelta
      text_chunks += 1
      text = event.delta.as(Anthropic::TextDelta).text
      response_text += text
      print text
    end
    STDOUT.flush
  end
end

puts
puts
puts "Statistics:"
puts "  Thinking chunks: #{thinking_chunks}"
puts "  Thinking chars: #{thinking_text.size}"
puts "  Text chunks: #{text_chunks}"
puts "  Response chars: #{response_text.size}"
puts

# Example 2: Event Type Statistics
puts "Example 2: Event Statistics"
puts "-" * 60
puts

event_counts = Hash(String, Int32).new(0)

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 256,
  messages: [{role: "user", content: "Write a haiku about programming."}]
) do |event|
  event_type = case event
               when Anthropic::MessageStartEvent      then "message_start"
               when Anthropic::MessageDeltaEvent      then "message_delta"
               when Anthropic::MessageStopEvent       then "message_stop"
               when Anthropic::ContentBlockStartEvent then "content_block_start"
               when Anthropic::ContentBlockDeltaEvent then "content_block_delta"
               when Anthropic::ContentBlockStopEvent  then "content_block_stop"
               when Anthropic::PingEvent              then "ping"
               else                                        "unknown"
               end
  event_counts[event_type] += 1

  # Also print text
  if event.is_a?(Anthropic::ContentBlockDeltaEvent)
    if text = event.text
      print text
    end
  end
end

puts
puts
puts "Event counts:"
event_counts.each do |type, count|
  puts "  #{type}: #{count}"
end
puts

# Example 3: Multi-content Block Tracking
puts "Example 3: Multi-Content Block Handling"
puts "-" * 60
puts

content_blocks = [] of {Int32, String, String}
current_block_type = ""
current_block_content = ""

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 512,
  messages: [{role: "user", content: "Give me 3 fun facts about Crystal, numbered 1-3."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    current_block_type = case event.content_block
                         when Anthropic::TextContent     then "text"
                         when Anthropic::ToolUseContent  then "tool_use"
                         when Anthropic::ThinkingContent then "thinking"
                         else                                 "unknown"
                         end
    current_block_content = ""
    print "[Block #{event.index} start: #{current_block_type}] "
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      current_block_content += text
      print text
    end
  when Anthropic::ContentBlockStopEvent
    content_blocks << {event.index, current_block_type, current_block_content}
    puts " [Block #{event.index} end]"
  end
end

puts
puts "Collected #{content_blocks.size} content block(s)"
puts

# Example 4: Token-Efficient Tools Beta
puts "Example 4: Beta Headers for Optimization"
puts "-" * 60
puts

calculator = Anthropic.tool(
  name: "calculate",
  description: "Calculate a math expression",
  schema: {
    "expression" => Anthropic::Schema.string("Math expression like '2 + 2'"),
  },
  required: ["expression"]
) do |input|
  expr = input["expression"].as_s
  # Simple evaluation for demo
  case expr
  when /^(\d+)\s*\+\s*(\d+)$/ then ($1.to_i + $2.to_i).to_s
  when /^(\d+)\s*\*\s*(\d+)$/ then ($1.to_i * $2.to_i).to_s
  else                             "Error: Cannot parse"
  end
end

puts "Available optimization beta headers:"
puts "  Token-efficient tools: #{Anthropic::TOKEN_EFFICIENT_TOOLS_BETA}"
puts "  Fine-grained streaming: #{Anthropic::FINE_GRAINED_STREAMING_BETA}"
puts
puts "Usage: client.beta.messages.create(betas: [BETA_HEADER], ...)"
puts

# Example usage (commented to avoid extra API calls):
# client.beta.messages.stream(
#   betas: [Anthropic::TOKEN_EFFICIENT_TOOLS_BETA],
#   model: Anthropic::Model::CLAUDE_SONNET_4_5,
#   max_tokens: 256,
#   tools: [calculator],
#   messages: [{role: "user", content: "What is 15 * 7?"}]
# ) do |event|
#   # Handle events...
# end

puts "=" * 60
puts "Advanced streaming enables fine-grained control over responses!"
