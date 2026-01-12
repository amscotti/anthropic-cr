require "../src/anthropic"
require "dotenv"

# Tools Streaming example: Watch tool calls being built in real-time
#
# When Claude uses tools, you can stream the tool input JSON as it's generated.
# This is useful for:
# - Showing progress during complex tool calls
# - Early validation of tool inputs
# - Building responsive UIs
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/16_tools_streaming.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Tools Streaming Example"
puts "=" * 60
puts

# Define a complex tool with multiple parameters
search_tool = Anthropic.tool(
  name: "search_products",
  description: "Search for products in the catalog",
  schema: {
    "query"     => Anthropic::Schema.string("Search query"),
    "category"  => Anthropic::Schema.enum("electronics", "clothing", "books", "home", description: "Product category"),
    "min_price" => Anthropic::Schema.number("Minimum price", minimum: 0.0),
    "max_price" => Anthropic::Schema.number("Maximum price"),
    "sort_by"   => Anthropic::Schema.enum("relevance", "price_low", "price_high", "rating", description: "Sort order"),
  },
  required: ["query"]
) do |input|
  # Simulated search results
  query = input["query"].as_s
  "Found 5 products matching '#{query}'"
end

puts "Example 1: Stream tool input JSON"
puts "-" * 60

print "Streaming tool call: "
tool_json_parts = [] of String
current_tool_name = ""

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [search_tool],
  messages: [{role: "user", content: "Search for wireless headphones under $100, sorted by rating"}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    if tool_use = event.content_block.as?(Anthropic::ToolUseContent)
      current_tool_name = tool_use.name
      print "\n  Tool: #{current_tool_name}\n  Input: "
    end
  when Anthropic::ContentBlockDeltaEvent
    # Stream text
    if text = event.text
      print text
      STDOUT.flush
    end

    # Stream tool input JSON
    if partial_json = event.partial_json
      tool_json_parts << partial_json
      print partial_json
      STDOUT.flush
    end
  when Anthropic::ContentBlockStopEvent
    if !tool_json_parts.empty?
      puts "\n  (Tool input complete)"
      tool_json_parts.clear
    end
  end
end

puts
puts

# Example 2: Using the tool_use_deltas iterator
puts "Example 2: Using tool_use_deltas iterator"
puts "-" * 60

weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get weather for multiple cities",
  schema: {
    "cities" => Anthropic::Schema.array(
      Anthropic::Schema.string,
      description: "List of city names",
      min_items: 1
    ),
    "units" => Anthropic::Schema.enum("celsius", "fahrenheit"),
  },
  required: ["cities"]
) do |input|
  cities = input["cities"].as_a.map(&.as_s)
  "Weather data for #{cities.join(", ")}"
end

print "Tool deltas: "
client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [weather_tool],
  messages: [{role: "user", content: "What's the weather in Tokyo, London, and New York? Use fahrenheit."}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    if tool_use = event.content_block.as?(Anthropic::ToolUseContent)
      print "\n[#{tool_use.name}] "
    end
  when Anthropic::ContentBlockDeltaEvent
    if partial = event.partial_json
      print partial
      STDOUT.flush
    end
  end
end

puts
puts

# Example 3: Stream with multiple tool calls
puts "Example 3: Multiple tool calls in one response"
puts "-" * 60

calculator_tool = Anthropic.tool(
  name: "calculate",
  description: "Perform a calculation",
  schema: {
    "operation" => Anthropic::Schema.enum("add", "subtract", "multiply", "divide"),
    "a"         => Anthropic::Schema.number("First number"),
    "b"         => Anthropic::Schema.number("Second number"),
  },
  required: ["operation", "a", "b"]
) do |input|
  a = input["a"].as_f
  b = input["b"].as_f
  op = input["operation"].as_s
  result = case op
           when "add"      then a + b
           when "subtract" then a - b
           when "multiply" then a * b
           when "divide"   then a / b
           else                 0.0
           end
  result.to_s
end

tool_count = 0
client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  tools: [calculator_tool],
  messages: [{role: "user", content: "Calculate: (15 + 7) and (100 / 4)"}]
) do |event|
  case event
  when Anthropic::ContentBlockStartEvent
    if tool_use = event.content_block.as?(Anthropic::ToolUseContent)
      tool_count += 1
      puts "Tool call ##{tool_count}: #{tool_use.name}"
      print "  Input: "
    end
  when Anthropic::ContentBlockDeltaEvent
    if text = event.text
      print text
      STDOUT.flush
    end
    if partial = event.partial_json
      print partial
      STDOUT.flush
    end
  when Anthropic::ContentBlockStopEvent
    if event.index > 0 && tool_count > 0
      puts
    end
  end
end

puts
puts "Total tool calls: #{tool_count}"
puts

puts "=" * 60
puts "Tool streaming provides visibility into Claude's function calls!"
