require "../src/anthropic-cr"
require "dotenv"

# Web Search Streaming example: Stream responses that include web searches
#
# When Claude performs web searches, you can stream both the search process
# and the final response as it's generated.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/17_web_search_streaming.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Web Search Streaming Example"
puts "=" * 60
puts

# Example 1: Basic streaming with web search
puts "Example 1: Stream web search response"
puts "-" * 60

print "Searching and streaming: "
search_started = false
text_started = false

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 2048,
  server_tools: [Anthropic::WebSearchTool.new],
  messages: [{role: "user", content: "What are the latest news about the Crystal programming language? Be brief."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    case event.content_block
    when Anthropic::ServerToolUseContent
      if event.content_block.as(Anthropic::ServerToolUseContent).name == "web_search"
        print "\n[Web search started...]\n"
        search_started = true
      end
    when Anthropic::TextContent
      if search_started && !text_started
        print "\n[Search complete, generating response:]\n"
        text_started = true
      end
    end
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      print text
      STDOUT.flush
    end
  end
end

puts
puts

# Example 2: Domain-limited search with streaming
puts "Example 2: Domain-limited streaming search"
puts "-" * 60

limited_search = Anthropic::WebSearchTool.new(
  allowed_domains: ["crystal-lang.org", "github.com"],
  max_uses: 2
)

print "Searching crystal-lang.org and github.com: "

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  server_tools: [limited_search],
  messages: [{role: "user", content: "Find the latest Crystal version and any recent updates. Keep it short."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    if event.content_block.is_a?(Anthropic::ServerToolUseContent)
      print "\n[Searching...] "
    end
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      print text
      STDOUT.flush
    end
  end
end

puts
puts

# Example 3: Collect full response while streaming
puts "Example 3: Collect response while streaming"
puts "-" * 60

collected_text = String::Builder.new
search_count = 0

print "Response: "
client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  server_tools: [Anthropic::WebSearchTool.new(max_uses: 1)],
  messages: [{role: "user", content: "What's the current population of Tokyo? Just give me the number and source."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    if event.content_block.is_a?(Anthropic::ServerToolUseContent)
      search_count += 1
    end
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      print text
      collected_text << text
      STDOUT.flush
    end
  end
end

puts
puts
puts "Summary:"
puts "  Searches performed: #{search_count}"
puts "  Response length: #{collected_text.to_s.size} characters"
puts

# Example 4: Track all content blocks
puts "Example 4: Track all content blocks"
puts "-" * 60

content_blocks = [] of String

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  server_tools: [Anthropic::WebSearchTool.new],
  messages: [{role: "user", content: "What programming language has the fastest compile times? Brief answer."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    block = event.content_block
    case block
    when Anthropic::ServerToolUseContent
      content_blocks << "server_tool_use"
      puts "[Block #{content_blocks.size}] Server tool: #{block.name}"
    when Anthropic::TextContent
      content_blocks << "text"
      print "[Block #{content_blocks.size}] Text: "
    when Anthropic::WebSearchToolResultContent
      content_blocks << "web_search_tool_result"
      puts "[Block #{content_blocks.size}] Search results received"
    else
      content_blocks << "unknown"
    end
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      print text
      STDOUT.flush
    end
  when Anthropic::ContentBlockStopEvent
    # Add newline after text blocks
    if content_blocks[event.index]? == "text"
      puts
    end
  end
end

puts
puts "Content blocks received: #{content_blocks.join(" -> ")}"
puts

puts "=" * 60
puts "Web search streaming shows real-time search and response generation!"
