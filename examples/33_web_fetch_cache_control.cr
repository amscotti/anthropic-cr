require "../src/anthropic-cr"
require "dotenv"

# Web Fetch 20260309 example: request fresh content with use_cache: false
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/33_web_fetch_cache_control.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Web Fetch 20260309 Example"
puts "=" * 60
puts

tool = Anthropic::WebFetchTool20260309.new(
  allowed_callers: ["direct"],
  max_uses: 1,
  use_cache: false,
  allowed_domains: ["crystal-lang.org"]
)

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU,
  max_tokens: 768,
  server_tools: [tool] of Anthropic::ServerTool,
  messages: [
    {
      role:    "user",
      content: "Fetch https://crystal-lang.org and give me a short fresh summary of the homepage. Mention that you bypassed the cache if the tool reports that detail.",
    },
  ]
)

message.content.each do |block|
  case block
  when Anthropic::ServerToolUseContent
    puts "[Server Tool Use] #{block.name}"
    puts "  Input: #{block.input}"
  when Anthropic::WebFetchToolResultContent
    puts "[Web Fetch Result] tool_use_id=#{block.tool_use_id}"
  when Anthropic::TextContent
    puts "[Text] #{block.text}"
  end
end

puts
puts "Stop reason: #{message.stop_reason}"
puts "Usage: #{message.usage.input_tokens} in / #{message.usage.output_tokens} out"
