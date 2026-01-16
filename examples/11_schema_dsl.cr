require "../src/anthropic-cr"
require "dotenv"

# Schema DSL example: Type-safe tool input definitions
#
# This example demonstrates the Schema DSL that provides clean,
# type-safe tool schema definitions.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/11_schema_dsl.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Schema DSL Example"
puts "=" * 60
puts

# Schema DSL provides clean, type-safe tool definitions:
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  schema: {
    "location" => Anthropic::Schema.string("City name, e.g. San Francisco, CA"),
    "unit"     => Anthropic::Schema.enum("celsius", "fahrenheit", description: "Temperature unit"),
  },
  required: ["location"]
) do |input|
  location = input["location"].as_s
  unit = input["unit"]?.try(&.as_s) || "fahrenheit"
  temp = unit == "celsius" ? "22" : "72"
  "The weather in #{location} is sunny and #{temp}°#{unit == "celsius" ? "C" : "F"}."
end

puts "Tool defined with Schema DSL:"
puts "  - Name: #{weather_tool.name}"
puts "  - Description: #{weather_tool.description}"
puts

# More complex schema example with nested objects and arrays
inventory_tool = Anthropic.tool(
  name: "check_inventory",
  description: "Check product inventory at a store",
  schema: {
    "product_id" => Anthropic::Schema.string("Product SKU"),
    "store_ids"  => Anthropic::Schema.array(
      Anthropic::Schema.string,
      description: "Store IDs to check",
      min_items: 1,
      max_items: 5
    ),
    "include_nearby" => Anthropic::Schema.boolean("Include nearby stores in search"),
    "max_distance"   => Anthropic::Schema.number("Maximum distance in miles", minimum: 0.0, maximum: 100.0),
    "quantity"       => Anthropic::Schema.integer("Minimum quantity needed", minimum: 1),
  },
  required: ["product_id", "store_ids"]
) do |input|
  product = input["product_id"].as_s
  stores = input["store_ids"].as_a.map(&.as_s).join(", ")
  "Product #{product} is available at stores: #{stores}"
end

puts "Complex tool with nested schema:"
puts "  - Name: #{inventory_tool.name}"
puts

# Test the weather tool with Claude
puts "Testing weather tool with Claude..."
puts "-" * 60

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 1024,
  messages: [
    {role: "user", content: "What's the weather like in Tokyo? Use celsius."},
  ],
  tools: [weather_tool]
)

if message.tool_use?
  tool_blocks = message.tool_use_blocks
  tool_blocks.each do |tool_use|
    puts "Claude wants to use: #{tool_use.name}"
    puts "With input: #{tool_use.input}"

    # Execute the tool
    result = weather_tool.call(tool_use.input)
    puts "Result: #{result}"
  end
else
  text = message.text_blocks.first?.try(&.text) || ""
  puts "Response: #{text}"
end

puts
puts "=" * 60
puts "Schema DSL makes tool definitions more readable and type-safe!"
