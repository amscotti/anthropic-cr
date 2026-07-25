# Changelog

All notable changes to `anthropic-cr` are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] — 2026-07-24

Tracks the late-July 2026 release of the official Python (0.120.0), Ruby (1.59.0), and TypeScript (0.115.0) SDKs (OpenAPI 131 endpoints).

### Added — Models

- `Anthropic::Model::CLAUDE_OPUS_5` (`claude-opus-5`) — powerful intelligence for long-running agents and coding.
- `:opus_5` shorthand on `Anthropic.model_name`.

### Added — Dreams API (beta)

- `client.beta.dreams` — memory-consolidation jobs: `create`, `retrieve`, `list`, `archive`, `cancel`.
- Types: `BetaDream`, inputs (`BetaDreamMemoryStoreInput` / `BetaDreamSessionsInput`), model config, status, usage, list page.
- Beta constant `DREAMING_BETA` (`dreaming-2026-04-21`); Dreams calls auto-attach **both** `MANAGED_AGENTS_BETA` and `DREAMING_BETA` (official requirement). Research-preview access is separately gated (404 without it).
- Example: `examples/43_dreams.cr`.

### Added — MCP Tunnels API (beta, research preview)

- `client.beta.tunnels` — `create`, `retrieve`, `list`, `archive`, `reveal_token`, `rotate_token`.
- Nested `client.beta.tunnels.certificates` — `create`, `retrieve`, `list`, `archive`.
- Types: `BetaTunnel`, `BetaTunnelToken`, `BetaTunnelCertificate`.
- Beta constant `MCP_TUNNELS_BETA` (`mcp-tunnels-2026-06-22`), auto-attached on tunnels + certificates.
- Management endpoints require WIF with `workspace:manage_tunnels` (standard API keys return 401). Using tunnel URLs from Messages is separate.
- Example: `examples/44_tunnels.cr`.

### Added — Fallbacks expansions

- `fallbacks: "default"` requests the server-defined default fallback chain (in addition to an explicit `Array(FallbackParam)`). Only the exact string `"default"` is accepted; other strings raise.
- Object-form `fallback_credit_token: FallbackCreditTokenParam.new(token:, mode: "strict" | "best_effort")` (union with bare `String`).
- Response `Usage#fallback_credit` (`FallbackCreditUsage` with `redeemed` / `not_applied` status) and `Usage#speed` (`"standard"` / `"fast"`); same fields on streaming `DeltaUsage` where applicable.
- Alias `FallbacksParam` / `FallbackCreditToken` + converters.

### Added — Tool addition / removal

- Request content blocks `ToolAdditionContent` (`tool_addition`) and `ToolRemovalContent` (`tool_removal`) with tool-change references (`tool_reference`, `mcp_tool_reference`, `mcp_toolset_reference`).
- `MidConversationSystemContent#content` expanded to `Array(MidConversationSystemBlock)` = text | tool_addition | tool_removal.
- `Anthropic::ToolDispatch` folds mid-conversation tool_addition/removal (including nested under `mid_conv_system`) into the tool runner’s available tool set.

### Added — Managed Agents

- `BetaManagedAgentsModelConfig` with optional `effort` (bare string or `{type: "high"}` objects via `BetaManagedAgentsEffort`) and `speed` (`"standard"` / `"fast"`).
- `client.beta.agents.create` / `update` accept model as string, symbol, or model config object.
- Session create accepts `initial_events:` (e.g. `user.message` / `user.define_outcome`).
- Thread event stream accepts `event_deltas:` (same as session-level event stream).

### Added — Docs / polish

- Refusal category docs include `general_harms`; `stop_reason` docs include `model_context_window_exceeded`.
- Webhook event type constants for `environment.*` and `memory_store.*`.
- Opt-in beta constant `THINKING_TOKEN_COUNT_BETA` (`thinking-token-count-2026-05-13`) — not auto-attached.
- Examples: `42_opus_5.cr`, `43_dreams.cr`, `44_tunnels.cr`.

### Changed (breaking)

- **`CLAUDE_OPUS` / `:opus` rolling alias** now resolves to `claude-opus-5` (was `claude-opus-4-8`). Pin with `CLAUDE_OPUS_4_8` / `:opus_4_8` if you need 4.8.
- **Primary fallback beta constants** now track July 2026:
  - `SERVER_SIDE_FALLBACK_BETA` → `server-side-fallback-2026-07-01` (pin June with `SERVER_SIDE_FALLBACK_BETA_2026_06_01`)
  - `FALLBACK_CREDIT_BETA` → `fallback-credit-2026-07-01` (pin June with `FALLBACK_CREDIT_BETA_2026_06_01`)
- `BetaRefusalFallbackMiddleware` defaults to `fallback-credit-2026-07-01` and redeems credit tokens in object form with `mode: "best_effort"`.
- **`MidConversationSystemContent#content`** type is now `Array(MidConversationSystemBlock)` instead of `Array(TextContent)`. Call sites that type the array as `Array(TextContent)` or call `.text` without casting need a small update.

### Added — Amazon Bedrock

- `Anthropic::Bedrock::Client` (Runtime) with AWS SigV4 or `AWS_BEARER_TOKEN_BEDROCK`.
- Credential resolution (pure Crystal chain): explicit keys → env → shared credentials → `aws login` cache → **IAM Identity Center SSO** (`GetRoleCredentials` via cached access token; legacy profile keys and modern `[sso-session …]`) → IMDS (best-effort).
- Request rewrite `/v1/messages` → `/model/{id}/invoke` (+ stream path); injects `anthropic_version: bedrock-2023-05-31`.
- **Streaming:** AWS Event Stream → SSE transcoder so `messages.stream` works.
- **Limited beta surface** on Runtime: `client.beta.messages` only; other beta resources raise.
- **`Anthropic::Bedrock::MantleClient`:** Mantle endpoint (`bedrock-mantle.{region}.api.aws/anthropic`), SigV4 service `bedrock-mantle`, native `/v1/messages` (no rewrite).
- Batches / count_tokens / Models raise `NotImplementedError` (same as official SDKs).
- Examples: `45_bedrock.cr`, `46_bedrock_mantle.cr`.

### Not included

- `claude-mythos-preview` constant (still EOL / omitted by design).
- Google Cloud / Vertex provider package.
- `credential_process`, assume-role profiles, and web-identity federation (use env/shared keys, `aws login`, SSO, or IMDS).

## [0.8.0] — 2026-07-04

Tracks the July 2026 release of the official Python (0.116.0), Ruby (1.55.0), and TypeScript (0.110.0) SDKs, centered on the Claude Sonnet 5 / Fable 5 / Mythos 5 generation.

### Added — Models

- `Anthropic::Model::CLAUDE_SONNET_5`, `Anthropic::Model::CLAUDE_FABLE_5`, `Anthropic::Model::CLAUDE_MYTHOS_5`. `CLAUDE_SONNET` / `CLAUDE_FABLE` rolling aliases now resolve here; `:sonnet`, `:fable`, `:mythos` shorthands updated.
- Retired past-EOL model constants (`claude-opus-4`, `claude-mythos-preview`).

### Added — Server-side fallbacks on refusal

- `Anthropic::FallbackParam`, `Anthropic::FallbackContent` (content block, wired into the `ContentBlock` union + converter), `Anthropic::FallbackInfo`, `Anthropic::FallbackRefusalTrigger`, `Anthropic::FallbackMessageIterationUsage`.
- `fallbacks:` / `fallback_credit_token:` request params on `messages` and `beta.messages` (`create`, `stream`, `open_stream`).
- `Usage#iterations` per-hop breakdown.
- `RefusalStopDetails` gained `fallback_credit_token`, `fallback_has_prefill_claim`, `recommended_model`.
- Beta constants `SERVER_SIDE_FALLBACK_BETA` (`server-side-fallback-2026-06-01`) and `FALLBACK_CREDIT_BETA` (`fallback-credit-2026-06-01`), auto-attached when `fallbacks:` is set.

### Added — HTTP middleware system

- `Anthropic::Middleware` module + `Anthropic::APIRequest` / `Anthropic::APIResponse` / `Anthropic::MiddlewareNext`. Middleware runs once per HTTP attempt inside the retry loop.
- Client registration via `Anthropic::Client.new(middleware: [...])`.
- `Anthropic::BetaRefusalFallbackMiddleware` — client-side refusal fallbacks for providers without server-side fallback support. Tags requests with `fallback-refusal-middleware`.

### Added — New server tools

- `Anthropic::CodeExecutionTool20260521` (`code_execution_20260521`).
- `Anthropic::WebFetchTool20260318` and `Anthropic::WebSearchTool20260318` (with `response_inclusion`).

### Added — Managed Agents

- `client.beta.deployments` — `create`, `retrieve`, `update`, `list`, `archive`, `pause`, `unpause`, `run`.
- `client.beta.deployment_runs` — `retrieve`, `list`.
- Managed Agents event-delta streaming: `event_deltas:` opt-in on `client.beta.sessions.events.stream`, `Anthropic::SessionEventStream`, and the `Anthropic::Sessions.accumulate_managed_agents_event` helper.
- `Anthropic::InjectionLocation` and `Anthropic::CredentialNetworking` for vault credential injection scoping.
- Webhook event classification helpers on `BetaWebhookEvent`.

### Changed

- `user_profile_id` is now sent as the `anthropic-user-profile-id` **request header** (was a JSON body field) across beta + non-beta messages, `count_tokens`, and `parse`, matching the official SDKs.
- `agent-memory-2026-07-22` beta (`AGENT_MEMORY_BETA`) attached to all memory-stores resources.
- `Anthropic::StainlessHelper` single-sources the `x-stainless-helper` telemetry header with append semantics; `extra_headers:` plumbing on `messages` / `beta.messages`; `ToolRunner` now tags requests.
- Streaming accumulator parses tool-use input lazily (once per block close) instead of on every `input_json_delta`.

## [0.7.1] — 2026-05-31

Adds support for the Managed Agents beta API, providing agent definition management and secure credential storage (Vaults).

### Added — Resources

- `client.beta.agents` — CRUD operations for Managed Agents. Provides `create`, `retrieve`, `update`, `list`, and `archive` endpoints.
- `client.beta.vaults` — CRUD operations for Vaults. Provides `create`, `retrieve`, `update`, `list`, `delete`, and `archive` endpoints.
- `client.beta.vaults.credentials` — Vault credentials API. Provides `create`, `retrieve`, `update`, `list`, `delete`, `archive`, and `mcp_oauth_validate` endpoints.
- Automatic injection of the `managed-agents-2026-04-01` beta header (`MANAGED_AGENTS_BETA`) when using the agents and vaults resources.

### Added — Models

- `BetaAgent` and `BetaAgentListResponse` under `Anthropic::BetaAgent`.
- `BetaVault`, `BetaVaultDeleteResponse`, and `BetaVaultListResponse` under `Anthropic::BetaVault`.
- `BetaCredential`, `BetaCredentialDeleteResponse`, `BetaCredentialListResponse`, and `BetaCredentialValidation` under `Anthropic::BetaCredential`.

## [0.7.0] — 2026-05-31

Tracks the Opus 4.8 / May 2026 release of the official Python (0.105.0), Ruby (1.44.0), and TypeScript SDKs.

### Added — Models

- `Anthropic::Model::CLAUDE_OPUS_4_8` — frontier intelligence model. `CLAUDE_OPUS` rolling alias now resolves here.
- `:opus_4_8` shorthand on `Anthropic.model_name`; `:opus` now resolves to `claude-opus-4-8`.

### Added — Content Blocks & Data Types

- `Anthropic::MidConversationSystemContent` (`mid_conv_system`) — dynamic system instructions that appear mid-conversation.
- `Anthropic::OutputTokensDetails` (`output_tokens_details`) — breakdown of output tokens generated as internal reasoning (`thinking_tokens`). Integrated into `Usage` and `DeltaUsage` structures.

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
