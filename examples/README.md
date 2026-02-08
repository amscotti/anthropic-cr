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
