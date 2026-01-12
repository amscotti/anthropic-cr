# anthropic-cr

An unofficial Anthropic API client for Crystal. Access Claude AI models with idiomatic Crystal code.

**Status:** Feature Complete - Full Messages API, Batches API, Models API, Files API, tool runner, web search, extended thinking, structured outputs, citations, prompt caching, and Schema DSL. API design inspired by official Ruby SDK patterns.

> **Note:** A large portion of this library was written with the assistance of AI (Claude), including code, tests, and documentation.

## Features

- ✅ Messages API (create and stream)
- ✅ Streaming with Server-Sent Events
- ✅ Tool use / function calling
- ✅ **Schema DSL** - Type-safe tool definitions (no more JSON::Any)
- ✅ **Typed Tools** - Ruby BaseTool-like pattern with struct inputs
- ✅ Tool runner (automatic tool execution loop)
- ✅ **Web Search** - Built-in web search via server-side tool
- ✅ **Extended Thinking** - Enable Claude's reasoning process
- ✅ **Structured Outputs** - Type-safe JSON responses via beta API
- ✅ **Citations** - Document citations with streaming support
- ✅ **Beta Namespace** - `client.beta.messages` matching Ruby SDK
- ✅ Vision (image understanding)
- ✅ System prompts and temperature control
- ✅ Message Batches API (create, list, retrieve, results, cancel, delete)
- ✅ Models API (list and retrieve)
- ✅ Auto-pagination helpers
- ✅ Enhanced streaming helpers (text, tool_use_deltas, thinking, citations)
- ✅ Comprehensive error handling with automatic retries
- ✅ Type-safe API with full compile-time checking
- ✅ Files API (upload, download, delete)
- ✅ Token counting API
- ✅ Prompt caching with TTL control
- 🚧 AWS Bedrock & Google Vertex support (future)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     anthropic-cr:
       github: amscotti/anthropic-cr
   ```

2. Run `shards install`

## Quick Start

```crystal
require "anthropic"

# Initialize the client (uses ANTHROPIC_API_KEY from environment)
client = Anthropic::Client.new

# Create a message
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    {role: "user", content: "Hello, Claude!"}
  ]
)

puts message.text
# => "Hello! I'm Claude, an AI assistant..."
```

## Usage Examples

### Basic Message

```crystal
client = Anthropic::Client.new(api_key: "sk-ant-...")

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "What is Crystal?"}]
)

puts message.text
puts "Used #{message.usage.input_tokens} input tokens"
```

### Streaming

```crystal
client.messages.stream(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "Write a haiku about programming"}]
) do |event|
  if event.is_a?(Anthropic::ContentBlockDeltaEvent)
    print event.text if event.text
    STDOUT.flush
  end
end
```

### Tool Use with Schema DSL (Recommended)

The Schema DSL provides clean, type-safe tool definitions without verbose JSON::Any syntax:

```crystal
# Define a tool with Schema DSL
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  schema: {
    "location" => Anthropic::Schema.string("City name, e.g. San Francisco"),
    "unit"     => Anthropic::Schema.enum("celsius", "fahrenheit", description: "Temperature unit"),
  },
  required: ["location"]
) do |input|
  location = input["location"].as_s
  unit = input["unit"]?.try(&.as_s) || "fahrenheit"
  "Sunny, 72°#{unit == "celsius" ? "C" : "F"} in #{location}"
end

# Use it
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "What's the weather in Tokyo?"}],
  tools: [weather_tool]
)

if message.tool_use?
  message.tool_use_blocks.each do |tool_use|
    result = weather_tool.call(tool_use.input)
    puts result
  end
end
```

Schema DSL supports: `string`, `number`, `integer`, `boolean`, `enum`, `array`, and nested `object` types.

### Typed Tools (Ruby BaseTool-like)

For type-safe inputs, define structs and use the `Anthropic.tool` macro:

```crystal
# Define input struct with annotations
struct GetWeatherInput
  include JSON::Serializable

  @[JSON::Field(description: "City name, e.g. San Francisco")]
  getter location : String

  @[JSON::Field(description: "Temperature unit")]
  getter unit : TemperatureUnit?
end

enum TemperatureUnit
  Celsius
  Fahrenheit
end

# Create typed tool - handler receives typed struct!
weather_tool = Anthropic.tool(
  name: "get_weather",
  description: "Get weather for a location",
  input: GetWeatherInput
) do |input|
  # input.location is String, not JSON::Any!
  unit = input.unit || TemperatureUnit::Fahrenheit
  "Sunny, 72° in #{input.location}"
end
```

### Structured Outputs

Get type-safe JSON responses with defined schemas:

```crystal
# Define output struct
struct SentimentResult
  include JSON::Serializable
  getter sentiment : String
  getter confidence : Float64
  getter summary : String
end

# Create schema from struct
schema = Anthropic.output_schema(
  type: SentimentResult,
  name: "sentiment_result"
)

# Use with beta API
message = client.beta.messages.create(
  betas: [Anthropic::STRUCTURED_OUTPUT_BETA],
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 512,
  output_schema: schema,
  messages: [{role: "user", content: "Analyze: 'Great product!'"}]
)

# Parse directly to typed struct
result = SentimentResult.from_json(message.text)
puts result.sentiment    # Type-safe access
puts result.confidence   # No .as_f casting needed!
```

### Web Search

Let Claude search the internet for current information:

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 2048,
  server_tools: [Anthropic::WebSearchTool.new],
  messages: [{role: "user", content: "What are the latest developments in Crystal programming?"}]
)

puts message.text  # Response includes web search results
```

Configure web search with domain limits or location:

```crystal
# Limit to specific domains
search = Anthropic::WebSearchTool.new(
  allowed_domains: ["github.com", "crystal-lang.org"],
  max_uses: 3
)

# Location-aware search
# Note: user_location affects search RANKING, use system prompt for Claude awareness
search = Anthropic::WebSearchTool.new(
  user_location: Anthropic::UserLocation.new(city: "San Francisco", country: "US")
)
# Use with system prompt: "The user is located in San Francisco, California."
```

### Extended Thinking

Enable Claude's reasoning process for complex problems:

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 8192,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 4000),
  messages: [{role: "user", content: "Solve this logic puzzle..."}]
)

# Response includes both thinking and final answer
message.content.each do |block|
  case block["type"]?.try(&.as_s)
  when "thinking"
    puts "Thinking: #{block["thinking"]?.try(&.as_s)}"
  when "text"
    puts "Answer: #{block["text"]?.try(&.as_s)}"
  end
end
```

### Vision

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        Anthropic::TextContent.new("Describe this image"),
        Anthropic::ImageContent.base64("image/png", base64_data)
      ] of Anthropic::ContentBlock
    )
  ]
)
```

### System Prompts & Parameters

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_5,
  max_tokens: 2048,
  system: "You are a helpful coding assistant specializing in Crystal.",
  temperature: 0.7,
  messages: [{role: "user", content: "How do I create a HTTP server?"}]
)
```

### Message Batches (Phase 2)

Process multiple messages in a single batch for cost-effective, high-throughput use cases:

```crystal
# Create batch requests
requests = [
  Anthropic::BatchRequest.new(
    custom_id: "req-1",
    params: Anthropic::BatchRequestParams.new(
      model: Anthropic::Model::CLAUDE_HAIKU_4_5,
      max_tokens: 100,
      messages: [Anthropic::MessageParam.user("What is 2+2?")]
    )
  ),
  Anthropic::BatchRequest.new(
    custom_id: "req-2",
    params: Anthropic::BatchRequestParams.new(
      model: Anthropic::Model::CLAUDE_HAIKU_4_5,
      max_tokens: 100,
      messages: [Anthropic::MessageParam.user("What is the capital of France?")]
    )
  ),
]

# Create and monitor batch
batch = client.messages.batches.create(requests: requests)
puts batch.id  # => "msgbatch_..."

# Check status
status = client.messages.batches.retrieve(batch.id)
puts status.processing_status  # => "in_progress" | "ended"

# When ended, get results
client.messages.batches.results(batch.id) do |result|
  puts "#{result.custom_id}: #{result.result.message.try(&.text)}"
end
```

### Models API (Phase 2)

List and retrieve available Claude models:

```crystal
# List all models
response = client.models.list
response.each do |model|
  puts "#{model.display_name} (#{model.id})"
end

# Retrieve specific model
model = client.models.retrieve(Anthropic::Model::CLAUDE_SONNET_4_5)
puts model.display_name  # => "Claude Sonnet 4.5"
```

### Tool Runner (Beta)

Automatic tool execution loop - no manual handling required:

```crystal
# Define tools
calculator = Anthropic.tool(...) { |input| calculate(input) }
time_tool = Anthropic.tool(...) { |input| Time.local.to_s }

# Create runner (in beta namespace, matching Ruby SDK)
runner = client.beta.messages.tool_runner(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [Anthropic::MessageParam.user("What time is it? Also calculate 15 + 27")],
  tools: [calculator, time_tool] of Anthropic::Tool
)

# Iterate through conversation (tools executed automatically)
runner.each_message { |msg| puts msg.text unless msg.tool_use? }

# Or just get the final answer
final = runner.final_message
puts final.text
```

## Model Constants

```crystal
Anthropic::Model::CLAUDE_OPUS_4_5      # Latest Opus
Anthropic::Model::CLAUDE_SONNET_4_5    # Latest Sonnet
Anthropic::Model::CLAUDE_HAIKU_4_5     # Latest Haiku

# Or use shorthands
Anthropic.model_name(:opus)    # => "claude-opus-4-5-20251101"
Anthropic.model_name(:sonnet)  # => "claude-sonnet-4-5-20250929"
Anthropic.model_name(:haiku)   # => "claude-haiku-4-5-20251001"
```

## Examples

See the [examples/](./examples/) directory for complete working examples:

**Phase 1 (Core API):**
- `01_basic_message.cr` - Simple message creation
- `02_streaming.cr` - Real-time streaming responses
- `03_tool_use.cr` - Function calling with tools
- `04_vision.cr` - Image understanding
- `05_system_prompt.cr` - System prompts and temperature
- `06_error_handling.cr` - Error handling and retries

**Phase 2 (Advanced Features):**
- `07_list_models.cr` - List and retrieve models
- `08_batches.cr` - Message batches (batch processing)
- `09_tool_runner.cr` - Automatic tool execution loop
- `10_pagination.cr` - Auto-pagination helpers

**Phase 2.5 (Enhanced):**
- `11_schema_dsl.cr` - Type-safe Schema DSL for tool definitions
- `12_web_search.cr` - Web search server-side tool
- `13_extended_thinking.cr` - Extended thinking / reasoning
- `14_citations.cr` - Document citations with streaming
- `15_structured_outputs.cr` - Type-safe JSON responses (Schema DSL + Typed Structs)
- `16_tools_streaming.cr` - Tool input streaming
- `17_web_search_streaming.cr` - Web search with streaming
- `18_typed_tools.cr` - Ruby BaseTool-like typed inputs
- `19_files_api.cr` - File uploads and management
- `20_chatbot.cr` - Interactive chatbot example
- `21_token_counting.cr` - Token counting for context management
- `22_prompt_caching.cr` - Prompt caching for efficiency
- `23_auto_compaction.cr` - Automatic context compaction
- `24_advanced_streaming.cr` - Advanced streaming patterns

Run examples with:
```bash
crystal run examples/01_basic_message.cr
```

## Development

```bash
# Install dependencies
shards install

# Run tests
crystal spec

# Format code
crystal tool format

# Run linter
./bin/ameba

# Type check
crystal build --no-codegen src/anthropic.cr
```


## Contributing

1. Fork it (<https://github.com/amscotti/anthropic-cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Anthony Scotti](https://github.com/amscotti) - creator and maintainer
