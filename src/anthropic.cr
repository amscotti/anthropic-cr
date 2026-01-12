require "json"
require "http/client"
require "json-schema"

# Core modules
require "./anthropic/version"
require "./anthropic/errors"
require "./anthropic/schema"

# Models
require "./anthropic/models/role"
require "./anthropic/models/content"
require "./anthropic/models/usage"
require "./anthropic/models/message"
require "./anthropic/models/model_info"

# Streaming
require "./anthropic/streaming/events"
require "./anthropic/streaming/stream"

# Tools
require "./anthropic/tools/tool_choice"
require "./anthropic/tools/tool"
require "./anthropic/tools/server_tools"
require "./anthropic/tools/runner"

# Request params (typed structs for API requests)
require "./anthropic/models/params"

# Client and resources
require "./anthropic/client"
require "./anthropic/resources/messages"
require "./anthropic/resources/batches"
require "./anthropic/resources/models"
require "./anthropic/resources/files"
require "./anthropic/resources/beta"

module Anthropic
end
