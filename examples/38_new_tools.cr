require "../src/anthropic-cr"
require "dotenv"

# New server tools example (June/July 2026 release).
#
# Demonstrates the tools added since the last sync:
# - `CodeExecutionTool20260521` (code_execution_20260521)
# - `WebFetchTool20260318`      (web_fetch_20260318, adds response_inclusion)
# - `WebSearchTool20260318`     (web_search_20260318, adds response_inclusion)
#
# These are server-side tools; the required beta headers are attached
# automatically by the SDK.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/38_new_tools.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "New Server Tools (20260521 / 20260318)"
puts "=" * 60
puts

# --- 1. Code execution tool (May 2026 variant) ---
puts "1. CodeExecutionTool20260521 — run code in a sandbox"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5,
  max_tokens: 2048,
  server_tools: [Anthropic::CodeExecutionTool20260521.new],
  messages: [{role: "user", content: "Use code execution to compute the 12th Fibonacci number and tell me the result."}]
)

puts "Model used: #{message.model}"
puts message.text
puts
puts "=" * 60
puts

# --- 2. Web search tool (March 2026 variant with response_inclusion) ---
puts "2. WebSearchTool20260318 — search the web (response_inclusion: \"full\")"
puts "-" * 60
puts

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_5,
  max_tokens: 2048,
  server_tools: [Anthropic::WebSearchTool20260318.new(response_inclusion: "full", max_uses: 3)],
  messages: [{role: "user", content: "What is the latest stable version of the Crystal programming language? Search the web."}]
) do |event|
  if event.is_a?(Anthropic::ContentBlockDeltaEvent) && (text = event.text)
    print text
  end
end
puts
puts
puts "=" * 60
puts

# --- 3. Web fetch tool (March 2026 variant) ---
puts "3. WebFetchTool20260318 — fetch a web page"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5,
  max_tokens: 1024,
  server_tools: [Anthropic::WebFetchTool20260318.new(use_cache: true)],
  messages: [{role: "user", content: "Fetch https://crystal-lang.org/ and tell me the headline in one sentence."}]
)

puts "Model used: #{message.model}"
puts message.text
puts
puts "=" * 60
puts "Done!"
