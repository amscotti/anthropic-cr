module Anthropic
  # Server-side tools that are executed by Anthropic's servers
  #
  # These tools don't require local execution - Claude can use them directly
  # and the results are returned as part of the message.

  # Base type for server-side tools
  abstract struct ServerTool
    include JSON::Serializable

    abstract def type : String
  end

  # Beta header constants
  WEB_SEARCH_BETA             = "web-search-2025-03-05"
  STRUCTURED_OUTPUT_BETA      = "structured-outputs-2025-11-13"
  FILES_API_BETA              = "files-api-2025-04-14"
  EXTENDED_CACHE_TTL_BETA     = "extended-cache-ttl-2025-04-11"
  TOKEN_EFFICIENT_TOOLS_BETA  = "token-efficient-tools-2025-02-19"
  FINE_GRAINED_STREAMING_BETA = "fine-grained-tool-streaming-2025-05-14"
  CODE_EXECUTION_BETA         = "code-execution-2025-05-22"
  MCP_CONNECTOR_BETA          = "mcp-connector-2025-05-01"
  ADVANCED_TOOL_USE_BETA      = "advanced-tool-use-2025-11-20"

  # Web search tool - allows Claude to search the internet
  #
  # Note: This tool requires the beta header "anthropic-beta: web-search-2025-03-05"
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 1024,
  #   server_tools: [Anthropic::WebSearchTool.new],
  #   messages: [{role: "user", content: "What's the latest news about Crystal programming language?"}]
  # )
  # ```
  struct WebSearchTool < ServerTool
    include JSON::Serializable

    getter type : String = "web_search_20250305"
    getter name : String = "web_search"

    # Optional: Limit search to specific domains
    @[JSON::Field(key: "allowed_domains")]
    getter allowed_domains : Array(String)?

    # Optional: Exclude specific domains from search
    @[JSON::Field(key: "blocked_domains")]
    getter blocked_domains : Array(String)?

    # Optional: Maximum number of searches Claude can perform
    @[JSON::Field(key: "max_uses")]
    getter max_uses : Int32?

    # Optional: User's approximate location for localized results
    @[JSON::Field(key: "user_location")]
    getter user_location : UserLocation?

    def initialize(
      @allowed_domains : Array(String)? = nil,
      @blocked_domains : Array(String)? = nil,
      @max_uses : Int32? = nil,
      @user_location : UserLocation? = nil,
    )
    end

    # Returns the beta header required for this tool
    def self.beta_header : String
      WEB_SEARCH_BETA
    end

    # Create a web search tool limited to specific domains
    def self.limited_to(*domains : String) : self
      new(allowed_domains: domains.to_a)
    end

    # Create a web search tool excluding specific domains
    def self.excluding(*domains : String) : self
      new(blocked_domains: domains.to_a)
    end
  end

  # User location for localized web search results
  struct UserLocation
    include JSON::Serializable

    getter type : String = "approximate"
    getter city : String?
    getter region : String?
    getter country : String?
    getter timezone : String?

    def initialize(
      @city : String? = nil,
      @region : String? = nil,
      @country : String? = nil,
      @timezone : String? = nil,
    )
    end
  end

  # Code execution tool - allows Claude to run code in a sandbox
  struct CodeExecutionTool < ServerTool
    include JSON::Serializable

    getter type : String = "code_execution_20250522"

    def initialize
    end
  end

  # MCP (Model Context Protocol) tool - connects to external MCP servers
  struct MCPTool < ServerTool
    include JSON::Serializable

    getter type : String = "mcp_20250501"
    getter name : String

    # Server configuration
    @[JSON::Field(key: "server_label")]
    getter server_label : String

    @[JSON::Field(key: "server_url")]
    getter server_url : String

    @[JSON::Field(key: "allowed_tools")]
    getter allowed_tools : Array(String)?

    def initialize(
      @name : String,
      @server_label : String,
      @server_url : String,
      @allowed_tools : Array(String)? = nil,
    )
    end
  end

  # Union type for all server tools
  alias AnyServerTool = WebSearchTool | CodeExecutionTool | MCPTool

  # Individual web search result
  struct WebSearchResult
    include JSON::Serializable

    getter url : String
    getter title : String
    getter snippet : String?

    @[JSON::Field(key: "encrypted_content")]
    getter encrypted_content : String?

    @[JSON::Field(key: "page_age")]
    getter page_age : String?

    def initialize(
      @url : String,
      @title : String,
      @snippet : String? = nil,
      @encrypted_content : String? = nil,
      @page_age : String? = nil,
    )
    end
  end

  # Server tool use content block (Claude using a server-side tool)
  struct ServerToolUseContent
    include JSON::Serializable

    getter type : String = "server_tool_use"
    getter id : String
    getter name : String
    getter input : JSON::Any

    def initialize(@id : String, @name : String, @input : JSON::Any)
    end

    # Parse input into a typed struct
    def input_as(type : T.class) : T forall T
      T.from_json(input.to_json)
    end
  end

  # Web search tool result content block
  struct WebSearchToolResultContent
    include JSON::Serializable

    getter type : String = "web_search_tool_result"

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter content : Array(WebSearchResult)

    def initialize(@tool_use_id : String, @content : Array(WebSearchResult))
    end
  end
end
