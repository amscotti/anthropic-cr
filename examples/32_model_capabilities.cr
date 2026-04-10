require "../src/anthropic-cr"
require "dotenv"

# Model Capabilities example: inspect richer Models API metadata
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/32_model_capabilities.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Model Capabilities Example"
puts "=" * 60
puts

model = client.models.retrieve(Anthropic::Model::CLAUDE_SONNET_4_6)

puts "Model: #{model.display_name}"
puts "ID: #{model.id}"
puts "Created: #{model.created_at}"
puts "Max input tokens: #{model.max_input_tokens || "unknown"}"
puts "Max output tokens: #{model.max_tokens || "unknown"}"
puts

if capabilities = model.capabilities
  puts "Capabilities"
  puts "- Batch API: #{capabilities.batch.supported?}"
  puts "- Citations: #{capabilities.citations.supported?}"
  puts "- Code execution: #{capabilities.code_execution.supported?}"
  puts "- Image input: #{capabilities.image_input.supported?}"
  puts "- PDF input: #{capabilities.pdf_input.supported?}"
  puts "- Structured outputs: #{capabilities.structured_outputs.supported?}"
  puts "- Thinking: #{capabilities.thinking.supported?}"
  puts "- Thinking adaptive: #{capabilities.thinking.types.adaptive.supported?}"
  puts "- Thinking enabled: #{capabilities.thinking.types.enabled.supported?}"
  puts "- Effort control: #{capabilities.effort.supported?}"
  puts "- Context management: #{capabilities.context_management.supported?}"

  if compact = capabilities.context_management.compact_20260112
    puts "- Compaction strategy 20260112: #{compact.supported?}"
  end
else
  puts "No capability metadata returned for this model."
end
