# Changelog

All notable changes to `anthropic-cr` are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] — 2026-11-16

Tracks the `2026-10-21` API release across the official Python (2.8.0), Ruby (2.8.0), and TypeScript (1.8.0) SDKs. Upgrades the default `anthropic-version` to `2026-10-21`, switches API key auth to `Authorization: Bearer`, removes `?beta=true`, `client.completions`, sampling parameters, and client-side `CompactionConfig`, promotes User Profiles and core Organization Admin APIs to GA, adds Beta Message Threads (`BetaMessageThread`) with default `ToolRunner` integration, Browser & Computer toolsets (`20260801`), 5.5/5.2 models, 98-entry `(status, error_code)` error dispatch with typed details, new beta Organization extensions (plugins, telemetry destinations, webhooks, Claude Tag, spend limits, usage/cost reports), Managed Agents workflow runs & `SessionRunner` improvements, and full cloud provider parity.

### Changed — Breaking changes (`2026-10-21`)

- **API version & auth**: `Client::API_VERSION` bumped from `"2023-06-01"` to `"2026-10-21"`. API key authentication now sends `Authorization: Bearer <api_key>` instead of `x-api-key`. Passing both `api_key` and `auth_token` explicitly raises `ArgumentError` (setting both `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` in env logs a one-shot warning).
- **`?beta=true` removed**: Removed `?beta=true` query strings from all beta resource URLs; `BetaRefusalFallbackMiddleware#applies_to?` now checks `request.beta?` (set by all `Beta*` resource calls).
- **Completions removed**: Removed `client.completions` (`/v1/complete`), `Anthropic::Completions`, `Anthropic::Completion`, and `examples/47_completions.cr`.
- **Sampling parameters removed**: Removed `temperature`, `top_k`, and `top_p` from GA & Beta `Messages`, `Batches`, `MessageCreateParams`, `TokenCountParams`, `BatchRequestParams`, `BetaBatchRequestParams`, and `ToolRunner`.
- **Client-side `CompactionConfig` removed**: Removed `CompactionConfig` (`compaction_config` / `compaction: CompactionConfig`) from `ToolRunner`; server-side `SummarizeCompaction` and `ToolRunner#compact_before_next_turn` remain.
- **Errors**: Renamed 413 `PayloadTooLargeError` to `ContentTooLargeError` (keeping `alias PayloadTooLargeError = ContentTooLargeError`), added `HTTPNotImplementedError < InternalServerError` (501; never `Anthropic::NotImplementedError` so stdlib `::NotImplementedError` is never shadowed), reparented `GatewayTimeoutError` (504) and `OverloadedError` (529) under `InternalServerError`, and added `RequestTimeoutError` (408), `PreconditionFailedError` (412), `RequestHeaderFieldsTooLargeError` (431), `ClientClosedRequestError` (499), `ServiceUnavailableError` (503), and `ConfigurationError < Exception`.
- **Models**: Removed `betas:` keyword parameter from GA `client.models.list` and `client.models.retrieve` (retained on `client.beta.models`).
- **Beta headers**: Stopped auto-attaching `STRUCTURED_OUTPUT_BETA`, `CACHE_DIAGNOSTICS_BETA`, and `USER_PROFILES_BETA` on GA `Messages` / `Batches`; stopped force-attaching `FILES_API_BETA` on `BetaFiles` and `SKILLS_BETA` on `BetaSkills`; `BetaDreams` sends only `DREAMING_BETA` and `BetaMemoryStores` sends only `AGENT_MEMORY_BETA` (dropping `MANAGED_AGENTS_BETA`); updated `USER_PROFILES_BETA` to `"user-profiles-2026-08-18"` (keeping `USER_PROFILES_2026_03_24_BETA` and `USER_PROFILES_2026_09_04_BETA`).
- **Organization model shapes**: `BetaAPIKey` / `APIKey` drops required `workspace_id` and makes `created_by` / `expires_at` / `partial_key_hint` / `principal` nullable (adding typed `scope` and `principal`); `BetaOrganizationRateLimit#group_type` is optional; `BetaServiceAccountWorkspaceMember#implicit : Bool?` (keeping `#implicit?`) and `BetaFederationIssuer#poll_status` (and `last_fetched_at` / `next_poll_at`) are nullable.
- **Cloud providers**: `GoogleCloud::Client` derived gateway URL path switched from `/v1alpha/` to `/v1/`. `Bedrock::Client` and `Vertex::Client` default `anthropic_version` changed from `"bedrock-2023-05-31"` / `"vertex-2023-10-16"` to `API_VERSION` (`"2026-10-21"`), read from the `anthropic-version` header into body `"anthropic_version"` and deleted from outbound HTTP headers.

### Added — Models, Messages, & Toolsets

- **Models & capabilities**: Added `CLAUDE_SONNET_5_5`, `CLAUDE_HAIKU_5_5`, `CLAUDE_FABLE_5_2`, `CLAUDE_MYTHOS_5_2` and `:sonnet_5_5` / `:haiku_5_5` / `:fable_5_2` / `:mythos_5_2` shorthands; marked `CLAUDE_SONNET_4_5` deprecated (EOL Nov 30, 2026). Added `ModelInfo` `lifecycle`, `line`, `deprecated_at`, `retires_at` (`ModelLine`, `ModelLifecycle`); `lifecycle : Array(String)?` query filter on `Models#list` / `BetaModels#list`; `ModelCapabilities#server_tools : ServerToolsCapability?`; `ThinkingTypes#between_tools` & `#disabled`; and `ThinkingConfig.between_tools`.
- **GA `speed`, diagnostics fix, & system directives**: Added `speed : String?` (`"standard"` | `"fast"`) on GA `Messages`, `MessageCreateParams`, `TokenCountParams`, and `BatchRequestParams`; fixed `CacheMissReason#cache_missed_input_tokens : Int32?`; added Beta `MessageParam` `clear_at`, `output_config : BetaSystemMessageOutputConfig?`, optional `content`, and `MessageParam.system(...)`.
- **Browser & Computer toolsets (`20260801`)**: Added `BrowserToolset20260801` (31-member `BrowserToolsetConfigs` + typed `BrowserToolUse` action inputs) and `ComputerToolset20260801` (17-member `ComputerToolsetConfigs` + typed `ComputerToolUse` action inputs) emitting `x-stainless-helper` (`browser-toolset` / `computer-toolset`) without attaching `anthropic-beta`. Added `toolset_name : String?` on `ToolUseContent` / `ToolResultContent` (propagated by `ToolRunner`) and `BrowserStateContent` (`browser_state` with `tab_opened`, `download_started`, `download_completed`, `download_failed` state changes).

### Added — Beta Message Threads & Runner Enhancements

- **Beta Message Threads (`message-threads-2026-08-12`)**: Added `BetaThreadParam` (`BetaThreadCreateParams` | `BetaThreadContinueParams`) on `BetaMessages` and `BetaBatchRequestParams` (auto-attaching `MESSAGE_THREADS_BETA`), plus `client.beta.messages.thread(...)` returning `BetaMessageThread` (`append`, `update`, `fork`, `send`, `create`, `parse`, `stream`, `open_stream`, `tool_runner`, automatic container adoption, `cache_control`-stripping replay recovery on `ThreadNotFoundError` / `ThreadAlreadyContinuedError` / `ThreadContinueInFlightError` / refusal / fallback / incomplete streams, and `continue_unthreaded` fallback).
- **`ToolRunner` & `BetaRefusalFallbackMiddleware`**: `BetaMessages#tool_runner` uses `BetaMessageThread` by default when `client.supports_message_threads?` (`thread: false` opts out); added initial-message deep copying, `push_messages`, `set_messages_params`, UTF-16 surrogate sanitization, and extra definition fields (`cache_control`, `strict`, `defer_loading`, `allowed_callers`, `input_examples`, `eager_input_streaming`) on `Tool` / `Anthropic.tool`. `BetaRefusalFallbackMiddleware` degrades `thinking.type == "between_tools"` to `disabled`, preserves `role == "system"` directives, and retries once without inherited `speed: "fast"` on HTTP 429 or 529.
- **Streaming**: `MessageStream` and `SnapshotBuilder` pass through unknown SSE event types safely (`UnknownStreamEvent`), survive pre-`message_start` events, preserve `toolset_name` on streamed tool uses, and handle null fields on failed compaction deltas.

### Added — GA User Profiles & Organization Admin

- **GA User Profiles (`client.user_profiles`)**: Full GA `create`, `retrieve`, `update`, `list` (with `enforcement_status` filter and `PageCursorMethods`), `delete` (`DeletedUserProfile`), and `action_urls.create` (`UserProfileActionURL`), plus `UserProfile` models (`enforcement_status`, `enforcement_actions`, `programs` cyber/efs, `external_user_details.reference_id`). Updated `BetaUserProfiles` with `delete`, `action_urls.create`, `enforcement_status`, `name`, and `access_type`; added `user_profile.enforcement_action_opened`, `user_profile.enforcement_action_resolved`, and `user_profile.program_status_updated` webhook events.
- **GA Organization Admin (`client.organization`)**: Exposed `client.organization` (`beta: false`) with `retrieve`, `api_keys`, `compliance_settings`, `external_keys`, `federation`, `invites`, `rate_limits`, `service_accounts`, `users`, `workspaces`, plus newly graduated `rbac_groups` (+ `members`), `rbac_roles` (+ `permissions`), `spend_limits` (`effective.list`, `increase_requests`), and `analytics` (`summaries`, `users`, `apps.chat.projects`, `connectors`, `plugins`, `skills`, `artifacts`). Added `user_profile_id` on `Workspace`/`ExternalKey`, `workspaces.list` `ids`/`include_default`, `workspaces.rate_limits.update`, `invites.create` `rbac_group_ids`, and Beta-only `users.sign_out` (`ADMIN_USER_SIGN_OUT_BETA`).
- **New Beta Organization sub-resources (`client.beta.organization`)**: Added `spend_limits` CRUD (`SPEND_LIMIT_READS_BETA` on `list`), `analytics.usage` & `analytics.cost` (`ANALYTICS_USAGE_COST_BETA`, `ReportPageCursor(T)`) + legacy report helpers, `plugins` (+ `versions`, `installation_settings`, `shares`) & `plugin_marketplaces` (`CE_PLUGINS_BETA`), `telemetry_destinations` (+ `test`, `workspaces`, `TELEMETRY_DESTINATIONS_BETA`), `webhooks` (`WEBHOOKS_BETA`), and `claude_tag` (`bundles`, `targets`, `slack_channels`, `slack_workspaces`, `EXPERIMENTAL_CLAUDE_TAG_BETA`).

### Added — Errors, Transport, Managed Agents, & Cloud Providers

- **Errors & transport**: Added `api_message`, `error_code`, and `details` on `APIError`, `ErrorType` constants (incl. `memory_precondition_failed_error`, `memory_path_conflict_error`, `conflict_error`), the 98-entry `(status_code, error_code)` `ERROR_CLASSES` & `ErrorDetails` union via `Anthropic.build_api_error` / `build_stream_api_error`, `with_options` credential/timeout clearing, `timeout_overridden?` + `x-stainless-timeout`, cross-origin redirect header stripping, preserved client-level `anthropic-workspace-id` / `anthropic-user-profile-id` headers, `Anthropic.encode_path_segment`, bracket/nested query encoding, empty-filename `IO`/`Bytes` multipart parts (`filename=""`), `PageCursorMethods` / `ReportPageCursor(T)`, `x-stainless-helper-method`, and `Schema.const` / typeless `enum`.
- **Managed Agents & Tunnels**: Added `BetaManagedAgentsModel` 5.5/5.2 constants, `execution_identity` (`service_account` | `aws_role`), `multiagent_20261001` (`advisor`, `subagents`, `workflows`), `web_fetch.url_sources`, `SessionUsage` (`active_seconds`, `list_cost`, `server_tool_use`), `SessionThread` (`InlineAgent`, `workflow_run_id`, `statuses`), `SessionEventType` (41 constants), idle `refusal` + `stop_details`, 7 new `session.error` variants, 7 `workflow_run.*` events + 5 errors, `SessionRunner` fix ending turns on any `session.status_idle` with `stop_reason.type != "requires_action"`, and `BetaTunnel#transport` (`cloudflare` / `relay`).
- **Cloud Providers**: Added `supports_message_threads?` (`true` on `AWS::Client` / `GoogleCloud::Client`; `false` on `Bedrock::Client` / `Bedrock::MantleClient` / `Vertex::Client`), `with_options(...)` across all 5 provider clients with atomic credential replacement and explicit-`nil` env skipping, `Anthropic.build_api_error` delegation across Bedrock/Mantle/Vertex, `AWS::Client` Bearer auth + client-side `action_urls` guard + `proxy-authorization` SigV4 exclusion, `Bedrock::Client` `;` matrix model encoding & `AWS_REGION`/`AWS_DEFAULT_REGION` bearer fallback, `MantleClient` `user_profile_id` body injection + bracket query arrays, `GoogleCloud::Client` `claudeOrganization/invoke` routing for `/v1/organizations/` and `/v1/user_profiles` without requiring `workspace_id`, `Vertex::Client` `;` -> `%3B` encoding, and `::NotImplementedError` guards for `user_profiles` and `organization` on Bedrock, Mantle, and Vertex.
- **Example**: Added `examples/51_threads_toolsets_and_admin.cr`.

## [0.11.0] — 2026-09-26

Tracks the late-September 2026 release of the official Python (1.8.0), Ruby (1.73.0), and TypeScript (0.128.0) SDKs. Adds explicit compaction (summarize requests, signed blocks), mid-conversation tool changes on the runner, MCP tool-list pinning, response tools, input transformations, web-fetch URL sources, user external details, data-residency geos, rate-limit groups, and the September beta revisions.

### Changed — Breaking renames (skills, files, user profiles)

- Skills: `BetaSkills#create` takes `display_name:` (was `display_title:`); `SkillResponse#display_title` → `#display_name`, `#latest_version` → `#latest_version_id`, and `#source` is now a `SkillSource` struct (use `#source.type`) instead of a `String`. `SkillVersionResponse#version` / `#directory` are removed — versions are addressed by `#id` (`versions.retrieve` / `versions.delete` take the version id).
- Pagination: files, skills, skill-versions, and user-profiles list responses now expose cursor pagination (`data` + `next_page`) only; `has_more?` / `first_id` / `last_id` are removed. (`BetaAgentListResponse` likewise uses `next_page`.)

### Added — Explicit compaction

- `Anthropic::SummarizeCompaction` (`type: "summarize"`, optional `instructions`) via the `CompactionParam` alias; accepted by beta `messages.create` / `stream` / `open_stream` / `count_tokens` and per-request beta batch params (`BetaBatchRequestParams#compaction`, matching upstream placement). The `compact-2026-09-04` beta attaches automatically.
- `CompactionContent#signature` and `#tool_changes` (addition/removal blocks covering the compacted range); `CompactionCapability` on `ModelCapabilities` (`summarize` + `supported`); `:opus_5_5` shorthand and `CLAUDE_OPUS_5_5`.
- Streaming: compaction deltas now assign the block's final value (a `null` content delta marks a failed compaction) and carry `encrypted_content`.

### Added — Runner tool changes and explicit compaction turns

- `ToolRunner#add_tools` (runnable `Tool` or raw `ToolDefinition`), `#remove_tools` (by tool or name), and `#compact_before_next_turn` (explicit server-side compaction before the next turn; requires `use_beta: true`). Tool changes flush as a trailing system message with the `inline-tools-2026-09-15` beta attached automatically; local dispatch follows the overrides immediately.
- `Role::System` for system-role message params.

### Added — API deltas

- Beta flags: `USER_PROFILES_2026_09_04_BETA`, `COMPACT_2026_09_04_BETA`, `INLINE_TOOLS_2026_09_15_BETA`, `MCP_CLIENT_2026_09_15_BETA`.
- Rate limits: `BetaOrganizationRateLimit#group` discriminated union (`BetaOrganizationRateLimitModelGroup` with `display_name`, plus batch/files/skills/token-count/web-search groups); `models` is now nilable (`nil` for non-model groups). Both match upstream, where `group` is required and `models` is `null` off model groups — readers must nil-check `models`.
- Forward compatibility: unknown tool-change, input-transformation, and rate-limit-group variants parse into `GenericToolChange` / `GenericInputTransformation` / `BetaOrganizationRateLimitGenericGroup` (raw payload preserved) instead of raising, mirroring `GenericStopDetails`.
- `BetaWorkspace#data_residency` is now typed (`BetaDataResidency?`) instead of `JSON::Any?`.
- `ToolRunner#add_tools` / `#remove_tools` now require a beta runner (`use_beta: true`), raising `ArgumentError` otherwise; `ToolRemovalContent` only accepts reference (never by-value) tools.
- MCP: `MCPToolListingContent` response block; `MCPToolset#tools` pins the server's listing (`MCPToolListingEntry`), auto-attaching `mcp-client-2026-09-15` in place of the older revision.
- Response tools: `ResponseTool` (+ `from_definition`) and `ToolChangeToolDefinition` for inline tool definitions; server-tool definitions stay raw `JSON::Any`.
- Input transformations: `Message#input_transformations` (`ThinkingDroppedInputTransformation` / `ThinkingMismatchAllowedInputTransformation` + `InputTransformationReason`); streaming replaces the `message_start` value with the serving model's entries from `message_delta`.
- Web fetch: `url_sources` (`WebFetchURLSources` with all/none/only/except tool-result scopes and all/none user-input scope) on all four web-fetch tool versions.
- User profiles: `external_user_details` (`BetaUserProfileExternalUserDetails`, all fields optional/nilable) on create/update and responses; the `user-profiles-2026-09-04` revision attaches automatically when details are sent.
- Data residency: `BetaAllowedInferenceGeo` (`GLOBAL` / `US`), `allowed_inference_geos` accepts `"unrestricted"` (`BetaDataResidency#unrestricted?`), and `BetaDataResidencyCreateConfig` / `BetaDataResidencyUpdateConfig` for workspace create/update.
- Example: `examples/50_compaction_and_tools.cr`.

### Added — Sessions and environments (managed agents)

- `BetaSessionEvents#send` with seven typed input events (`BetaSessionUserMessageEvent.message` / `.message` on system events, interrupt, tool confirmation, tool result, custom tool result, define-outcome with file/text rubrics); the send response mirrors upstream (`{data: [...]}`).
- Typed session resources: `BetaSessionFileResource` / `BetaSessionGitHubRepositoryResource` (branch/commit `checkout`) / `BetaSessionMemoryStoreResource` behind `BetaSessionResourceConverter`, with `GenericSessionResource` preserving unknown future types. `resources.add_file` / `#retrieve` / `#list` now return typed values; new `#update` (authorization token, POST) and `#delete` (`BetaSessionResourceDeleted`).
- Self-hosted environment work queue: `client.beta.environments.work` with `#retrieve` / `#update` (metadata merge patch) / `#list` / `#ack` / `#heartbeat` / `#poll` (nil when idle, `anthropic-worker-id` via `WORKER_ID_HEADER`) / `#stats` / `#stop`. Work payloads discriminate session vs healthcheck data (`BetaSessionWorkData` / `BetaHealthCheckWorkData`).
- `workspace_id` now accepted on every sessions, session-events, session-resources, session-threads, and environments call (list/delete/archive included); `sessions#update` also takes `vault_ids` and nil-deleting metadata patches.
- Breaking: `BetaSessionThreads#create` removed — no upstream thread-create endpoint exists (threads are created by the API); use `#retrieve` / `#list` / `#archive`.

### Added — Structured-output parsing, federation workspaces, webhooks, workspace headers

- GA `client.messages.parse` (typed `TypedOutputSchema(T)` → `ParsedMessage(T)` and untyped `OutputSchema` → `ParsedMessage(JSON::Any)` overloads), mirroring the beta helper; GA create/stream/count_tokens now auto-attach the structured-outputs beta when `output_config.format` is set.
- Federation rule workspaces: `client.beta.organization.federation.rules.workspaces` with `#list` / `#add` / `#remove`; `BetaFederationRuleWorkspace#created_by_actor_id` / `#workspace_name` are now nilable per upstream.
- `BetaFederationRule#attributes` / `#created_by_actor_id` / `#description` / `#issuer_name` / `#updated_by_actor_id` are now nilable per upstream (`attributes` is always null today) — readers must nil-check them.
- Webhooks: `BetaWebhooks#parse_unverified`, `Client#webhook_key` (falls back to `ANTHROPIC_WEBHOOK_SIGNING_KEY`), full session/vault/vault-credential `EventType` vocabulary, and `BetaWebhookEvent#event_type` with fixed `*_event?` classification (delivery type is nested in `data`, not the `"event"` envelope).
- `workspace_id` header sweep: accepted on every deployments, deployment-runs, memory-stores, memories, memory-versions, tunnels, certificates, user-profiles, vaults, credentials, and GA/beta models call; GA models and user-profiles calls also accept `betas` per upstream.

### Fixed — Content parsing and agent toolsets

- `Citation` now uses the upstream `start_char_index` / `end_char_index` keys (the old `start_char` / `end_char` keys never matched the API); deprecated `start_char` / `end_char` readers remain. Char, page, and content-block citations also expose `file_id`.
- `WebSearchToolResultContent` carries the upstream `caller` (with `caller` / `caller_tool_id` helpers, including the `code_execution_20260120` variant) and parses error payloads (`WebSearchToolResultError` + `WebSearchToolResultErrorCode`) via `results` / `result_error`; `WebSearchResult` gained its `type` discriminator.
- Images: `FileImageSource` (`ImageContent.file`), `ImageTransformations` (`oversized_image: downsize | error` via `OversizedImageBehavior`), and `transformations:` on all image factories.
- Typed agent toolsets: `BetaAgent#tools` parses into `BetaManagedAgentsAgentToolset20260401` / `BetaManagedAgentsMCPToolset` / `BetaManagedAgentsCustomTool` (configs, default configs, permission policies, web-tool domains/locations); agents `#create` / `#update` take typed `BetaManagedAgentsToolsetParam` tools. Also fixed latent `.as_a` misuse when serializing agent `mcp_servers` / `skills` / `tools` request bodies.
- `BetaAgentListResponse` uses cursor pagination (`next_page`) instead of `has_more`, matching upstream.

### Added — Runner resume, session runner, MCP helpers, streaming parse

- `ToolRunner` resumes paused turns: `pause_turn` / `compaction` stop reasons send the turn back unchanged instead of finishing, in both `#next_message` / `#run_until_finished` and `#each_streaming`. Pending compaction is deferred and queued tool changes are held while a turn is paused; streaming resumes replay full message content (thinking included) and tools run only on `tool_use` turns.
- `SessionRunner` streams managed-agents session events, executes local `Tool`s for `agent.tool_use` / `agent.custom_tool_use` (event id doubles as the result id), sends results back, and returns the terminal event (`session.status_terminated`, `session.deleted`); calls for unregistered tools are skipped without posting a result, and `max_events` bounds a run. It reconnects dropped streams with jittered backoff (500ms→10s, permanent 4xx aborts, `max_reconnects` bounds the loop), re-reads history after each (re)connect (a terminal in history ends the run; a trailing `end_turn` idle re-arms the countdown), gates `ask` calls on `user.tool_confirmation` verdicts (fail closed; server `deny` wins), stops after `max_idle` (default 60s) past an `end_turn` idle, and reports per-call outcomes via `on_call` (`SessionRunner::ToolCall`, including executed-but-unposted sends). Failed sends abort the run rather than re-executing the tool; malformed stream lines trigger a reconnect and non-object payloads are skipped.
- `Anthropic::MCP.content` / `.message` / `.messages` / `.resource_to_content` convert MCP payloads (text, image, embedded resources) into Anthropic content blocks without an MCP SDK dependency; unsupported or malformed values raise `MCP::UnsupportedMCPValueError`. Runnable-tool adapters (`mcpTool`) are out of scope — there is no Crystal MCP client to wrap.
- `MessageStream#final_parsed_output_as` / `#final_parsed_output_as!` parse the streamed final message's structured output.

### Added — Client internals (auth, scoped options, proxy, request IDs)

- OAuth bearer auth: `Client.new(auth_token:)` (or `ANTHROPIC_AUTH_TOKEN`) sends `Authorization: Bearer` instead of `x-api-key`. An explicit credential argument disables environment lookup, matching Python/Ruby.
- `Client#with_options` returns a scoped copy with overridden `timeout` / `max_retries` / `extra_headers` / `extra_query` / `middleware` / credentials / `base_url` / `proxy` — the Crystal equivalent of upstream per-request options. `Client#with_middleware` appends middleware to a copy.
- HTTPS proxy support: explicit `proxy:` URL or `HTTPS_PROXY` / `https_proxy` with `NO_PROXY` / `no_proxy` bypass (wildcards, subdomains, leading dots), HTTPS `CONNECT` tunneling, and `Proxy-Authorization` from URL userinfo. Only `http://` proxies are accepted; plain-HTTP base URLs bypass the proxy.
- Per-request query params win over client `default_query` instead of sending both; raw-download and multipart paths now raise typed `APITimeoutError` / `APIConnectionError` like every other path (including direct-path TLS failures).
- `APIError#request_id` reads the `request-id` response header for support reports.
- Retry loop also retries typed `APITimeoutError` / `APIConnectionError` from the proxy path, matching the middleware path.

## [0.10.0] — 2026-09-07

Tracks the September 2026 release of the official Python (1.4.0), Ruby (1.69.0), and TypeScript (0.124.0) SDKs. Adds the Organization Admin API, alternate provider clients (AWS gateway, Google Cloud gateway, Vertex AI), legacy Completions, and recent API deltas (thinking display modes, workspace headers, session budgets, dream output behavior, user-profile fields, new models and beta flags).

### Added — Organization Admin API (beta)

- `client.beta.organization` — `retrieve` plus sub-resources: `api_keys`, `external_keys`, `invites`, `users`, `workspaces` (with nested `members`, `rate_limits`, `service_accounts`), `service_accounts` (with nested `workspaces`), `federation` (`issuers` + `rules`), `rate_limits`, `compliance_settings`.
- Types: `BetaOrganization`, `BetaAPIKey`, `BetaExternalKey` (+ deletion/validation shapes), `BetaOrganizationInvite`, `BetaOrganizationUser`, `BetaWorkspace` (+ member shapes), `BetaServiceAccount` (+ membership shapes), `BetaFederationIssuer`, `BetaFederationRule` (+ match/workspace shapes), `BetaOrganizationRateLimit`, `BetaComplianceSettings`, `BetaDataResidency`, role modules, and per-resource paginated list responses.
- Example: `examples/48_organization.cr`.

### Added — Alternate providers (non-Azure)

- `Anthropic::Vertex::Client` — Vertex AI publisher-model API (`rawPredict` / `streamRawPredict` URL rewrite, `vertex-2023-10-16` version, Google OAuth Bearer auth, Batch API raises `NotImplementedError`).
- `Anthropic::GoogleCloud::Client` — Claude API on the Google Cloud gateway (full first-party API passthrough with invoke-prefix routing, `token_provider` / access token / ADC, `skip_auth` mode).
- `Anthropic::AWS::Client` — AWS gateway (`aws-external-anthropic` SigV4 via the shared Bedrock credential chain, API-key mode, workspace header, `skip_auth` mode).
- `Anthropic::GoogleAuth::Provider` — shared Google credential resolution (explicit token, token-provider proc, `authorized_user` ADC refresh, GCE metadata server). Service-account key files raise an actionable error (Crystal stdlib has no RSA signer for the JWT-bearer grant).
- Example: `examples/49_providers.cr`.

### Added — Legacy Completions

- `client.completions` — `create` and block-based `stream` for `/v1/complete` with `betas:` / `workspace_id:` header support (mirrors the official SDKs' create/create_streaming split, including the `ArgumentError` guards).
- Type: `Anthropic::Completion`.
- Example: `examples/47_completions.cr`.

### Added — API deltas

- Models: `CLAUDE_FABLE_5_1` (`claude-fable-5-1`), `CLAUDE_MYTHOS_5_1` (`claude-mythos-5-1`), `:fable_5_1` / `:mythos_5_1` shorthands.
- Beta flags: `THINKING_DISPLAY_UPDATES_BETA`, `THINKING_BINDING_CONTROLS_BETA`, `MID_CONVERSATION_TOOL_CHANGES_BETA`, `MID_CONVERSATION_OUTPUT_CONFIG_BETA`, `MID_CONVERSATION_SYSTEM_CLEAR_AT_BETA`, `TASK_BUDGETS_BETA`, `COMPACT_BETA`, `COMPUTER_USE_2025_11_24_BETA`, `CE_USER_MANAGEMENT_BETA`, `USER_PROFILES_2026_08_18_BETA`.
- Thinking: `ThinkingConfig#display` (`summarized` / `omitted` / `updates` via `Anthropic::ThinkingDisplay`); Messages methods auto-attach the display-updates beta when set.
- Workspace: first-class `workspace_id:` on Messages (GA + beta + `parse`), Sessions, Dreams, and Completions via centralized `Anthropic.merge_workspace_header`; `APIError#workspace_id` reads the `anthropic-workspace-id` response header.
- Sessions: `budget:` on create/update (`BetaManagedAgentsBudgetLimit` + `BetaMonetaryAmount`); `BetaManagedAgentsSession#budget`; `workspace_id:` on create/retrieve/update.
- Dreams: `output_behavior:` on create (`BetaDreamOutputBehaviorCreateNew` / `BetaDreamOutputBehaviorUpdateExisting`); required `BetaDream#output_behavior` (current API responses always include it).
- User profiles: `access_type` / `name` / `external_user_onboarded_at` on create/update and responses (`Anthropic::UserProfileAccessType`); `order_by` on list.

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
