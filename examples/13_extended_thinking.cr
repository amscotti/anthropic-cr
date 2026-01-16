require "../src/anthropic-cr"
require "dotenv"

# Extended Thinking example: Enable Claude's reasoning process
#
# Extended thinking allows Claude to "think" through complex problems
# before providing a response. The thinking content shows Claude's
# reasoning process.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/13_extended_thinking.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Extended Thinking Example"
puts "=" * 60
puts

# Enable extended thinking with a budget of 2000 tokens
puts "Asking Claude to solve a problem with extended thinking..."
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 8192,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 4000),
  messages: [
    {role: "user", content: "Solve this logic puzzle: Three friends (Alice, Bob, and Carol) each have a different favorite color (red, blue, green) and a different pet (cat, dog, bird). Alice's favorite color is not red. The person who likes blue has a cat. Carol doesn't have a dog. Bob's favorite color is green. Who has which color and pet?"},
  ]
)

# Process the response content to show thinking and text separately
message.content.each do |block|
  case block
  when Anthropic::ThinkingContent
    puts "🧠 THINKING:"
    puts "-" * 40
    thinking_text = block.thinking
    # Show first 500 chars of thinking for brevity
    if thinking_text.size > 500
      puts thinking_text[0, 500]
      puts "... [truncated, #{thinking_text.size - 500} more characters]"
    else
      puts thinking_text
    end
    puts
  when Anthropic::TextContent
    puts "📝 RESPONSE:"
    puts "-" * 40
    puts block.text
  end
end

puts
puts "=" * 60

# Another example with streaming
puts
puts "Extended Thinking with Streaming"
puts "=" * 60
puts

print "🧠 Thinking: "
thinking_shown = false

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 2000),
  messages: [
    {role: "user", content: "Create a haiku about programming in Crystal."},
  ]
) do |event|
  case event
  when Anthropic::ContentBlockDeltaEvent
    # Check for thinking delta
    if event.thinking
      print "." # Show progress indicator for thinking
    end

    # Check for text delta
    if text = event.text
      unless thinking_shown
        puts " done!"
        puts
        print "📝 Response: "
        thinking_shown = true
      end
      print text
    end
  end
end

puts
puts
puts "=" * 60
puts "Extended thinking helps Claude reason through complex problems!"
