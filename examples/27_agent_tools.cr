require "../src/anthropic-cr"
require "dotenv"

# Agent Tools example: Using Claude's built-in agent tools
#
# Agent tools allow Claude to interact with a computer environment:
# - BashTool: Execute shell commands
# - TextEditorTool: View and edit files
# - ComputerUseTool: Control a computer desktop via screenshots, mouse, and keyboard
#
# These tools require an actual agent environment to run. This example
# demonstrates the setup and configuration patterns.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/27_agent_tools.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Agent Tools Example"
puts "=" * 60
puts

# Example 1: BashTool + TextEditorTool (coding agent setup)
puts "Example 1: Coding agent tools setup"
puts "-" * 60

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [
    Anthropic::BashTool.new,
    Anthropic::TextEditorTool.new,
  ] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "What tools do you have available? Describe them briefly."},
  ]
)

puts "Response:"
puts message.text
puts

# Example 2: ComputerUseTool (desktop automation setup)
puts "Example 2: Computer use tool setup"
puts "-" * 60

message2 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [
    Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080),
    Anthropic::BashTool.new,
    Anthropic::TextEditorTool.new,
  ] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "What tools do you have available? Describe them briefly."},
  ]
)

puts "Response:"
puts message2.text
puts

# Example 3: WebFetchTool
puts "Example 3: Web fetch tool"
puts "-" * 60

message3 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [Anthropic::WebFetchTool.new] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "Fetch the content from https://crystal-lang.org and summarize what Crystal is."},
  ]
)

puts "Response:"
puts message3.text
puts

# Example 4: WebFetchTool with domain restrictions
puts "Example 4: Web fetch with domain restrictions"
puts "-" * 60

restricted_fetch = Anthropic::WebFetchTool.new(
  allowed_domains: ["crystal-lang.org", "github.com"],
  max_uses: 3,
  max_content_tokens: 5000
)

message4 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [restricted_fetch] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "Look up the latest Crystal language version from crystal-lang.org."},
  ]
)

puts "Response:"
puts message4.text
puts

# Example 5: MemoryTool
puts "Example 5: Memory tool"
puts "-" * 60

message5 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [Anthropic::MemoryTool.new] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "Remember that my preferred programming language is Crystal and I work on API client libraries."},
  ]
)

puts "Response:"
puts message5.text
puts

# Example 6: WebFetchTool with citations enabled
puts "Example 6: Web fetch with citations"
puts "-" * 60

fetch_with_citations = Anthropic::WebFetchTool.new(
  citations: Anthropic::CitationConfig.enable,
  max_uses: 3
)

message6 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 4096,
  server_tools: [fetch_with_citations] of Anthropic::ServerTool,
  messages: [
    {role: "user", content: "Fetch https://crystal-lang.org and tell me about Crystal. Cite your sources."},
  ]
)

puts "Response:"
puts message6.text
puts

# Example 7: Tool Search Tools
puts "Example 7: Tool search tools (configuration demo)"
puts "-" * 60

puts "Tool search tools allow Claude to search through large tool sets:"
puts
puts "  BM25 Tool:"
bm25 = Anthropic::ToolSearchBM25Tool.new
puts "    type: #{bm25.type}"
puts "    name: #{bm25.name}"
puts
puts "  Regex Tool:"
regex = Anthropic::ToolSearchRegexTool.new
puts "    type: #{regex.type}"
puts "    name: #{regex.name}"
puts
puts "  Usage: Pass as server_tools alongside many user-defined tools"
puts "  to let Claude search for the right tool to use."
puts

# Example 8: Legacy Tool Versions (October 2024)
puts "Example 8: Legacy tool versions (configuration demo)"
puts "-" * 60

puts "Legacy tool versions from October 2024 (beta-only):"
puts
puts "  BashToolLegacy:"
bash_legacy = Anthropic::BashToolLegacy.new
puts "    type: #{bash_legacy.type}"
puts "    name: #{bash_legacy.name}"
puts
puts "  TextEditorToolLegacy:"
editor_legacy = Anthropic::TextEditorToolLegacy.new
puts "    type: #{editor_legacy.type}"
puts "    name: #{editor_legacy.name}"
puts
puts "  ComputerUseToolLegacy:"
computer_legacy = Anthropic::ComputerUseToolLegacy.new(display_width_px: 1024, display_height_px: 768)
puts "    type: #{computer_legacy.type}"
puts "    name: #{computer_legacy.name}"
puts "    display: #{computer_legacy.display_width_px}x#{computer_legacy.display_height_px}"
puts
puts "  Use these with beta API for backwards compatibility with October 2024 tools."
puts

puts "=" * 60
puts "Agent tools enable Claude to interact with computer environments!"
