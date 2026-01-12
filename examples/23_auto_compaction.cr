require "../src/anthropic"
require "dotenv"

# Auto-Compaction Example
#
# Demonstrates automatic message compaction for long-running tool loops.
# When the conversation exceeds a token threshold, the tool runner
# automatically compresses the history while preserving context.
#
# This is useful for:
# - Long-running agents that accumulate context
# - Tool loops that generate verbose outputs
# - Maintaining conversations within context limits
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/23_auto_compaction.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Auto-Compaction Example"
puts "=" * 60
puts

# Create a tool that returns verbose output to simulate growing context
search_tool = Anthropic.tool(
  name: "search",
  description: "Search for information about a topic. Returns detailed results.",
  schema: {
    "query" => Anthropic::Schema.string("Search query"),
  },
  required: ["query"]
) do |input|
  query = input["query"].as_s

  # Simulate verbose search results
  <<-RESULTS
  Search Results for "#{query}":

  1. Introduction to #{query}
     #{query} is a fascinating topic that has been studied extensively.
     Key concepts include fundamental principles, advanced techniques,
     and practical applications in various fields.

  2. History of #{query}
     The study of #{query} dates back centuries. Early pioneers made
     significant contributions that laid the foundation for modern
     understanding. Major milestones include theoretical breakthroughs
     and technological advances.

  3. Modern Applications
     Today, #{query} is applied in numerous domains including science,
     technology, medicine, and everyday life. Recent developments have
     expanded its reach even further.

  4. Future Directions
     Researchers continue to explore new frontiers in #{query}.
     Emerging trends suggest exciting possibilities for the future.
  RESULTS
end

done_tool = Anthropic.tool(
  name: "done",
  description: "Call this when you have completed all searches and are ready to summarize.",
  schema: {} of String => Anthropic::Schema::Property,
  required: [] of String
) do |_|
  "Task completed."
end

# Track compaction events
compaction_count = 0
total_tokens_saved = 0

# Create compaction config with low threshold for demonstration
compaction = Anthropic::CompactionConfig.enabled(threshold: 3000) do |before, after|
  compaction_count += 1
  saved = before - after
  total_tokens_saved += saved
  puts
  puts "=" * 40
  puts "COMPACTION ##{compaction_count}"
  puts "  Tokens before: #{before}"
  puts "  Tokens after:  #{after}"
  puts "  Tokens saved:  #{saved}"
  puts "=" * 40
  puts
end

puts "Configuration:"
puts "  Token threshold: 3000"
puts "  Tools: search, done"
puts
puts "Starting tool loop..."
puts "-" * 60
puts

# Create tool runner with compaction
runner = Anthropic::ToolRunner.new(
  client: client,
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.user(
      "Please search for the following topics one at a time, then call done: " \
      "1) Crystal programming language, " \
      "2) Type safety, " \
      "3) Concurrency patterns. " \
      "After searching all topics, summarize what you learned."
    ),
  ],
  tools: [search_tool, done_tool] of Anthropic::Tool,
  max_iterations: 10,
  compaction: compaction
)

message_count = 0
runner.each_message do |message|
  message_count += 1
  puts "Message ##{message_count}:"

  if message.tool_use?
    tool_uses = message.tool_use_blocks
    tool_uses.each do |tool|
      puts "  Tool: #{tool.name}"
      if tool.name == "search"
        query = tool.input["query"]?.try(&.as_s) || "unknown"
        puts "  Query: #{query}"
      end
    end
  else
    text = message.text_blocks.first?.try(&.text) || ""
    preview = text.size > 100 ? "#{text[0, 100]}..." : text
    puts "  Response: #{preview}"
  end

  puts "  Stop reason: #{message.stop_reason}"
  puts
end

puts "-" * 60
puts
puts "Summary:"
puts "  Total messages: #{message_count}"
puts "  Compaction events: #{compaction_count}"
puts "  Total tokens saved: #{total_tokens_saved}"
puts
puts "=" * 60
puts "Auto-compaction keeps long conversations within context limits!"
