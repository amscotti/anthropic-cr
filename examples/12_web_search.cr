require "../src/anthropic"
require "dotenv"

# Web Search example: Using Claude's built-in web search capability
#
# Web search is a server-side tool that allows Claude to search the internet
# for current information without requiring you to implement the search yourself.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/12_web_search.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Web Search Example"
puts "=" * 60
puts

# Basic web search
puts "Example 1: Basic web search"
puts "-" * 60

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 2048,
  server_tools: [Anthropic::WebSearchTool.new],
  messages: [
    {role: "user", content: "What are the latest developments in the Crystal programming language? Search for recent news."},
  ]
)

puts "Response:"
message.text_blocks.each { |block| puts block.text }
puts

# Web search limited to specific domains
puts "Example 2: Domain-limited search"
puts "-" * 60

search_tool = Anthropic::WebSearchTool.new(
  allowed_domains: ["github.com", "crystal-lang.org"],
  max_uses: 3
)

message2 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 2048,
  server_tools: [search_tool],
  messages: [
    {role: "user", content: "Find the latest Crystal language releases and notable new shards."},
  ]
)

puts "Response (limited to github.com and crystal-lang.org):"
puts message2.text
puts

# Web search with location context
# Note: user_location affects search RANKING (results are localized),
# but Claude needs a system prompt to know where the user actually is.
puts "Example 3: Location-aware search"
puts "-" * 60

location_search = Anthropic::WebSearchTool.new(
  user_location: Anthropic::UserLocation.new(
    city: "San Francisco",
    region: "California",
    country: "US",
    timezone: "America/Los_Angeles"
  )
)

message3 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 2048,
  # System prompt tells Claude the user's location
  system: "The user is located in San Francisco, California. Use this context for location-based questions.",
  server_tools: [location_search],
  messages: [
    {role: "user", content: "What's the current weather right now?"},
  ]
)

puts "Response (location-aware):"
puts message3.text
puts

puts "=" * 60
puts "Web search provides Claude with access to current information!"
