# Changelog

All notable changes to `anthropic-cr` are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] — 2026-04-18

Tracks the Opus 4.7 / April 2026 release of the official Python (0.96.0),
Ruby (1.35.0), and TypeScript SDKs.

### Added — Models

- `Anthropic::Model::CLAUDE_OPUS_4_7` — frontier intelligence for long-running
  agents and coding. `CLAUDE_OPUS` rolling alias now resolves here.
- `Anthropic::Model::CLAUDE_MYTHOS_PREVIEW` — preview class of intelligence
  strongest in coding and cybersecurity.
- `:opus_4_7` and `:mythos` shorthands on `Anthropic.model_name`; `:opus` now
  resolves to `claude-opus-4-7`.
- `EffortCapability#xhigh` for Opus 4.7+ effort level.

### Added — Resources

- `client.beta.user_profiles` — full CRUD API for per-end-user profiles plus
  enrollment URLs. Types: `BetaUserProfile`, `BetaUserProfileTrustGrant`,
  `BetaUserProfileEnrollmentURL`, `BetaUserProfileListResponse`. Automatically
  adds the `user-profiles-2026-03-24` beta header.
- `user_profile_id:` parameter on `client.beta.messages.create` / `stream` /
  `open_stream` / `count_tokens`. Auto-adds the user-profiles beta header.

### Added — Tools & Content Blocks

- `Anthropic::AdvisorTool` (type `advisor_20260301`) — delegate sub-questions
  to a secondary advisor model. Automatically adds the
  `advisor-tool-2026-03-01` beta header when passed in `server_tools:`.
- `AdvisorToolResultContent` block with discriminated-union `content` field
  (`AdvisorResultContent` | `AdvisorRedactedResultContent` |
  `AdvisorToolResultErrorContent`) via `AdvisorToolResultValueConverter`.
- Previously-missing tool versions: `CodeExecutionTool20250522`,
  `TextEditorTool20250124`, `TextEditorTool20250429`.

### Added — Data Types

- `Anthropic::BetaTokenTaskBudget` — session-wide token cap. Wired through
  `OutputConfig#task_budget`.
- Citation location union (`CitationRef`): `Citation` (char_location),
  `CitationPageLocation`, `CitationContentBlockLocation`,
  `CitationWebSearchResultLocation`, `CitationSearchResultLocation`. Parsed
  via `CitationConverter` / `CitationArrayConverter`.
- `StopDetails` union of `RefusalStopDetails | GenericStopDetails` with
  `StopDetailsConverter`. New `Message#refusal?` and `Message#refusal_stop_details`
  convenience methods.
- `encrypted_content` field on `CompactionContent` and `CompactionDelta` for
  confidential compaction summaries.

### Added — Errors

- `PayloadTooLargeError` (HTTP 413).
- `GatewayTimeoutError` (HTTP 504).
- `OverloadedError` (HTTP 529).
- `APIError#error_type` — populated from the server's `error.type` envelope
  (e.g., `"invalid_request_error"`, `"overloaded_error"`).
- `MessageStream#each` now raises the appropriate typed `APIError` subclass
  when the stream contains an SSE `error` event (overloaded, rate limit,
  timeouts, etc.).
- Retry list expanded to include 529.
- `Client#handle_error` tolerates empty / non-JSON error bodies gracefully.

### Added — Beta Header Constants

`ADVISOR_TOOL_BETA`, `USER_PROFILES_BETA`, `PDFS_BETA`, `OUTPUT_128K_BETA`,
`OUTPUT_300K_BETA`, `MCP_CLIENT_2025_04_04_BETA`, `DEV_FULL_THINKING_BETA`,
`INTERLEAVED_THINKING_BETA`, `CONTEXT_1M_BETA`,
`MODEL_CONTEXT_WINDOW_EXCEEDED_BETA`, `FAST_MODE_BETA`.

### Added — Examples

- `examples/34_opus_47.cr` — Opus 4.7 + `xhigh` effort + `BetaTokenTaskBudget`.
- `examples/35_advisor_tool.cr` — Advisor tool with typed result-block handling.
- `examples/36_user_profiles.cr` — User Profiles API CRUD and scoped messaging.

### Added — Tests

49 new specs in `spec/anthropic/parity_updates_spec.cr` covering models,
citation variants, stop-details union, advisor tool + result blocks, tool
version variants, beta constants, task budget, `user_profile_id` wiring,
User Profiles resource, 413/504/529 errors + `error_type`, empty-body
tolerance, and SSE error raising. Total suite: 458 examples, 0 failures.

### Changed

- `CLAUDE_OPUS` rolling alias repointed from `claude-opus-4-6` to
  `claude-opus-4-7`.
- `:opus` shorthand now resolves to `claude-opus-4-7`.
- `Message#stop_details` is now typed as `StopDetails?` (union) instead of
  `RefusalStopDetails?`. Use the new `Message#refusal_stop_details` accessor
  or pattern-match on the union to migrate.
- `CitationsDelta#citation` now returns `LegacyCitationData?` — `nil` for
  non-char-location citation variants. Raw payload accessible via
  `citation_data` / `citation_type` for all variants.
- Deprecation notes added on `CLAUDE_SONNET_4`, `CLAUDE_OPUS_4`, and
  `CLAUDE_OPUS_4_1` (EOL June 15, 2026).

### Migration Notes

The only potentially breaking change is the `stop_details` type widening:

```crystal
# Before (0.5.0)
if details = message.stop_details
  puts details.category
end

# After (0.6.0) — option 1: convenience accessor
if details = message.refusal_stop_details
  puts details.category
end

# After (0.6.0) — option 2: pattern match
case details = message.stop_details
when Anthropic::RefusalStopDetails
  puts details.category
when Anthropic::GenericStopDetails
  puts "Unknown variant: #{details.type}"
end
```

---

## [0.5.0] — 2026-02-17

- Claude Opus 4.6, adaptive thinking, Skills API, `open_stream`, structured
  outputs, Models API capability metadata, `context_management` beta,
  compaction streaming delta.
