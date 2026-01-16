require "../src/anthropic-cr"
require "dotenv"

# Structured outputs example: Type-safe JSON responses
#
# Demonstrates:
# - Defining output types as Crystal structs
# - Getting structured responses from Claude
# - Type-safe access to response data
#
# Run with:
#   crystal run examples/15_structured_outputs.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# Define output types as Crystal structs
struct FamousNumber
  include JSON::Serializable

  @[JSON::Field(description: "The numeric value")]
  getter value : Float64

  @[JSON::Field(description: "Why this number is significant")]
  getter reason : String?
end

struct Output
  include JSON::Serializable

  @[JSON::Field(description: "Array of 3-5 famous numbers")]
  getter numbers : Array(FamousNumber)
end

# Create schema from struct
schema = Anthropic.output_schema(
  type: Output,
  name: "famous_numbers"
)

message = client.beta.messages.create(
  betas: [Anthropic::STRUCTURED_OUTPUT_BETA],
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  output_schema: schema,
  messages: [{role: "user", content: "List some famous mathematical numbers."}]
)

# Parse directly to typed struct
output = Output.from_json(message.text)

puts "Famous Numbers:"
puts
output.numbers.each do |num|
  puts "  #{num.value}"
  puts "    #{num.reason}" if num.reason
  puts
end

# Alternative: Access via parsed_output helper
if parsed = message.parsed_output
  puts "Via parsed_output:"
  puts parsed.to_pretty_json
end
