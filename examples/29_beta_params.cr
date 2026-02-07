require "../src/anthropic-cr"
require "dotenv"

# Beta Parameters Example (Live API Calls)
# Demonstrates: WebFetchTool, MCP Client with MCPToolset,
# and Tool Search (BM25) with many user tools.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/29_beta_params.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Beta Parameters Example"
puts "=" * 60
puts

# ── 1. WebFetchTool — Have Claude fetch and summarize a page ──
puts "=== WebFetchTool ==="
puts "Claude fetches a web page server-side and summarises it."
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 1024,
  server_tools: [Anthropic::WebFetchTool.new(max_uses: 1)] of Anthropic::ServerTool,
  messages: [{role: "user", content: "Fetch https://crystal-lang.org and give me a one-paragraph summary of the page."}]
)

message.content.each do |block|
  case block
  when Anthropic::ServerToolUseContent
    puts "  [Server Tool Use] #{block.name} — input: #{block.input}"
  when Anthropic::WebFetchToolResultContent
    puts "  [WebFetch Result] (#{block.tool_use_id})"
  when Anthropic::TextContent
    puts "  [Text] #{block.text}"
  end
end
puts
puts "  Stop reason: #{message.stop_reason}"
puts "  Usage: #{message.usage.input_tokens} in / #{message.usage.output_tokens} out"
puts

# ── 2. MCP Client — Connect to Context7 documentation search MCP ──
puts "=== MCP Client (Beta) ==="
puts "Connect to Context7 MCP server to search library documentation."
puts

# Define the MCP server (Context7 provides documentation search for libraries)
context7_server = Anthropic::MCPServerDefinition.new(
  url: "https://mcp.context7.com/mcp",
  name: "context7"
)

# MCPToolset declares which MCP server's tools to expose
toolset = Anthropic::MCPToolset.new(mcp_server_name: "context7")

begin
  mcp_message = client.beta.messages.create(
    betas: [Anthropic::MCP_CLIENT_BETA],
    model: Anthropic::Model::CLAUDE_SONNET_4_5,
    max_tokens: 2048,
    mcp_servers: [context7_server],
    server_tools: [toolset] of Anthropic::ServerTool,
    messages: [{role: "user", content: "Use the Context7 MCP tools to search for documentation about how to define a JSON serializable struct in Crystal. Give me a brief answer."}]
  )

  mcp_message.content.each do |block|
    case block
    when Anthropic::MCPToolUseContent
      puts "  [MCP Tool Use] #{block.name} on #{block.server_name}"
    when Anthropic::MCPToolResultContent
      status = block.is_error? ? "ERROR" : "OK"
      puts "  [MCP Result] (#{status})"
    when Anthropic::ServerToolUseContent
      puts "  [Server Tool Use] #{block.name}"
    when Anthropic::TextContent
      puts "  [Text] #{block.text}"
    end
  end
  puts
  puts "  Stop reason: #{mcp_message.stop_reason}"
  puts "  Usage: #{mcp_message.usage.input_tokens} in / #{mcp_message.usage.output_tokens} out"
rescue ex : Anthropic::APIError
  puts "  MCP call failed (#{ex.status}): #{ex.message}"
  puts "  (This is expected if the MCP server is unavailable)"
end
puts

# ── 3. Tool Search (BM25) — Search through many user tools ───
puts "=== Tool Search with BM25 ==="
puts "Define many tools, let Claude search through them with BM25."
puts

# Define a batch of user tools
tools = [
  Anthropic::InlineTool.new(
    name: "get_weather",
    description: "Get current weather for a city",
    schema: {"city" => Anthropic::Schema.string("City name")},
    required: ["city"]
  ) { |input| "Sunny, 22°C in #{input["city"].as_s}" },

  Anthropic::InlineTool.new(
    name: "convert_currency",
    description: "Convert an amount between currencies",
    schema: {
      "amount" => Anthropic::Schema.number("Amount to convert"),
      "from"   => Anthropic::Schema.string("Source currency code"),
      "to"     => Anthropic::Schema.string("Target currency code"),
    },
    required: ["amount", "from", "to"]
  ) { |input| "#{input["amount"]} #{input["from"].as_s} = #{(input["amount"].as_f * 0.85).round(2)} #{input["to"].as_s}" },

  Anthropic::InlineTool.new(
    name: "translate_text",
    description: "Translate text to another language",
    schema: {
      "text"     => Anthropic::Schema.string("Text to translate"),
      "language" => Anthropic::Schema.string("Target language"),
    },
    required: ["text", "language"]
  ) { |input| "Translated '#{input["text"].as_s}' to #{input["language"].as_s}" },

  Anthropic::InlineTool.new(
    name: "calculate_tip",
    description: "Calculate tip amount for a restaurant bill",
    schema: {
      "bill_amount"    => Anthropic::Schema.number("Total bill"),
      "tip_percentage" => Anthropic::Schema.number("Tip percentage"),
    },
    required: ["bill_amount"]
  ) { |input|
    bill = input["bill_amount"].as_f
    pct = input["tip_percentage"]?.try(&.as_f) || 18.0
    "Tip: $#{(bill * pct / 100).round(2)}"
  },

  Anthropic::InlineTool.new(
    name: "lookup_word",
    description: "Look up the definition of an English word",
    schema: {"word" => Anthropic::Schema.string("Word to define")},
    required: ["word"]
  ) { |input| "#{input["word"].as_s}: a common English word" },

  Anthropic::InlineTool.new(
    name: "generate_password",
    description: "Generate a random secure password",
    schema: {"length" => Anthropic::Schema.integer("Password length")},
    required: ["length"]
  ) { |input| "p@ssW0rd##{input["length"]}" },
] of Anthropic::Tool

search_message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 1024,
  tools: tools,
  server_tools: [Anthropic::ToolSearchBM25Tool.new] of Anthropic::ServerTool,
  messages: [{role: "user", content: "What's the weather in Tokyo?"}]
)

search_message.content.each do |block|
  case block
  when Anthropic::ServerToolUseContent
    puts "  [Server Tool Use] #{block.name} — input: #{block.input}"
  when Anthropic::ToolUseContent
    puts "  [Tool Use] #{block.name} — input: #{block.input}"
  when Anthropic::TextContent
    puts "  [Text] #{block.text}"
  end
end
puts
puts "  Stop reason: #{search_message.stop_reason}"
puts "  Usage: #{search_message.usage.input_tokens} in / #{search_message.usage.output_tokens} out"
puts

puts "=" * 60
puts "Done! All beta features demonstrated with live API calls."
