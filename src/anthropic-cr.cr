require "json"
require "http/client"
require "json-schema"
require "uuid"

# Core modules
require "./anthropic-cr/version"
require "./anthropic-cr/errors"
require "./anthropic-cr/schema"
require "./anthropic-cr/stainless_helper"
require "./anthropic-cr/middleware"
require "./anthropic-cr/refusal_fallback_middleware"

# Models
require "./anthropic-cr/models/role"
require "./anthropic-cr/models/content"
require "./anthropic-cr/models/usage"
require "./anthropic-cr/models/message"
require "./anthropic-cr/models/model_info"
require "./anthropic-cr/models/diagnostics"
require "./anthropic-cr/models/environments"
require "./anthropic-cr/models/memory_stores"
require "./anthropic-cr/models/sessions"
require "./anthropic-cr/models/webhooks"
require "./anthropic-cr/models/agents"
require "./anthropic-cr/models/vaults"
require "./anthropic-cr/models/fallbacks"
require "./anthropic-cr/models/deployments"
require "./anthropic-cr/models/dreams"
require "./anthropic-cr/models/tunnels"

# Streaming
require "./anthropic-cr/streaming/events"
require "./anthropic-cr/streaming/stream"
require "./anthropic-cr/streaming/session_event_stream"

# Sessions accumulate helper + managed-agents delta types
require "./anthropic-cr/sessions"

# Tools
require "./anthropic-cr/tools/tool_choice"
require "./anthropic-cr/tools/tool"
require "./anthropic-cr/tools/server_tools"
require "./anthropic-cr/tools/runner"

# Request params (typed structs for API requests)
require "./anthropic-cr/models/params"

# Resources
require "./anthropic-cr/resources/file_upload"
require "./anthropic-cr/resources/messages"
require "./anthropic-cr/resources/batches"
require "./anthropic-cr/resources/models"
require "./anthropic-cr/resources/files"
require "./anthropic-cr/resources/skills"
require "./anthropic-cr/resources/user_profiles"
require "./anthropic-cr/resources/environments"
require "./anthropic-cr/resources/memory_stores"
require "./anthropic-cr/resources/sessions"
require "./anthropic-cr/resources/webhooks"
require "./anthropic-cr/resources/agents"
require "./anthropic-cr/resources/vaults"
require "./anthropic-cr/resources/deployments"
require "./anthropic-cr/resources/dreams"
require "./anthropic-cr/resources/tunnels"
require "./anthropic-cr/resources/beta"

# Client (must come after resources that define types used in Client methods)
require "./anthropic-cr/client"

# Amazon Bedrock Runtime + Mantle (SigV4 / optional bearer)
require "./anthropic-cr/bedrock/credentials"
require "./anthropic-cr/bedrock/sigv4"
require "./anthropic-cr/bedrock/client"
require "./anthropic-cr/bedrock/mantle_client"

module Anthropic
end
