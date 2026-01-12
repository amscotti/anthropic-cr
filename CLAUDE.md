# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An unofficial Anthropic SDK for Crystal providing full API coverage: Messages, Batches, Models, Files, streaming, tool use, structured outputs, and more. Aims for parity with official SDKs (Python, TypeScript, Ruby) while leveraging Crystal's type system.

## Development Commands

```bash
# Install dependencies
shards install

# Run all tests
crystal spec

# Run a single test file
crystal spec spec/anthropic/resources/messages_spec.cr

# Type check without building
crystal build --no-codegen src/anthropic.cr

# Format code
crystal tool format

# Run linter
./bin/ameba

# Run example (requires ANTHROPIC_API_KEY in .env or environment)
crystal run examples/01_basic_message.cr
```

## Architecture

### Module Structure

```
src/anthropic/
├── client.cr              # HTTP client with retry logic
├── errors.cr              # Error hierarchy (APIError, RateLimitError, etc.)
├── schema.cr              # Schema DSL for tool definitions
├── models/                # Type definitions
│   ├── content.cr         # Content block types (Text, Image, Tool, etc.)
│   ├── message.cr         # Message and MessageParam
│   ├── params.cr          # Request parameter structs
│   └── ...
├── resources/             # API resources
│   ├── messages.cr        # Messages API
│   ├── batches.cr         # Batches API
│   ├── models.cr          # Models API
│   ├── files.cr           # Files API (beta)
│   └── beta.cr            # Beta namespace
├── streaming/             # SSE streaming
│   ├── events.cr          # Event types
│   └── stream.cr          # MessageStream with iterators
└── tools/                 # Tool system
    ├── tool.cr            # Tool base class, InlineTool, TypedTool
    ├── tool_choice.cr     # ToolChoice types
    ├── server_tools.cr    # Server-side tools (WebSearch, etc.)
    └── runner.cr          # Automatic tool execution loop
```

### Key Design Patterns

**Resource Chaining:** APIs accessed via `client.messages.create(...)`, `client.models.list()`, `client.beta.files.upload(...)`

**Block-based Streaming:** `stream(...) { |event| }` yields events directly. Iterator-based streaming (returning a `MessageStream` object) is not yet implemented due to HTTP connection lifecycle limitations.

**Flexible Message Input:** NamedTuples for simple use `{role: "user", content: "Hi"}` or typed structs `MessageParam.new(...)` for complex content

**Tool System:**
- `Anthropic.tool(name:, schema:, ...) { |input| }` - Schema DSL tools
- `Anthropic.tool(name:, input: MyStruct) { |input| }` - TypedTool with struct input
- `client.beta.messages.tool_runner(...)` - Automatic tool execution loop (in beta namespace, matching Ruby SDK)

**Server Tools:** Unlike Ruby SDK which passes all tools in a single `tools` array, Crystal uses separate `tools` and `server_tools` parameters for better type safety and automatic beta header management.

**Error Handling:** All API errors include `status`, `body`, and `headers` properties for debugging.

### Testing

Uses WebMock for HTTP stubbing. Tests don't hit the real API.

```crystal
# Stub a request and capture what was sent
capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
client.messages.create(...)
body = JSON.parse(capture.body.not_nil!)
```

Fixtures in `spec/fixtures/responses.cr` provide standard API responses.

### Key Type Patterns

- All API types use `JSON::Serializable`
- Use `@[JSON::Field(key: "snake_case")]` for API field mapping
- Content blocks use discriminated union via `ContentBlockConverter`
- Prefer structs for data, classes for resources with state
