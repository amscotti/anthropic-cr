# AGENTS.md

Guidance for agentic coding tools working in this repository.

## Scope
- Applies to the repository root at `/Users/ascotti/Documents/code/anthropic-cr`.
- If a deeper nested `AGENTS.md` is added, prefer the more specific file for files under that subtree.
- No Cursor or Copilot rule files were found: `.cursor/rules/**`, `.cursorrules`, `.github/copilot-instructions.md`.
- If any of those files appear later, follow them alongside this file.

## Project Snapshot
- Unofficial Anthropic SDK for Crystal with broad API coverage.
- Crystal version target: `>= 1.18.2`.
- Top-level module is `Anthropic`, not `Anthropic::CR`.
- Entry point is `src/anthropic-cr.cr`.
- Main source directory is `src/anthropic-cr/`, not `src/anthropic/`.
- Runtime dependency is intentionally small; `json-schema` is the main non-stdlib shard.
- Development dependencies include `webmock`, `vcr`, `ameba`, and `dotenv`.
- Preserve parity with official Anthropic SDKs when it fits Crystal's type system.

## Build, Lint, and Test Commands
```bash
# Install dependencies
shards install

# Run the full spec suite
crystal spec

# Run a single spec file
crystal spec spec/anthropic/resources/messages_spec.cr

# Run a single example/spec by line number
crystal spec spec/anthropic/resources/messages_spec.cr:12

# Type-check / build without code generation
crystal build --no-codegen src/anthropic-cr.cr

# Auto-format Crystal files
crystal tool format

# Check formatting without rewriting files
crystal tool format --check

# Run the linter
./bin/ameba

# Run an example (needs ANTHROPIC_API_KEY in env or .env)
crystal run examples/01_basic_message.cr
```
- Prefer single-file specs while iterating on a change.
- After API or type changes, run `crystal build --no-codegen src/anthropic-cr.cr` even if specs pass.
- Before handing off a substantive change, run format, lint, affected specs, and the no-codegen build.
- CI in `.github/workflows/ci.yml` runs four jobs: format, lint, test, and build.

## Repository Layout
- `src/anthropic-cr.cr`: requires and exposes the public library surface.
- `src/anthropic-cr/client.cr`: HTTP client, retries, headers, timeouts, uploads.
- `src/anthropic-cr/resources/`: stateful API resources such as `Messages`, `Models`, `Files`, `Batches`, and beta wrappers.
- `src/anthropic-cr/models/`: JSON-serializable value types, enums, unions, and converters.
- `src/anthropic-cr/streaming/`: SSE event types and stream parsing.
- `src/anthropic-cr/tools/`: inline tools, typed tools, server tools, tool runner, tool choice.
- `spec/`: specs, fixtures, and shared test helpers.
- `examples/`: public API examples; keep them accurate and runnable.

## Core Architecture Rules
- Do not add API calls directly on `Client`; use resource accessors like `client.messages.create`.
- `Beta` is a wrapper namespace, not a second client implementation.
- Keep streaming block-based: `stream(...) do |event| ... end`.
- Keep `tools:` and `server_tools:` separate; do not merge them into one array.
- Beta-only behavior should flow through `client.beta...` or centralized beta-header helpers.
- Preserve the public module name `Anthropic` everywhere.

## Require / Import Conventions
- Crystal uses `require`; do not introduce JS/Ruby-style import patterns.
- Prefer standard library and shard requires first, then local relative requires.
- Group local requires by subsystem when a file loads many dependencies.
- In `src/anthropic-cr.cr`, keep the dependency order intentional; `client.cr` stays last because it depends on earlier types.
- In specs, require `spec`, stubbing libraries, then `../src/anthropic-cr`, then local fixtures/helpers.

## Types and Data Modeling
- Use `struct` for API data and other value objects.
- Use `class` for stateful resources or wrappers that hold a `Client` reference.
- Public API models generally `include JSON::Serializable`.
- Prefer explicit typed getters and ivars over loose hashes.
- Use `@[JSON::Field(...)]` for API key mapping, converters, or null-emission behavior.
- Use union types only when the API genuinely accepts multiple shapes.
- Keep return types explicit on public methods.
- Add small convenience constructors when they improve clarity for common cases.

## Naming, Formatting, and Style
- File names: `snake_case`; types/modules: `CamelCase`; constants: `ALL_CAPS`; methods/variables: `snake_case`.
- Predicate methods end with `?`; model constants belong under `Anthropic::Model`.
- Keep Anthropic API terminology unless there is a strong Crystal-idiomatic reason to rename it.
- Use 2-space indentation; `.editorconfig` enforces LF endings, trailing-whitespace trimming, and final newlines.
- Run `crystal tool format` after editing Crystal files.
- Multi-line parameter lists should align cleanly and keep trailing commas.
- Prefer small, composable helpers over deeply branched methods.
- Add comments for protocol quirks or non-obvious intent, not to restate the code.
- Public APIs benefit from short doc comments and minimal runnable examples when behavior is non-obvious.

## Resource and API Design
- Resource classes should delegate HTTP work through `@client.get`, `@client.post`, `@client.delete`, or stream helpers.
- Keep request/response shaping close to the resource method that owns it.
- Reuse existing parameter structs before introducing ad hoc JSON building.
- Mirror existing public method signatures and prefer explicit keyword arguments.

## Error Handling
- Use the typed exception hierarchy from `src/anthropic-cr/errors.cr`.
- Rescue specific subclasses before rescuing `Anthropic::APIError`.
- Preserve `status`, `body`, and `headers` when raising API failures.
- Network issues should surface as `APIConnectionError` or `APITimeoutError`.
- Use `ArgumentError` for invalid local input detected before a request is made.
- Do not swallow parse or transport failures silently unless returning `nil` is an established API pattern.

## HTTP and Retry Behavior
- Keep retry and timeout logic centralized in `Client`.
- Respect server-provided retry headers and existing exponential backoff.
- Do not add custom retry loops in resource classes.
- Keep default header composition and beta header composition centralized.

## Testing Guidance
- Specs use WebMock; do not hit the real Anthropic API in tests.
- Reuse `stub_and_capture` from `spec/spec_helper.cr` to inspect request bodies, paths, methods, and headers.
- Add reusable response bodies to `spec/fixtures/responses.cr` when introducing new API behavior.
- Mirror source layout when naming new spec files.
- Fast path for one file: `crystal spec spec/anthropic/resources/messages_spec.cr`.
- If you need one example, use `crystal spec path/to/spec.cr:LINE`.
- `not_nil!` is acceptable in specs and is explicitly allowed by Ameba there.

## Lint and Complexity Expectations
- Ameba lints `**/*.cr` and excludes `lib/`.
- Cyclomatic complexity target is 15 or lower outside excluded directories.
- Avoid shadowing, unused arguments, redundant conditions, and identical branches.
- Examples may be slightly more permissive, but library code should stay strict.

## Content, Tools, and Beta Gotchas
- `ContentBlock` parsing depends on `ContentBlockArrayConverter`; update the union and converter together.
- User-defined tools and server tools are distinct abstractions with different execution paths.
- When adding a server tool, connect any required beta header in message header-building logic.
- Prefer existing beta constants over hardcoded header strings.
- Preserve block-based streaming semantics; do not convert streaming APIs into lazy iterators.

## Public API Compatibility
- Avoid unnecessary breaking changes to public method signatures.
- Prefer additive keyword args or overloads over replacing existing call patterns.
- If you change public behavior, update specs and at least one example or doc snippet.
- Keep examples aligned with the actual public API surface.

## Before You Finish
- Format: `crystal tool format`
- Lint: `./bin/ameba`
- Test: `crystal spec` or at least the affected spec file
- Type-check: `crystal build --no-codegen src/anthropic-cr.cr`
- Call out any command you could not run and why
