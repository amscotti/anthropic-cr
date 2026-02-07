# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An unofficial Anthropic SDK for Crystal providing full API coverage: Messages, Batches, Models, Files, streaming, tool use, structured outputs, and more. Aims for parity with official SDKs (Python, TypeScript, Ruby) while leveraging Crystal's type system. Top-level module is `Anthropic` (not `Anthropic::CR`).

## Development Commands

```bash
# Install dependencies
shards install

# Run all tests
crystal spec

# Run a single test file
crystal spec spec/anthropic/resources/messages_spec.cr

# Type check without building
crystal build --no-codegen src/anthropic-cr.cr

# Format code
crystal tool format

# Run linter
./bin/ameba

# Run example (requires ANTHROPIC_API_KEY in .env or environment)
crystal run examples/01_basic_message.cr
```

## Architecture

### Source Layout

All source is under `src/anthropic-cr/` (not `src/anthropic/`). Entry point is `src/anthropic-cr.cr`.

```
src/anthropic-cr/
├── client.cr              # HTTP client with retry logic, exponential backoff
├── errors.cr              # Error hierarchy (APIError, RateLimitError, etc.)
├── schema.cr              # Schema DSL for tool definitions and output schemas
├── models/                # Type definitions (content.cr, message.cr, params.cr, usage.cr)
├── resources/             # API resources (messages.cr, batches.cr, models.cr, files.cr, beta.cr, skills.cr)
├── streaming/             # SSE streaming (events.cr, stream.cr)
└── tools/                 # Tool system (tool.cr, tool_choice.cr, server_tools.cr, runner.cr)
```

### Key Design Patterns

**Resource Chaining:** Client has no API methods directly. All via resources: `client.messages.create(...)`, `client.models.list()`, `client.beta.messages.create(...)`. Each resource class holds a reference to the client and delegates HTTP.

**Beta Namespace:** `Beta` is a wrapper class (not a separate client). It provides `BetaMessages`, `BetaFiles`, `BetaSkills` — specialized resource classes that accept explicit `betas` parameter for features requiring beta headers.

**Block-based Streaming:** `stream(...) { |event| }` yields events directly. No iterator-based streaming due to HTTP connection lifecycle limitations.

**Flexible Message Input:** NamedTuples for simple use `{role: "user", content: "Hi"}` or typed structs `MessageParam.new(...)` for complex content. Both accepted, converted internally.

**Tool System — Two Distinct Types:**
- **User-defined tools** (`tools` parameter): `InlineTool` (schema DSL) and `TypedTool(T)` (struct input). Both extend abstract `Tool` class, implement `#call(input : JSON::Any) : String`, and convert to `ToolDefinition` for API.
- **Server-side tools** (`server_tools` parameter): `WebSearchTool`, `BashTool`, `TextEditorTool`, `ComputerUseTool`, etc. Structs that serialize directly to API format. No `#call` method (executed server-side). Beta headers auto-managed in `Messages#build_beta_headers`.
- Unlike Ruby SDK (single `tools` array), Crystal uses separate parameters for type safety.

**ContentBlockConverter (Discriminated Union):** In `models/content.cr`, this converter dispatches JSON to the correct struct based on the `"type"` field. The `ContentBlock` alias is a union of all possible content types (`TextContent | ImageContent | ToolUseContent | ThinkingContent | ServerToolUseContent | ...`). Message structs annotate content arrays with `@[JSON::Field(converter: Anthropic::ContentBlockArrayConverter)]`.

**Error Handling:** All API errors include `status`, `body`, and `headers` properties.

### Testing

Uses WebMock for HTTP stubbing. Tests never hit the real API.

```crystal
# Stub a request and capture what was sent
capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
client.messages.create(...)
body = JSON.parse(capture.body.not_nil!)
```

`stub_and_capture` is defined in `spec/spec_helper.cr` — returns a `RequestCapture` object with `.body`, `.headers`, `.path`, `.method` for assertion. Fixtures in `spec/fixtures/responses.cr` provide standard API response strings as constants (e.g., `MESSAGE_BASIC`, `MESSAGE_WITH_TOOL_USE`).

### Key Type Patterns

- All API types use `JSON::Serializable`
- Use `@[JSON::Field(key: "snake_case")]` for API field mapping
- Prefer structs for data, classes for resources with state
- `TypedTool` uses the `json-schema` shard to auto-generate schemas from structs

### Code Style

- 2-space indentation (enforced by `.editorconfig`)
- Ameba linter: max cyclomatic complexity 15, excludes `lib/` and relaxes rules for `spec/` and `examples/`
