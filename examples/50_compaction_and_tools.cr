require "../src/anthropic-cr"
require "dotenv"

# Explicit compaction and mid-conversation tool changes (v0.11.0)
#
# Demonstrates `SummarizeCompaction` on beta messages, signed compaction
# blocks, and the runner's `add_tools` / `remove_tools` /
# `compact_before_next_turn` controls.
#
# Run with:
#   crystal run examples/50_compaction_and_tools.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

messages = [
  Anthropic::MessageParam.user("Our project uses Crystal. Remember that."),
  Anthropic::MessageParam.new(role: "assistant", content: "Noted: the project uses Crystal."),
  Anthropic::MessageParam.user("What language do we use?"),
]

# 1. Ask the API to compact the conversation instead of sampling a reply.
compacted = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_5_5,
  max_tokens: 1024,
  messages: messages,
  compaction: Anthropic::SummarizeCompaction.new(instructions: "Keep project facts.")
)

summary = compacted.content.compact_map { |block| block.as?(Anthropic::CompactionContent) }.first?
puts "Summary: #{summary.try(&.content)}"
puts "Signature: #{summary.try(&.signature) ? "present" : "absent"}"

# 2. Send the signed block back first in place of the summarized messages.
if summary
  followup = client.beta.messages.create(
    model: Anthropic::Model::CLAUDE_OPUS_5_5,
    max_tokens: 256,
    messages: [
      Anthropic::MessageParam.new(role: "assistant", content: [summary.as(Anthropic::ContentBlock)]),
      Anthropic::MessageParam.user("What language do we use?"),
    ]
  )
  puts "Follow-up: #{followup.content.compact_map { |block| block.as?(Anthropic::TextContent) }.map(&.text).join}"
end

# 3. Mid-conversation tool changes on the tool runner.
calculator = Anthropic.tool(
  name: "calculator",
  description: "Evaluate simple arithmetic like '2 + 3'.",
  schema: {"expression" => Anthropic::Schema.string("Arithmetic expression")},
  required: ["expression"]
) do |input|
  expr = input["expression"].as_s
  case expr
  when /(\d+)\s*\+\s*(\d+)/ then ($1.to_i + $2.to_i).to_s
  else                           "Cannot parse expression"
  end
end

runner = client.beta.messages.tool_runner(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 512,
  messages: [Anthropic::MessageParam.user("What is 20 + 22?")],
  tools: [calculator] of Anthropic::Tool
)

# Offer a notetaking tool from the next request on, then compact the
# conversation once the current turn (including tool calls) finishes.
notes = Anthropic.tool(
  name: "notes",
  description: "Record a short note.",
  schema: {"note" => Anthropic::Schema.string("Note text")},
  required: ["note"]
) do |input|
  "noted: #{input["note"].as_s}"
end

runner.add_tools(notes)
runner.compact_before_next_turn

while msg = runner.next_message
  msg.content.each do |block|
    case block
    when Anthropic::TextContent
      puts "Text: #{block.text}"
    when Anthropic::CompactionContent
      puts "Compacted: #{block.content}"
    end
  end
end

# Withdrawing a tool stops it from running straight away; the removal
# rides along on the next request.
runner.remove_tools("notes")
runner.feed_message(Anthropic::MessageParam.user("Thanks!"))
if msg = runner.next_message
  puts "After removal: #{msg.content.compact_map { |block| block.as?(Anthropic::TextContent) }.map(&.text).join}"
end
