require "../src/anthropic-cr"
require "dotenv"

# Tool Runner example: Automatic tool execution loop
#
# The tool runner automatically executes tools and continues the conversation
# until Claude provides a final answer without needing tools.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/09_tool_runner.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# Define multiple tools using Schema DSL
calculator = Anthropic.tool(
  name: "calculator",
  description: "Perform basic arithmetic calculations",
  schema: {
    "expression" => Anthropic::Schema.string("Mathematical expression, e.g. '2 + 2' or '10 * 5'"),
  },
  required: ["expression"]
) do |input|
  expr = input["expression"].as_s
  # Simple eval-like behavior (in real code, use a proper parser)
  case expr
  when /(\d+)\s*\+\s*(\d+)/ then ($1.to_i + $2.to_i).to_s
  when /(\d+)\s*\*\s*(\d+)/ then ($1.to_i * $2.to_i).to_s
  when /(\d+)\s*-\s*(\d+)/  then ($1.to_i - $2.to_i).to_s
  else                           "Cannot parse expression"
  end
end

time_tool = Anthropic.tool(
  name: "get_time",
  description: "Get the current time",
  schema: {} of String => Anthropic::Schema::Property,
  required: [] of String
) do |_input|
  Time.local.to_s("%Y-%m-%d %H:%M:%S")
end

puts "Using Tool Runner for automatic tool execution..."
puts "=" * 60
puts

# Create a tool runner (in beta namespace, matching Ruby SDK)
runner = client.beta.messages.tool_runner(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.user("What time is it right now? Also, what is 15 + 27?"),
  ],
  tools: [calculator, time_tool] of Anthropic::Tool,
  max_iterations: 5
)

# Iterate through each message in the conversation
iteration = 0
runner.each_message do |message|
  iteration += 1
  puts "Iteration #{iteration}:"
  puts "-" * 60

  if message.tool_use?
    puts "Claude wants to use tools:"
    message.tool_use_blocks.each do |tool_use|
      puts "  → #{tool_use.name}(#{tool_use.input})"
    end
  else
    puts "Final response:"
    message.text_blocks.each { |block| puts block.text }
  end

  puts
end

puts "=" * 60
puts "Conversation completed in #{iteration} iterations"
