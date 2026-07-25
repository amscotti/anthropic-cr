# Anthropic Crystal SDK Examples

Working examples demonstrating how to use the anthropic-cr SDK.

## Prerequisites

Set your API key:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Or create a `.env` file in the project root:
```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

## Running Examples

```bash
shards install
crystal run examples/01_basic_message.cr
```

## Examples

### Core API

| File | Description |
|------|-------------|
| `01_basic_message.cr` | Basic message + multi-turn conversation |
| `02_streaming.cr` | Streaming responses with SSE |
| `03_tool_use.cr` | Complete tool execution loop |
| `04_vision.cr` | Image understanding |
| `05_system_prompt.cr` | System prompts and temperature |
| `06_error_handling.cr` | Error types and retry behavior |

### Resources

| File | Description |
|------|-------------|
| `07_list_models.cr` | Models API (list, retrieve) |
| `08_batches.cr` | Message Batches API |
| `09_tool_runner.cr` | Automatic tool execution loop |
| `10_pagination.cr` | Auto-pagination helpers |

### Advanced Features

| File | Description |
|------|-------------|
| `11_schema_dsl.cr` | Schema DSL for tool definitions |
| `12_web_search.cr` | Web search server tool |
| `13_extended_thinking.cr` | Extended thinking / reasoning |
| `14_citations.cr` | Document citations |
| `15_structured_outputs.cr` | Type-safe JSON responses |
| `16_tools_streaming.cr` | Streaming with tools |
| `17_web_search_streaming.cr` | Web search with streaming |
| `18_typed_tools.cr` | Typed tools (BaseTool pattern) |

### Beta & Utilities

| File | Description |
|------|-------------|
| `19_files_api.cr` | Files API (upload, download) |
| `20_chatbot.cr` | Interactive chatbot |
| `21_token_counting.cr` | Token counting for context management |
| `22_prompt_caching.cr` | Prompt caching |
| `23_auto_compaction.cr` | Automatic context compaction |
| `24_advanced_streaming.cr` | Advanced streaming patterns |
| `25_ollama.cr` | Ollama local model integration |
| `26_opus_46.cr` | Claude Opus 4.6 features |
| `27_agent_tools.cr` | Agent tools (bash, text editor, computer use, web fetch, memory) |
| `28_advanced_features.cr` | Redacted thinking, cache_control, metadata, extended tool fields |
| `29_beta_params.cr` | MCP servers, container/skills, tool search, CompactionDelta |
| `30_skills_api.cr` | Skills API (CRUD, versions, container integration) |
| `31_open_stream.cr` | Richer block-scoped streaming with `open_stream` |
| `32_model_capabilities.cr` | Inspect Models API metadata and capability support |
| `33_web_fetch_cache_control.cr` | `WebFetchTool20260309` with `use_cache: false` |

### Opus 4.8 / May 2026

| File | Description |
|------|-------------|
| `34_managed_agents.cr` | Stateful Managed Agents API (environments, memory stores, agents, vaults, webhooks) |
| `34_opus_48.cr` | Claude Opus 4.8 with `xhigh` effort and `BetaTokenTaskBudget` |
| `35_advisor_tool.cr` | Advisor tool (`advisor_20260301`) with typed result-block handling |
| `36_user_profiles.cr` | User Profiles API + `user_profile_id` scoped messaging |

### Sonnet 5 / Fable 5 / July 2026 (0.8.0)

| File | Description |
|------|-------------|
| `37_sonnet_5_fable_5.cr` | Claude Sonnet 5 / Fable 5 / Mythos 5 models |
| `38_new_tools.cr` | New server tools (`code_execution_20260521`, `web_fetch_20260318`, `web_search_20260318`) |
| `39_fallbacks.cr` | Server-side refusal fallbacks (`fallbacks:` chain or `"default"`, object credit tokens) |
| `40_middleware.cr` | HTTP middleware (logging + header injection) |
| `41_refusal_fallback_middleware.cr` | Client-side `BetaRefusalFallbackMiddleware` |

### Opus 5 / Dreams / Tunnels / July 2026 (0.9.0)

| File | Description |
|------|-------------|
| `42_opus_5.cr` | Claude Opus 5 model smoke test (`CLAUDE_OPUS` / `:opus` rolling alias) |
| `43_dreams.cr` | Dreams API — memory consolidation (gated research preview; 404 without access) |
| `44_tunnels.cr` | MCP Tunnels management (WIF `workspace:manage_tunnels`; API keys return 401) |

`34_managed_agents.cr` also covers 0.9.0 additions: agent model config with `effort` / `speed`, session `initial_events`, and thread stream `event_deltas`.

### Amazon Bedrock

| File | Description |
|------|-------------|
| `45_bedrock.cr` | Bedrock Runtime — SigV4, non-streaming + streaming (event-stream→SSE) |
| `46_bedrock_mantle.cr` | Bedrock Mantle — native `/v1/messages`, SigV4 service `bedrock-mantle` |

Prefer inference profile model IDs for Runtime (`us.anthropic.*` / `global.anthropic.*`). Credentials resolve from env, `~/.aws/credentials`, `aws login` cache, IAM Identity Center SSO (`aws sso login`), or IMDS. Mantle Anthropic models may need separate account entitlement beyond Runtime access.

