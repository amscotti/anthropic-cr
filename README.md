# anthropic-cr

An unofficial Anthropic API client for Crystal. Access Claude AI models with idiomatic Crystal code.

**Status:** Feature Complete — Full Messages API (`anthropic-version: 2026-10-21`, `Authorization: Bearer` auth), Batches API, Models API (with `lifecycle` / `line` metadata & `server_tools` capabilities), GA User Profiles API (`client.user_profiles`), GA & Beta Organization Admin API (`client.organization` + RBAC, spend limits, analytics, plugins, telemetry destinations, webhooks, Claude Tag), Managed Agents API (agents, environments, sessions, workflow runs, deployments, memory stores, vaults, dreams, MCP tunnels), Beta Message Threads (`BetaMessageThread`) with default `ToolRunner` integration, Browser & Computer toolsets (`20260801`), web search, advisor tool, extended thinking (including adaptive, `between_tools`, and `xhigh` effort), structured outputs, citations, prompt caching, Schema DSL, HTTP middleware, server-side and client-side refusal fallbacks, alternate cloud providers (AWS, Bedrock Runtime/Mantle, Google Cloud, Vertex AI), and 98-entry `(status, error_code)` typed error dispatch. Tracks the `2026-10-21` release (Python 2.8.0 / Ruby 2.8.0 / TypeScript 1.8.0) of the official SDKs. API design inspired by official Ruby SDK patterns.

> **Note:** A large portion of this library was written with the assistance of AI (Claude), including code, tests, and documentation.

## Features

- ✅ Messages API (create and stream)
- ✅ Streaming with Server-Sent Events (`stream` and `open_stream`)
- ✅ **Typed Stream Errors** — SSE `error` events raise the appropriate `Anthropic::APIError` subclass mid-stream
- ✅ Tool use / function calling
- ✅ **Schema DSL** — Type-safe tool definitions (no more `JSON::Any`)
- ✅ **Typed Tools** — Ruby BaseTool-like pattern with struct inputs
- ✅ Tool runner (automatic tool execution loop)
- ✅ **Web Search** — Built-in web search via server-side tool
- ✅ **Agent Tools** — BashTool, TextEditorTool, ComputerUseTool for agentic workflows
- ✅ **Web Fetch** — Built-in web page fetching via server-side tool
- ✅ **Memory** — Persistent memory tool for cross-conversation context
- ✅ **Code Execution** — Sandboxed code execution via server-side tool (four versions: `20250522`, `20250825`, `20260120`, `20260521`)
- ✅ **Web Fetch / Web Search (March 2026)** — `WebFetchTool20260318` and `WebSearchTool20260318` with `response_inclusion`
- ✅ **Advisor Tool** (`advisor_20260301`) — Delegate sub-questions to a secondary model at runtime
- ✅ **Strict Mode** — Enforce strict schema validation on tool definitions
- ✅ **Extended Thinking** — Claude's reasoning process (including adaptive thinking)
- ✅ **Redacted Thinking** — Parse and preserve redacted thinking blocks in multi-turn
- ✅ **Context Management** — Beta auto-compaction, clear tool uses, clear thinking, compaction streaming delta, encrypted compaction (`encrypted_content`)
- ✅ **MCP Servers** — Beta `mcp_servers` parameter for server-side MCP server definitions
- ✅ **Containers** — Core container reuse plus beta container skill loading
- ✅ **Tool Search** — BM25 and Regex tool search for deferred tool loading
- ✅ **Legacy Tool Versions** — October 2024 and intermediate versions (`BashToolLegacy`, `TextEditorToolLegacy`, `TextEditorTool20250124`, `TextEditorTool20250429`, `ComputerUseToolLegacy`)
- ✅ **HTTP Middleware** — Inspect, rewrite, or short-circuit requests/responses around the SDK's terminal HTTP send (`Anthropic::Middleware`, runs per attempt inside the retry loop)
- ✅ **Server-Side Fallbacks** — Automatic refusal retries via `fallbacks:` (array chain or `"default"`) + `server-side-fallback-2026-07-01` beta; `FallbackContent` block + per-hop `usage.iterations` + `usage.fallback_credit` / `usage.speed`
- ✅ **Client-Side Refusal Fallback Middleware** — `Anthropic::BetaRefusalFallbackMiddleware` with object-form `fallback_credit_token` (`strict` / `best_effort`, `fallback-credit-2026-07-01`)
- ✅ **Tool Addition / Removal** — Mid-conversation `tool_addition` / `tool_removal` content blocks (including inside `mid_conv_system`); tool runner folds them into available tools
- ✅ **Dreams API** — Memory-consolidation jobs (`client.beta.dreams`; beta `dreaming-2026-04-21`; research preview)
- ✅ **MCP Tunnels API** — Private MCP routing + certificates (`client.beta.tunnels`; `mcp-tunnels-2026-06-22`; `transport` `cloudflare` / `relay`; management via WIF)
- ✅ **Managed Agents Model Effort & Workflows** — Agent `model` config with `effort` / `speed`, `execution_identity`, `multiagent_20261001`, session `initial_events`, `workflow_run.*` events, and `SessionRunner` idle handling
- ✅ **Skills API** — Full CRUD for skills and skill versions (beta)
- ✅ **User Profiles API (GA + Beta)** — GA `client.user_profiles` (`create`, `retrieve`, `update`, `list`, `delete`, `action_urls.create`, enforcement actions, `cyber`/`efs` programs) plus `client.beta.user_profiles` (`user-profiles-2026-08-18` / `2026-09-04`); `user_profile_id:` sent via `anthropic-user-profile-id` header
- ✅ **Beta Message Threads** — `client.beta.messages.thread` (`BetaMessageThread`, `message-threads-2026-08-12`) with `append`, `update`, `fork`, `send`, `stream`, `open_stream`, replay recovery, and default `ToolRunner` integration
- ✅ **Browser & Computer Toolsets (`20260801`)** — `BrowserToolset20260801` / `ComputerToolset20260801` with typed action parsers (`BrowserToolUse` / `ComputerToolUse`), `toolset_name` propagation, and `BrowserStateContent`
- ✅ **Token Task Budgets** — `BetaTokenTaskBudget` for session-wide token caps via `output_config.task_budget`
- ✅ **Extended Tool Fields** — Beta `allowed_callers`, `defer_loading`, `input_examples`, `eager_input_streaming`
- ✅ **Effort Control** — Control output effort level via `output_config` (`low` / `medium` / `high` / `xhigh` / `max`)
- ✅ **Inference Geo** — Data residency control for inference requests
- ✅ **Structured Outputs** — Type-safe JSON responses and typed parsing helpers
- ✅ **Citations** — Document citations across all location variants (char, page, content block, web search result, search result) with streaming support
- ✅ **Beta Namespace** — `client.beta.messages`, `client.beta.user_profiles`, etc. matching Ruby SDK
- ✅ **Model Capabilities** — Richer Models API metadata (`lifecycle`, `line`, `deprecated_at`, `retires_at`, `capabilities` with `xhigh` effort, `between_tools` thinking, `server_tools`)
- ✅ **Stop Details Union** — Structured `refusal` stop details (with `fallback_credit_token` / `fallback_has_prefill_claim` / `recommended_model`) plus `GenericStopDetails` fallback for future variants
- ✅ Vision (image understanding)
- ✅ System prompts and output effort control (`OutputConfig#effort`)
- ✅ Message Batches API (create, list, retrieve, results, cancel, delete)
- ✅ Models API (list with `lifecycle` filter, retrieve)
- ✅ Auto-pagination helpers
- ✅ Enhanced streaming helpers (`text`, `tool_use_deltas`, `thinking`, `citations`, unknown SSE pass-through)
- ✅ **Comprehensive error handling** — Full HTTP status coverage (`400`, `401`, `403`, `404`, `408`, `409`, `412`, `413 ContentTooLargeError`, `422`, `429`, `431`, `499`, `500`, `501 HTTPNotImplementedError`, `503`, `504`, `529`), `ConfigurationError`, `api_message`/`error_type`/`error_code`/`details`, and 98-entry `(status, error_code)` subclass dispatch (`ERROR_CLASSES` / `Anthropic.build_api_error`) with automatic retries on 408/409/429/5xx/529
- ✅ Type-safe API with full compile-time checking
- ✅ Beta Files API (upload, download, delete)
- ✅ Token counting API
- ✅ Prompt caching with TTL control
- ✅ Managed Agents (agents / environments / sessions / deployments / deployment runs / vaults / secure webhooks)
- ✅ **Managed Agents Event Streaming** — `SessionEventStream` + `event_deltas:` opt-in + `accumulate_managed_agents_event` helper
- ✅ **x-stainless-helper Telemetry** — Single-sourced helper header with append semantics
- ✅ **Amazon Bedrock** — Runtime (`Bedrock::Client`, SigV4 + streaming) and Mantle (`Bedrock::MantleClient`); credentials via env, shared files, `aws login`, IAM Identity Center SSO, or IMDS
- ✅ **Alternate Providers** — AWS gateway (`AWS::Client`, Bearer/SigV4), Google Cloud gateway (`GoogleCloud::Client`, `/v1/` invoke + `claudeOrganization` routing), and Vertex AI (`Vertex::Client`, publisher-model API); `with_options` + `supports_message_threads?` across all 5 providers
- ✅ **Organization Admin API (GA + Beta)** — GA `client.organization` (`retrieve`, API keys, external keys, invites, users, workspaces, service accounts, federation, rate limits, compliance settings, RBAC groups/roles, spend limits effective/increase requests, enterprise analytics) plus Beta `client.beta.organization` extensions (`users.sign_out`, `spend_limits` CRUD, `analytics.usage`/`cost`, `plugins` & `plugin_marketplaces`, `telemetry_destinations`, `webhooks`, `claude_tag`)
- ✅ **Workspace Headers** — First-class `workspace_id:` on Messages, Sessions, Dreams, User Profiles, and Models; `APIError#workspace_id` reads the response header
- ✅ **Thinking Display Modes** — `ThinkingConfig#display` (`summarized` / `omitted` / `updates`, auto-attaching `thinking-display-updates-2026-08-18`)
- ✅ **Explicit Compaction** — `SummarizeCompaction` on beta messages / count-tokens / batch requests (auto-attaching `compact-2026-09-04`); signed blocks with `signature` + `tool_changes`; `ToolRunner#compact_before_next_turn`
- ✅ **Runner Tool Changes** — `ToolRunner#add_tools` / `#remove_tools` with `inline-tools-2026-09-15` auto-attached; local dispatch follows overrides immediately
- ✅ **MCP Tool-List Pinning** — `MCPToolListingContent` blocks; `MCPToolset#tools` pins listings (auto-attaching `mcp-client-2026-09-15`)
- ✅ **Input Transformations** — `Message#input_transformations` parsed from responses, with streaming `message_delta` replacement
- ✅ **Web-Fetch URL Sources** — `url_sources` scoping (all/none/only/except) on all web-fetch tool versions
- ✅ **User External Details** — `external_user_details` on profiles (auto-attaching `user-profiles-2026-09-04`)
- ✅ **Data-Residency Geos** — `BetaAllowedInferenceGeo`, `"unrestricted"` residency, create/update configs
- ✅ **Rate-Limit Groups** — Discriminated `group` union with model-group display names

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     anthropic-cr:
       github: amscotti/anthropic-cr
   ```

2. Run `shards install`

## Beta Status

Beta-only surfaces in this Crystal SDK were re-checked against the `2026-10-21` official Python (`2.8.0`), Ruby (`2.8.0`), and TypeScript (`1.8.0`) SDKs.

Now GA in `0.12.0`:
- **User Profiles API** via `client.user_profiles` (including `action_urls.create`, enforcement actions, and `cyber`/`efs` programs; `client.beta.user_profiles` remains for legacy `external_id` / `create_enrollment_url` under `user-profiles-2026-08-18` / `2026-09-04`)
- **Organization Admin API (core + RBAC + spend-limit effective/increase requests + analytics summaries)** via `client.organization`
- **Messages `speed`** (`"standard"` | `"fast"`), **Structured outputs** (`client.messages.parse` / `output_config.format`), **Prompt cache diagnostics**, **Basic container reuse** (`container: String`), and **Model lifecycle/capability metadata** (`client.models`)

Still beta upstream:
- **Beta Message Threads** via `client.beta.messages.thread` (`message-threads-2026-08-12`, default inside `client.beta.messages.tool_runner` when supported)
- **Files API** via `client.beta.files` and **Skills API** via `client.beta.skills`
- **Organization Admin Beta Extensions** via `client.beta.organization` (`users.sign_out`, `spend_limits` CRUD, `analytics.usage`/`cost` + legacy reports, `plugins` & `plugin_marketplaces`, `telemetry_destinations`, `webhooks`, `claude_tag`)
- **Advisor tool** (`advisor-tool-2026-03-01`) via `Anthropic::AdvisorTool`
- **Token task budgets** via `output_config.task_budget`
- **Server-side fallbacks** via `fallbacks:` (`server-side-fallback-2026-07-01`); client-side fallbacks via `Anthropic::BetaRefusalFallbackMiddleware` (`fallback-credit-2026-07-01`)
- **Dreams API** via `client.beta.dreams` (`dreaming-2026-04-21`; gated research preview)
- **MCP Tunnels API** via `client.beta.tunnels` (`mcp-tunnels-2026-06-22`; management needs WIF `workspace:manage_tunnels`)
- **Managed Agents API** via `client.beta.agents`, `client.beta.vaults`, `client.beta.sessions`, `client.beta.deployments`, `client.beta.deployment_runs`, `client.beta.environments`, `client.beta.memory_stores`, and secure webhook verification (`managed-agents-2026-04-01` / `agent-memory-2026-07-22`)
- **Context management** (`context_management`), **explicit compaction** (`SummarizeCompaction`, `compact-2026-09-04`), **MCP servers** (`mcp_servers`), **inline tool changes** (`inline-tools-2026-09-15`), and **skill-loading container configs** (`container: Anthropic::ContainerConfig`)
- Full release notes: [CHANGELOG.md](CHANGELOG.md) (`0.12.0`)

> **Note on progressive rollouts:** `task_budget`, the User Profiles API, the Advisor tool, and Managed Agents are being enabled progressively on Anthropic accounts. The bundled examples (`34_opus_48.cr`, `34_managed_agents.cr`, `35_advisor_tool.cr`, `36_user_profiles.cr`) handle the "not yet enabled" case gracefully.

## Quick Start

```crystal
require "anthropic-cr"

# Initialize the client (uses ANTHROPIC_API_KEY from environment)
client = Anthropic::Client.new

# Create a message
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5,
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
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 1024,
  messages: [{role: "user", content: "What is Crystal?"}]
)

puts message.text
puts "Used #{message.usage.input_tokens} input tokens"
```

### Streaming

Use `stream` for simple event-by-event handling:

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

Use `open_stream` when you want richer helpers like `text`, `collect_text`, and `final_message` while the stream is open:

```crystal
client.messages.open_stream(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "Write a haiku about programming"}]
) do |stream|
  print stream.collect_text
  final_message = stream.final_message
  puts "\nStop reason: #{final_message.try(&.stop_reason)}"
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
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
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

# Current Crystal helper lives under beta.messages
message = client.beta.messages.create(
  betas: [Anthropic::STRUCTURED_OUTPUT_BETA],
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
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
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
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
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
  max_tokens: 8192,
  thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 4000),
  messages: [{role: "user", content: "Solve this logic puzzle..."}]
)

# Response includes both thinking and final answer
message.content.each do |block|
  case block
  when Anthropic::ThinkingContent
    puts "Thinking: #{block.thinking}"
  when Anthropic::TextContent
    puts "Answer: #{block.text}"
  end
end
```

#### Adaptive Thinking (Opus 4.6+)

With Claude Opus 4.6, you can use adaptive thinking where the model decides how much to think:

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  thinking: Anthropic::ThinkingConfig.adaptive,
  messages: [{role: "user", content: "Explain quantum computing"}]
)
```

#### Effort Control

Control how much effort Claude puts into a response:

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_8,
  max_tokens: 16384,
  thinking: Anthropic::ThinkingConfig.adaptive,
  output_config: Anthropic::OutputConfig.new(effort: "xhigh"),
  messages: [{role: "user", content: "Write a detailed analysis..."}]
)
```

Effort levels: `"low"`, `"medium"`, `"high"`, `"xhigh"` (Opus 4.7+), `"max"`

#### Token Task Budgets (Beta)

Cap total token usage across contexts in a session via `output_config.task_budget`:

```crystal
budget = Anthropic::BetaTokenTaskBudget.new(total: 200_000)

message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_8,
  max_tokens: 4096,
  output_config: Anthropic::OutputConfig.new(effort: "xhigh", task_budget: budget),
  messages: [{role: "user", content: "Summarize the attached docs..."}]
)
```

#### Inference Geo

Control where your request is processed for data residency:

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_6,
  max_tokens: 16384,
  inference_geo: "us",
  messages: [{role: "user", content: "Hello!"}]
)
```

### Vision

```crystal
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
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
  model: Anthropic::Model::CLAUDE_SONNET_5_5,
  max_tokens: 2048,
  system: "You are a helpful coding assistant specializing in Crystal.",
  output_config: Anthropic::OutputConfig.new(effort: "high"),
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
model = client.models.retrieve(Anthropic::Model::CLAUDE_SONNET_4_6)
puts model.display_name  # => "Claude Sonnet 4.6"

if capabilities = model.capabilities
  puts capabilities.structured_outputs.supported?
  puts model.max_input_tokens
  puts model.max_tokens
end
```

### Tool Runner (Beta)

Automatic tool execution loop - no manual handling required:

```crystal
# Define tools
calculator = Anthropic.tool(...) { |input| calculate(input) }
time_tool = Anthropic.tool(...) { |input| Time.local.to_s }

# Create runner (in beta namespace, matching Ruby SDK)
runner = client.beta.messages.tool_runner(
  model: Anthropic::Model::CLAUDE_SONNET_4_6,
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

Mid-conversation, offer or withdraw tools and compact explicitly:

```crystal
runner.add_tools(notes_tool)   # tool_addition on the next request
runner.remove_tools("legacy")  # tool_removal on the next request
runner.compact_before_next_turn # server-side summary replaces the history
```

### Skills API (Beta)

Manage reusable skills that can be attached to containers for agentic workflows:

```crystal
# Create a skill by uploading files
skill = client.beta.skills.create(
  files: [
    Anthropic::FileUpload.new(
      io: File.open("skill/SKILL.md"),
      filename: "my-skill/SKILL.md",
      content_type: "text/markdown"
    ),
    Anthropic::FileUpload.new(
      io: File.open("skill/tool.py"),
      filename: "my-skill/tool.py",
      content_type: "text/x-python"
    ),
  ],
  display_name: "My Skill"
)

# List skills
skills = client.beta.skills.list(limit: 10)
skills.data.each { |s| puts "#{s.display_name} (#{s.id})" }

# Retrieve a skill
skill = client.beta.skills.retrieve("skill_abc123")

# Create a new version
client.beta.skills.versions.create(
  skill_id: skill.id,
  files: [
    Anthropic::FileUpload.from_path(
      "updated/tool.py",
      filename: "my-skill/tool.py"
    )
  ]
)

# List versions
versions = client.beta.skills.versions.list(skill_id: skill.id)
versions.data.each { |v| puts "Version #{v.name} (#{v.id}) from #{v.created_at}" }

# Delete (must delete all versions first)
versions.data.each do |v|
  client.beta.skills.versions.delete(skill_id: skill.id, version: v.id)
end
client.beta.skills.delete(skill.id)
```

**Note:** Each skill requires a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: my-skill
description: A brief description of what this skill does.
---

# My Skill

Detailed documentation about the skill...
```

### Dreams API (Beta)

Asynchronous memory-consolidation jobs that read a memory store + past sessions and write a **new** output store (input is never modified). Research preview — [request access](https://claude.com/form/claude-managed-agents). Docs: [Dreams](https://platform.claude.com/docs/en/managed-agents/dreams).

The SDK auto-attaches `dreaming-2026-04-21`. Without preview access the API returns **404**.

```crystal
dream = client.beta.dreams.create(
  inputs: [
    Anthropic::BetaDreamMemoryStoreInput.new("memstore_abc"),
    Anthropic::BetaDreamSessionsInput.new(["sesn_1"]),
  ],
  model: Anthropic::Model::CLAUDE_OPUS_4_8,
  instructions: "Consolidate durable facts for the next session.",
)
client.beta.dreams.retrieve(dream.id)
# also: list, archive, cancel
```

### MCP Tunnels API (Beta, research preview)

Private MCP hostnames so Claude can reach MCP servers inside your network (outbound-only stack: cloudflared + proxy). Research preview — [request access](https://claude.com/form/claude-managed-agents). Docs: [MCP tunnels](https://platform.claude.com/docs/en/agents-and-tools/mcp-tunnels/overview).

The SDK auto-attaches `mcp-tunnels-2026-06-22`. **Management** endpoints (create/list/archive/certificates/tokens) require a **Workload Identity Federation** bearer with scope `workspace:manage_tunnels` — standard `ANTHROPIC_API_KEY` values return **401**. Using a tunnel URL from Messages (`mcp_servers`) still uses a normal API key + the MCP client beta.

```crystal
# Client must use a WIF-exchanged token with workspace:manage_tunnels
tunnel = client.beta.tunnels.create(display_name: "prod-gateway")
token = client.beta.tunnels.reveal_token(tunnel.id)
cert = client.beta.tunnels.certificates.create(
  tunnel.id,
  ca_certificate_pem: File.read("ca.pem"),
)
# also: list, retrieve, archive; rotate_token
```

### Advisor Tool (Beta)

The advisor tool delegates sub-questions to a secondary model at runtime, useful for routing specialized checks (security review, math, etc.) without switching the primary conversation. The SDK automatically adds the `advisor-tool-2026-03-01` beta header when `AdvisorTool` is passed in `server_tools:`:

```crystal
advisor = Anthropic::AdvisorTool.new(
  model: Anthropic::Model::CLAUDE_OPUS_4_5,  # advisor model
  max_uses: 3,
  strict: true,
)

message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_OPUS_4_8,
  max_tokens: 2048,
  server_tools: [advisor] of Anthropic::ServerTool,
  messages: [{role: "user", content: "Review this payload for abuse patterns: ..."}]
)

message.content.each do |block|
  case block
  when Anthropic::AdvisorToolResultContent
    case inner = block.content
    when Anthropic::AdvisorResultContent         then puts "Advisor: #{inner.text}"
    when Anthropic::AdvisorRedactedResultContent then puts "Advisor (encrypted)"
    when Anthropic::AdvisorToolResultErrorContent then puts "Advisor error: #{inner.error_code}"
    end
  end
end
```

### User Profiles API (GA + Beta)

User profiles scope per-end-user state (memory, enforcement actions, program enrollments, etc.) to a specific end user of your application. Core CRUD, `action_urls`, and `delete` are GA on `client.user_profiles` (no beta header), while `client.beta.user_profiles` (`user-profiles-2026-08-18` / `2026-09-04`) retains legacy `external_id` and `create_enrollment_url` helpers:

```crystal
# Create a GA profile for your end user
profile = client.user_profiles.create(
  access_type: Anthropic::UserProfileAccessType::PASSTHROUGH,
  name: "Acme End User",
  external_user_details: Anthropic::UserProfileExternalUserDetails.new(reference_id: "user-123"),
  metadata: {"plan" => "pro"}
)

# Generate an action URL to hand to that user
action_url = client.user_profiles.action_urls.create(
  profile.id,
  action: Anthropic::UserProfileEnrollEndUserAction.new
)
puts action_url.url

# Scope a subsequent message to that profile (sends anthropic-user-profile-id header)
message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5_5,
  max_tokens: 512,
  user_profile_id: profile.id,
  messages: [{role: "user", content: "Welcome back!"}]
)

# List / retrieve / update / delete
client.user_profiles.list(limit: 20)
client.user_profiles.retrieve(profile.id)
client.user_profiles.update(profile.id, metadata: {"plan" => "enterprise"})
client.user_profiles.delete(profile.id)
```

### Beta Message Threads & Toolsets (Beta)

`BetaMessageThread` (`client.beta.messages.thread`, `message-threads-2026-08-12`) manages server-side thread continuation (omitting create-only `system`/`tools` on `continue`, adopting `container.id`, and recovering automatically with `cache_control` stripped when needed). `BrowserToolset20260801` and `ComputerToolset20260801` configure built-in browser/computer actions cleanly:

```crystal
thread = client.beta.messages.thread(
  model: Anthropic::Model::CLAUDE_SONNET_5_5,
  max_tokens: 1024,
  system: "Keep replies brief.",
  thinking: Anthropic::ThinkingConfig.between_tools,
  server_tools: [Anthropic::BrowserToolset20260801.new] of Anthropic::ServerTool,
)
reply = thread.send(Anthropic::MessageParam.user("Check https://crystal-lang.org"))
branch = thread.fork
```

### GA Organization Admin API (`client.organization`)

Core organization administration — `retrieve`, `api_keys`, `external_keys`, `invites`, `users`, `workspaces`, `service_accounts`, `federation`, `rate_limits`, `compliance_settings`, `rbac_groups`, `rbac_roles`, `spend_limits.effective`/`increase_requests`, and `analytics.summaries`/`users`/`apps`/`connectors`/`plugins`/`skills`/`artifacts` — is GA via `client.organization`. Beta-only extensions (`users.sign_out`, `spend_limits` CRUD, `analytics.usage`/`cost`, `plugins`, `plugin_marketplaces`, `telemetry_destinations`, `webhooks`, `claude_tag`) live under `client.beta.organization`.

### Server-Side Fallbacks (Beta)

When a model refuses a request for policy reasons, the server-side fallbacks feature lets the API automatically retry against a fallback model chain in a single round-trip. The SDK auto-attaches the `server-side-fallback-2026-07-01` beta when `fallbacks:` is set. Pass an explicit chain or the exact string `"default"` for the server-defined chain (other strings raise `ArgumentError`):

```crystal
message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 1024,
  fallbacks: [
    Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8),
  ],
  # or: fallbacks: "default",
  messages: [{role: "user", content: "..."}]
)

# If a fallback fired, the response carries a `fallback` content block at the
# model boundary and per-hop `usage.iterations`.
if fallback = message.content.find(&.is_a?(Anthropic::FallbackContent))
  fb = fallback.as(Anthropic::FallbackContent)
  puts "Fell back: #{fb.from.model} -> #{fb.to.model}"
end

# Object-form credit token on a client retry (auto-attaches fallback-credit-2026-07-01):
# message = client.beta.messages.create(
#   ...,
#   fallback_credit_token: Anthropic::FallbackCreditTokenParam.new(
#     token: "fct_...",
#     mode: "best_effort", # or "strict"
#   ),
# )
```

Primary beta constants track July 2026 (`SERVER_SIDE_FALLBACK_BETA`, `FALLBACK_CREDIT_BETA`). Pin June with `SERVER_SIDE_FALLBACK_BETA_2026_06_01` / `FALLBACK_CREDIT_BETA_2026_06_01` if needed. See [CHANGELOG.md](CHANGELOG.md) for the full 0.9.0 notes.

### Client-Side Refusal Fallback Middleware (Beta)

For API providers that don't support server-side fallbacks, `BetaRefusalFallbackMiddleware` retries refused requests down a client-side fallback chain (default beta `fallback-credit-2026-07-01`). It is mutually exclusive with the `fallbacks:` request param:

```crystal
client = Anthropic::Client.new(
  middleware: [
    Anthropic::BetaRefusalFallbackMiddleware.new(
      [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
    ),
  ],
)

message = client.beta.messages.create(
  model: Anthropic::Model::CLAUDE_FABLE_5,
  max_tokens: 1024,
  messages: [{role: "user", content: "..."}],
)
```

### HTTP Middleware

Inspect, rewrite, or short-circuit requests and responses around the SDK's terminal HTTP send. The chain runs once per attempt inside the retry loop:

```crystal
class LoggingMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    puts "-> #{request.method} #{request.path}"
    response = nxt.call(request)
    puts "<- HTTP #{response.status}"
    response
  end
end

client = Anthropic::Client.new(middleware: [LoggingMiddleware.new])

# Inject a custom request header
class AddHeaderMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    new_headers = request.headers.dup
    new_headers["x-custom"] = "injected"
    nxt.call(request.with(headers: new_headers))
  end
end
```

`nxt.call` returns an `APIResponse` for **every** status (4xx/5xx do not raise inside the chain); connection errors do raise. Middleware may call `nxt` multiple times to implement custom retry logic. **Limitation:** only buffered JSON requests run through the chain — streaming, raw downloads, and multipart uploads bypass middleware.

### Scoped Options & HTTPS Proxy

`with_options` returns a copy of the client with per-request overrides (the equivalent of upstream `requestOptions`), without mutating the original:

```crystal
scoped = client.with_options(
  timeout: 30.seconds,
  max_retries: 0,
  extra_headers: {"X-Tenant" => "acme"},
  api_key: "sk-ant-tenant", # per-tenant credentials, base_url, proxy, middleware
)
scoped.messages.create(model: "...", max_tokens: 64, messages: [...])
```

HTTPS destinations can tunnel through an explicit `proxy:` URL or the `HTTPS_PROXY` / `https_proxy` environment (with `NO_PROXY` / `no_proxy` bypass, including `*` wildcards and leading-dot domains). Proxy credentials in the URL become a `Proxy-Authorization` header. Only `http://` proxies are supported, and plain-HTTP base URLs bypass the proxy:

```crystal
client = Anthropic::Client.new(proxy: "http://user:pass@proxy.example.com:8080")
```

## Model Constants

```crystal
# Rolling aliases — point at the current default precise models
Anthropic::Model::CLAUDE_SONNET       # => "claude-sonnet-5"
Anthropic::Model::CLAUDE_FABLE        # => "claude-fable-5"
Anthropic::Model::CLAUDE_OPUS         # => "claude-opus-5"
Anthropic::Model::CLAUDE_OPUS_5       # => "claude-opus-5"
Anthropic::Model::CLAUDE_HAIKU        # => "claude-haiku-4-5"

# Latest models (5.5 / 5.2 & July 2026 generations)
Anthropic::Model::CLAUDE_SONNET_5_5   # Claude Sonnet 5.5
Anthropic::Model::CLAUDE_HAIKU_5_5    # Claude Haiku 5.5
Anthropic::Model::CLAUDE_FABLE_5_2    # Claude Fable 5.2
Anthropic::Model::CLAUDE_MYTHOS_5_2   # Claude Mythos 5.2
Anthropic::Model::CLAUDE_OPUS_5_5     # Claude Opus 5.5
Anthropic::Model::CLAUDE_SONNET_5     # High-performance model for coding and agents
Anthropic::Model::CLAUDE_FABLE_5      # Next-gen intelligence for the hardest knowledge work
Anthropic::Model::CLAUDE_MYTHOS_5     # Most capable for cybersecurity & biology research

# Claude 4.x models
Anthropic::Model::CLAUDE_OPUS_4_8     # Frontier intelligence (May 2026)
Anthropic::Model::CLAUDE_OPUS_4_7     # Frontier intelligence (April 2026)
Anthropic::Model::CLAUDE_OPUS_4_6     # Opus 4.6
Anthropic::Model::CLAUDE_OPUS_4_5     # Opus 4.5
Anthropic::Model::CLAUDE_SONNET_4_6   # Sonnet 4.6
Anthropic::Model::CLAUDE_HAIKU_4_5    # Haiku 4.5

# Deprecated
Anthropic::Model::CLAUDE_SONNET_4_5   # EOL November 30, 2026
Anthropic::Model::CLAUDE_OPUS_4_1     # EOL August 5, 2026
Anthropic::Model::CLAUDE_SONNET_4     # EOL June 15, 2026

# Or use shorthands
Anthropic.model_name(:sonnet)      # => "claude-sonnet-5"
Anthropic.model_name(:sonnet_5_5)  # => "claude-sonnet-5-5"
Anthropic.model_name(:haiku_5_5)   # => "claude-haiku-5-5"
Anthropic.model_name(:fable_5_2)   # => "claude-fable-5-2"
Anthropic.model_name(:mythos_5_2)  # => "claude-mythos-5-2"
Anthropic.model_name(:fable)       # => "claude-fable-5"
Anthropic.model_name(:mythos)      # => "claude-mythos-5"
Anthropic.model_name(:opus)        # => "claude-opus-5"
Anthropic.model_name(:opus_5_5)    # => "claude-opus-5-5"
Anthropic.model_name(:opus_4_8)    # => "claude-opus-4-8"
Anthropic.model_name(:opus_4_7)    # => "claude-opus-4-7"
Anthropic.model_name(:haiku)       # => "claude-haiku-4-5-20251001"
```

## Examples

See the [examples/](./examples/) directory for complete working examples:

**Phase 1 (Core API):**
- `01_basic_message.cr` - Simple message creation
- `02_streaming.cr` - Real-time streaming responses
- `03_tool_use.cr` - Function calling with tools
- `04_vision.cr` - Image understanding
- `05_system_prompt.cr` - System prompts and output effort (`OutputConfig`)
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
- `24_advanced_streaming.cr` - Advanced streaming patterns with `open_stream`
- `25_ollama.cr` - Ollama local model integration
- `26_opus_46.cr` - Claude Opus 4.6 (adaptive thinking, effort, inference geo)
- `27_agent_tools.cr` - Agent tools (bash, text editor, computer use, web fetch, memory)
- `28_advanced_features.cr` - Redacted thinking, cache_control on tools, metadata, extended tool fields, CompactionDelta
- `29_beta_params.cr` - MCP servers, container/skills, tool search tools, beta parameters
- `30_skills_api.cr` - Skills API (CRUD, versions, container integration)
- `31_open_stream.cr` - Richer block-scoped streaming with `open_stream`
- `32_model_capabilities.cr` - Inspect richer Models API metadata and capability support
- `33_web_fetch_cache_control.cr` - Use `WebFetchTool20260309` with `use_cache: false`
- `34_opus_48.cr` - Claude Opus 4.8 with `xhigh` effort and `BetaTokenTaskBudget`
- `34_managed_agents.cr` - Stateful Managed Agents API (environments, memory stores, agents, vaults, webhooks)
- `35_advisor_tool.cr` - Advisor tool (`advisor_20260301`) with typed result-block handling
- `36_user_profiles.cr` - User Profiles API create / list / enrollment and scoped messaging
- `37_sonnet_5_fable_5.cr` - Claude Sonnet 5 / Fable 5 / Mythos 5 models
- `38_new_tools.cr` - New server tools (`code_execution_20260521`, `web_fetch_20260318`, `web_search_20260318`)
- `39_fallbacks.cr` - Server-side refusal fallbacks (`fallbacks:` request param)
- `40_middleware.cr` - HTTP middleware (logging + header injection)
- `41_refusal_fallback_middleware.cr` - Client-side `BetaRefusalFallbackMiddleware`
- `42_opus_5.cr` - Claude Opus 5 model smoke test
- `43_dreams.cr` - Dreams API (memory consolidation, beta)
- `44_tunnels.cr` - MCP Tunnels + certificates (research preview)
- `45_bedrock.cr` - Amazon Bedrock Runtime (`Anthropic::Bedrock::Client`, SigV4)
- `46_bedrock_mantle.cr` - Bedrock Mantle (`Anthropic::Bedrock::MantleClient`)
- `48_organization.cr` - Organization Admin API (`client.organization` GA + beta extensions)
- `49_providers.cr` - AWS / Google Cloud / Vertex provider clients
- `50_compaction_and_tools.cr` - Explicit compaction + runner tool changes
- `51_threads_toolsets_and_admin.cr` - 5.5/5.2 models, `BetaMessageThread`, browser/computer toolsets, GA `user_profiles` + `organization`

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
crystal build --no-codegen src/anthropic-cr.cr
```


## Contributing

1. Fork it (<https://github.com/amscotti/anthropic-cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Anthony Scotti](https://github.com/amscotti) - creator and maintainer
