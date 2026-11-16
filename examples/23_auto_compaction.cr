require "../src/anthropic-cr"
require "dotenv"

# Server-Side Compaction Example
#
# Demonstrates server-side message compaction inside a beta tool loop using
# `compact_before_next_turn` and `SummarizeCompaction`. When invoked after a
# tool turn completes, the server summarizes the history into a `CompactionContent`
# block and continues smoothly from the compressed summary.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/23_auto_compaction.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Server-Side Compaction Example"
puts "=" * 60
puts

search_tool = Anthropic.tool(
  name: "search",
  description: "Search for information about a topic. Returns detailed results.",
  schema: {
    "query" => Anthropic::Schema.string("Search query"),
  },
  required: ["query"]
) do |input|
  query = input["query"].as_s

  <<-RESULTS
  Search Results for "#{query}":
  1. Overview of #{query}: foundational principles and core abstractions.
  2. Production usage: practical applications and performance trade-offs.
  RESULTS
end

runner = client.beta.messages.tool_runner(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.user(
      "Search for Crystal programming language and then summarize what you found."
    ),
  ],
  tools: [search_tool] of Anthropic::Tool,
  max_iterations: 6
)

message_count = 0
compacted_once = false

while message = runner.next_message
  message_count += 1
  puts "Message ##{message_count} (stop_reason=#{message.stop_reason}):"

  message.content.each do |block|
    case block
    when Anthropic::CompactionContent
      puts "  [Compaction summary received: #{(block.content || "").size} chars]"
    when Anthropic::ToolUseContent
      puts "  Tool call: #{block.name}"
    when Anthropic::TextContent
      preview = block.text.size > 120 ? "#{block.text[0, 120]}..." : block.text
      puts "  Response: #{preview}"
    end
  end

  if message.tool_use? && !compacted_once
    compacted_once = true
    runner.compact_before_next_turn(
      Anthropic::SummarizeCompaction.new(instructions: "Preserve key facts from tool outputs.")
    )
  end
  puts
end

puts "=" * 60
puts "Completed in #{message_count} turns."
