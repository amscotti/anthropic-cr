require "../src/anthropic-cr"
require "dotenv"

# Typed Tools example: Ruby BaseTool-like pattern with typed inputs
#
# This example demonstrates using Crystal structs to define tool inputs,
# similar to Ruby's BaseModel/BaseTool pattern. Benefits:
# - Type-safe inputs (no JSON::Any casting)
# - IDE autocomplete on input fields
# - Compile-time type checking
# - Schema auto-generated from struct definition
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/18_typed_tools.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

# ============================================================================
# Define input structs with annotations
# ============================================================================

# Temperature unit enum
enum TemperatureUnit
  Celsius
  Fahrenheit
end

# Weather tool input - struct defines the schema!
struct GetWeatherInput
  include JSON::Serializable

  @[JSON::Field(description: "City name, e.g. San Francisco, CA")]
  getter location : String

  @[JSON::Field(description: "Temperature unit (celsius or fahrenheit)")]
  getter unit : TemperatureUnit?
end

# Product category enum
enum ProductCategory
  Electronics
  Clothing
  Books
  Home
end

# Sort order enum
enum SortOrder
  Relevance
  PriceLow
  PriceHigh
  Rating
end

# Search tool input with multiple fields
# Note: Using String? for price fields because Claude may return numbers as strings
# For production use, you'd add a custom JSON converter to handle both formats
struct SearchProductsInput
  include JSON::Serializable

  @[JSON::Field(description: "Search query")]
  getter query : String

  @[JSON::Field(description: "Product category to filter by")]
  getter category : ProductCategory?

  @[JSON::Field(description: "Minimum price filter (number)")]
  getter min_price : JSON::Any?

  @[JSON::Field(description: "Maximum price filter (number)")]
  getter max_price : JSON::Any?

  @[JSON::Field(description: "Sort order for results")]
  getter sort_by : SortOrder?

  # Helper to get max_price as Float64
  def max_price_value : Float64?
    return nil unless mp = max_price
    mp.as_f? || mp.as_s?.try(&.to_f?)
  end

  # Helper to get min_price as Float64
  def min_price_value : Float64?
    return nil unless mp = min_price
    mp.as_f? || mp.as_s?.try(&.to_f?)
  end
end

# Calculator operation enum
enum Operation
  Add
  Subtract
  Multiply
  Divide
end

# Calculator tool input
struct CalculatorInput
  include JSON::Serializable

  @[JSON::Field(description: "Mathematical operation to perform")]
  getter operation : Operation

  @[JSON::Field(description: "First number")]
  getter a : Float64

  @[JSON::Field(description: "Second number")]
  getter b : Float64
end

# ============================================================================
# Create typed tools
# ============================================================================

client = Anthropic::Client.new

puts "Typed Tools Example (Ruby BaseTool-like pattern)"
puts "=" * 60
puts

# Create weather tool with typed input
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  input: GetWeatherInput
) do |input|
  # input is GetWeatherInput, not JSON::Any!
  # IDE provides autocomplete for input.location, input.unit
  unit = input.unit || TemperatureUnit::Fahrenheit
  temp = unit == TemperatureUnit::Celsius ? "22°C" : "72°F"
  "The weather in #{input.location} is sunny and #{temp}."
end

# Create search tool with typed input
search_tool = Anthropic.tool(
  name: "search_products",
  description: "Search for products in the catalog",
  input: SearchProductsInput
) do |input|
  # Typed access to all fields
  results = ["Widget Pro", "Gadget Max", "Tech Item"]

  filters = [] of String
  filters << "category: #{input.category}" if input.category
  filters << "min: $#{input.min_price_value}" if input.min_price_value
  filters << "max: $#{input.max_price_value}" if input.max_price_value
  filters << "sort: #{input.sort_by}" if input.sort_by

  filter_str = filters.empty? ? "" : " (#{filters.join(", ")})"
  "Found #{results.size} products for '#{input.query}'#{filter_str}: #{results.join(", ")}"
end

# Create calculator tool with typed input
calculator_tool = Anthropic.tool(
  name: "calculate",
  description: "Perform mathematical calculations",
  input: CalculatorInput
) do |input|
  # Type-safe operation handling
  result = case input.operation
           when Operation::Add      then input.a + input.b
           when Operation::Subtract then input.a - input.b
           when Operation::Multiply then input.a * input.b
           when Operation::Divide   then input.a / input.b
           else                          0.0
           end
  "#{input.a} #{input.operation.to_s.downcase} #{input.b} = #{result}"
end

# ============================================================================
# Use the tools
# ============================================================================

puts "Example 1: Weather tool with typed input"
puts "-" * 60

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [weather_tool],
  messages: [{role: "user", content: "What's the weather in Tokyo? Use celsius."}]
)

if message.tool_use?
  message.tool_use_blocks.each do |tool_use|
    puts "Tool called: #{tool_use.name}"
    puts "Input: #{tool_use.input.to_pretty_json}"
    result = weather_tool.call(tool_use.input)
    puts "Result: #{result}"
  end
else
  message.text_blocks.each { |block| puts block.text }
end
puts

puts "Example 2: Search tool with multiple typed fields"
puts "-" * 60

message2 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [search_tool],
  messages: [{role: "user", content: "Search for wireless headphones in electronics under $100, sorted by rating"}]
)

if message2.tool_use?
  message2.tool_use_blocks.each do |tool_use|
    puts "Tool called: #{tool_use.name}"
    puts "Input: #{tool_use.input.to_pretty_json}"
    result = search_tool.call(tool_use.input)
    puts "Result: #{result}"
  end
else
  puts message2.text
end
puts

puts "Example 3: Calculator with enum operation"
puts "-" * 60

message3 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [calculator_tool],
  messages: [{role: "user", content: "Calculate 15 multiplied by 7"}]
)

if message3.tool_use?
  message3.tool_use_blocks.each do |tool_use|
    puts "Tool called: #{tool_use.name}"
    puts "Input: #{tool_use.input.to_pretty_json}"
    result = calculator_tool.call(tool_use.input)
    puts "Result: #{result}"
  end
else
  puts message3.text
end
puts

puts "=" * 60
puts "Typed tools provide compile-time safety and IDE autocomplete!"
puts
puts "Compare:"
puts "  OLD: input[\"location\"].as_s  # Manual casting"
puts "  NEW: input.location           # Type-safe access"
