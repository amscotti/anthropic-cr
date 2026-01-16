require "json"
require "http/client"
require "json-schema"

# Core modules
require "./anthropic-cr/version"
require "./anthropic-cr/errors"
require "./anthropic-cr/schema"

# Models
require "./anthropic-cr/models/role"
require "./anthropic-cr/models/content"
require "./anthropic-cr/models/usage"
require "./anthropic-cr/models/message"
require "./anthropic-cr/models/model_info"

# Streaming
require "./anthropic-cr/streaming/events"
require "./anthropic-cr/streaming/stream"

# Tools
require "./anthropic-cr/tools/tool_choice"
require "./anthropic-cr/tools/tool"
require "./anthropic-cr/tools/server_tools"
require "./anthropic-cr/tools/runner"

# Request params (typed structs for API requests)
require "./anthropic-cr/models/params"

# Client and resources
require "./anthropic-cr/client"
require "./anthropic-cr/resources/messages"
require "./anthropic-cr/resources/batches"
require "./anthropic-cr/resources/models"
require "./anthropic-cr/resources/files"
require "./anthropic-cr/resources/beta"

module Anthropic
end
