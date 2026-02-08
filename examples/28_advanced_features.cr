require "../src/anthropic-cr"
require "dotenv"

# Advanced Features Example
# Demonstrates: redacted thinking, search result input, cache_control on tools,
# metadata, and context_management setup.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/28_advanced_features.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# ── 1. Redacted Thinking Handling ──────────────────────────────────
puts "=== Redacted Thinking ==="
puts "When using extended thinking, some blocks may be redacted."
puts "You must preserve redacted_thinking blocks in multi-turn conversations."
puts ""

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 4000),
  messages: [{role: "user", content: "What are the security implications of quantum computing?"}]
)

# Iterate content blocks and handle all thinking types
message.content.each do |block|
  case block
  when Anthropic::ThinkingContent
    puts "  [Thinking] #{block.thinking[0..80]}..."
  when Anthropic::RedactedThinkingContent
    puts "  [Redacted Thinking] data=#{block.data[0..20]}..."
  when Anthropic::TextContent
    puts "  [Text] #{block.text[0..100]}..."
  end
end

# For multi-turn, preserve all content blocks including redacted thinking
puts "\n  Redacted blocks: #{message.redacted_thinking_blocks.size}"
puts ""

# ── 2. Cache Control on Tools ─────────────────────────────────────
puts "=== Cache Control on Tools ==="
puts "Large tool schemas can be cached to reduce latency and cost."
puts ""

cached_tool = Anthropic::InlineTool.new(
  name: "knowledge_base_search",
  description: "Search a large knowledge base with many fields",
  schema: {
    "query"    => Anthropic::Schema.string("Search query"),
    "category" => Anthropic::Schema.enum("docs", "faq", "tutorials", description: "Category to search"),
    "limit"    => Anthropic::Schema.integer("Max results to return"),
  },
  required: ["query"],
  cache_control: Anthropic::CacheControl.ephemeral
) do |input|
  "Results for: #{input["query"].as_s}"
end

definition = cached_tool.to_definition
puts "  Tool: #{definition.name}"
puts "  Cache control: #{definition.cache_control.try(&.type) || "none"}"
puts ""

# ── 3. Metadata ───────────────────────────────────────────────────
puts "=== Metadata ==="
puts "Attach user_id to requests for tracking and abuse detection."
puts ""

metadata = Anthropic::Metadata.new(user_id: "user-12345")
puts "  Metadata JSON: #{metadata.to_json}"

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 100,
  metadata: metadata,
  messages: [{role: "user", content: "Hello!"}]
)
puts "  Response: #{message.text[0..60]}..."
puts ""

# ── 4. Context Management (Beta) ──────────────────────────────────
puts "=== Context Management ==="
puts "Beta feature for automatic conversation management."
puts ""

# Auto-compact configuration
compact_config = Anthropic::ContextManagementConfig.auto_compact(
  instructions: "Preserve key facts and decisions",
  trigger: "auto"
)
puts "  Auto-compact config: #{compact_config.to_json}"

# Full config with multiple edits
full_config = Anthropic::ContextManagementConfig.new(edits: [
  Anthropic::CompactEdit.new(instructions: "Keep important context"),
  Anthropic::ClearToolUsesEdit.new(exclude_tools: ["important_tool"]),
  Anthropic::ClearThinkingEdit.new,
] of Anthropic::ContextManagementEdit)
puts "  Full config edits: #{full_config.edits.size}"
puts ""

# ── 5. Search Result Input ────────────────────────────────────────
puts "=== Search Result Content Block ==="
puts "Provide search results as structured input to messages."
puts ""

search_result = Anthropic::SearchResultContent.new(
  source: "https://crystal-lang.org/docs",
  title: "Crystal Programming Language",
  content: [
    Anthropic::TextContent.new(text: "Crystal is a programming language with Ruby-like syntax and C-like performance."),
  ],
  citations: Anthropic::CitationConfig.enable
)
puts "  Search result type: #{search_result.type}"
puts "  Source: #{search_result.source}"
puts "  Title: #{search_result.title}"
puts ""

# ── 6. Server Tool Usage in Response ──────────────────────────────
puts "=== Server Tool Usage ==="
puts "Track server tool usage (e.g., web search requests) in response usage stats."
puts ""

usage_json = %({"input_tokens":100,"output_tokens":50,"server_tool_use":{"web_search_requests":3}})
usage = Anthropic::Usage.from_json(usage_json)
if stu = usage.server_tool_use
  puts "  Web search requests: #{stu.web_search_requests}"
end
puts ""

# ── 7. Extended Tool Fields (Beta) ──────────────────────────────
puts "=== Extended Tool Fields ==="
puts "Beta fields on tool definitions for advanced control."
puts ""

extended_tool_def = Anthropic::ToolDefinition.new(
  name: "data_processor",
  description: "Process data from various sources",
  input_schema: Anthropic::InputSchema.build(
    properties: {
      "source" => Anthropic::Schema.string("Data source identifier"),
    },
    required: ["source"]
  ),
  allowed_callers: ["code_execution_20250825"],
  defer_loading: true,
  input_examples: [JSON.parse(%({"source": "sales_2025"}))],
  eager_input_streaming: true
)

puts "  Tool: #{extended_tool_def.name}"
puts "  allowed_callers: #{extended_tool_def.allowed_callers}"
puts "  defer_loading: #{extended_tool_def.defer_loading?}"
puts "  input_examples: #{extended_tool_def.input_examples.try(&.size)} example(s)"
puts "  eager_input_streaming: #{extended_tool_def.eager_input_streaming}"
puts ""

# ── 8. ServerToolUseContent.caller ──────────────────────────────
puts "=== ServerToolUseContent.caller ==="
puts "Indicates which tool or entity invoked a server tool."
puts ""

# Parse a server_tool_use block with caller field
stu_json = %({"type":"server_tool_use","id":"stu_01","name":"code_execution","input":{"code":"print(42)"},"caller":"code_execution_20250825"})
stu = Anthropic::ServerToolUseContent.from_json(stu_json)
puts "  Tool: #{stu.name}"
puts "  Caller: #{stu.caller}"
puts "  (nil when no caller): #{Anthropic::ServerToolUseContent.from_json(%({"type":"server_tool_use","id":"stu_02","name":"web_search","input":{"query":"test"}})).caller.inspect}"
puts ""

# ── 9. CompactionDelta ──────────────────────────────────────────
puts "=== CompactionDelta ==="
puts "Streaming delta type for compaction events."
puts ""

# Parse directly
delta = Anthropic::CompactionDelta.new(content: "Compacted summary text.")
puts "  type: #{delta.type}"
puts "  content: #{delta.content}"

# Parse via StreamDeltaConverter (as it would arrive in a stream)
event_json = %({"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"Summary of prior conversation."}})
event = Anthropic::ContentBlockDeltaEvent.from_json(event_json)
if compaction = event.delta.as?(Anthropic::CompactionDelta)
  puts "  Parsed from event: #{compaction.content}"
end
puts ""

# ── 10. Usage Enrichments: CacheCreation & Inference Geo ──────
puts "=== Usage Enrichments ==="
puts "The usage object may include cache_creation (token breakdown by TTL)"
puts "and inference_geo (where inference was processed)."
puts ""

# Parse a usage object that contains the enriched fields
enriched_json = %({
  "input_tokens": 150,
  "output_tokens": 42,
  "cache_creation": {
    "ephemeral_1h_input_tokens": 100,
    "ephemeral_5m_input_tokens": 50
  },
  "inference_geo": "us"
})
enriched_usage = Anthropic::Usage.from_json(enriched_json)

puts "  Input tokens: #{enriched_usage.input_tokens}"
puts "  Output tokens: #{enriched_usage.output_tokens}"

if cc = enriched_usage.cache_creation
  puts "  Cache creation breakdown:"
  puts "    Ephemeral 1h tokens: #{cc.ephemeral_1h_input_tokens}"
  puts "    Ephemeral 5m tokens: #{cc.ephemeral_5m_input_tokens}"
end

if geo = enriched_usage.inference_geo
  puts "  Inference geo: #{geo}"
end
puts ""

# Also demonstrate with a real API call
enriched_message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 50,
  messages: [{role: "user", content: "Say hello briefly."}]
)
puts "  Real API call usage:"
puts "    Input tokens: #{enriched_message.usage.input_tokens}"
puts "    Output tokens: #{enriched_message.usage.output_tokens}"
puts "    Cache creation: #{enriched_message.usage.cache_creation.inspect}"
puts "    Inference geo: #{enriched_message.usage.inference_geo.inspect}"
puts ""

puts "Done! All advanced features demonstrated."
