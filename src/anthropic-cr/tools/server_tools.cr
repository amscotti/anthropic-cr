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
  CODE_EXECUTION_BETA         = "code-execution-2025-08-25"
  MCP_CONNECTOR_BETA          = "mcp-connector-2025-05-01"
  ADVANCED_TOOL_USE_BETA      = "advanced-tool-use-2025-11-20"
  COMPUTER_USE_BETA           = "computer-use-2025-01-24"
  COMPUTER_USE_LEGACY_BETA    = "computer-use-2024-10-22"
  WEB_FETCH_BETA              = "web-fetch-2025-09-10"
  MEMORY_BETA                 = "context-management-2025-06-27"
  SKILLS_BETA                 = "skills-2025-10-02"
  MCP_CLIENT_BETA             = "mcp-client-2025-11-20"

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

    getter type : String = "code_execution_20250825"

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

  # Bash tool - allows Claude to execute bash commands
  #
  # An agent tool for running shell commands in a sandboxed environment.
  # This tool is GA and does not require a beta header.
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 4096,
  #   server_tools: [Anthropic::BashTool.new],
  #   messages: [{role: "user", content: "List the files in the current directory"}]
  # )
  # ```
  struct BashTool < ServerTool
    include JSON::Serializable

    getter type : String = "bash_20250124"
    getter name : String = "bash"

    def initialize
    end
  end

  # Text editor tool - allows Claude to view and edit files
  #
  # An agent tool for reading and modifying text files.
  # This tool is GA and does not require a beta header.
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 4096,
  #   server_tools: [Anthropic::TextEditorTool.new],
  #   messages: [{role: "user", content: "Read the contents of config.yml"}]
  # )
  # ```
  struct TextEditorTool < ServerTool
    include JSON::Serializable

    getter type : String = "text_editor_20250728"
    getter name : String = "str_replace_based_edit_tool"

    # Optional: Maximum number of characters the tool can process
    @[JSON::Field(key: "max_characters", emit_null: false)]
    getter max_characters : Int32?

    def initialize(@max_characters : Int32? = nil)
    end
  end

  # Computer use tool - allows Claude to interact with a computer desktop
  #
  # An agent tool for controlling a computer through screenshots, mouse, and keyboard.
  # Requires the computer use beta header.
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 4096,
  #   server_tools: [Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080)],
  #   messages: [{role: "user", content: "Open the browser and navigate to example.com"}]
  # )
  # ```
  struct ComputerUseTool < ServerTool
    include JSON::Serializable

    getter type : String = "computer_20250124"
    getter name : String = "computer"

    # Required: Width of the display in pixels
    @[JSON::Field(key: "display_width_px")]
    getter display_width_px : Int32

    # Required: Height of the display in pixels
    @[JSON::Field(key: "display_height_px")]
    getter display_height_px : Int32

    # Optional: Display number for multi-monitor setups
    @[JSON::Field(key: "display_number", emit_null: false)]
    getter display_number : Int32?

    # Optional: Enable zoom for accessibility
    @[JSON::Field(key: "enable_zoom", emit_null: false)]
    getter enable_zoom : Bool?

    def initialize(
      @display_width_px : Int32,
      @display_height_px : Int32,
      @display_number : Int32? = nil,
      @enable_zoom : Bool? = nil,
    )
    end
  end

  # Web fetch tool - allows Claude to fetch and read web pages
  #
  # A server-side tool that enables Claude to retrieve content from URLs.
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 4096,
  #   server_tools: [Anthropic::WebFetchTool.new],
  #   messages: [{role: "user", content: "Read the content at https://example.com"}]
  # )
  # ```
  struct WebFetchTool < ServerTool
    include JSON::Serializable

    getter type : String = "web_fetch_20250910"
    getter name : String = "web_fetch"

    # Optional: Maximum number of fetches Claude can perform
    @[JSON::Field(key: "max_uses", emit_null: false)]
    getter max_uses : Int32?

    # Optional: Limit fetching to specific domains
    @[JSON::Field(key: "allowed_domains", emit_null: false)]
    getter allowed_domains : Array(String)?

    # Optional: Exclude specific domains from fetching
    @[JSON::Field(key: "blocked_domains", emit_null: false)]
    getter blocked_domains : Array(String)?

    # Optional: Maximum content tokens to return
    @[JSON::Field(key: "max_content_tokens", emit_null: false)]
    getter max_content_tokens : Int32?

    # Optional: Enable citations on fetched content
    @[JSON::Field(emit_null: false)]
    getter citations : CitationConfig?

    def initialize(
      @max_uses : Int32? = nil,
      @allowed_domains : Array(String)? = nil,
      @blocked_domains : Array(String)? = nil,
      @max_content_tokens : Int32? = nil,
      @citations : CitationConfig? = nil,
    )
    end

    # Create a web fetch tool limited to specific domains
    def self.limited_to(*domains : String) : self
      new(allowed_domains: domains.to_a)
    end

    # Create a web fetch tool excluding specific domains
    def self.excluding(*domains : String) : self
      new(blocked_domains: domains.to_a)
    end
  end

  # Memory tool - allows Claude to store and retrieve information across conversations
  #
  # A server-side tool for persistent memory management.
  #
  # ```
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 4096,
  #   server_tools: [Anthropic::MemoryTool.new],
  #   messages: [{role: "user", content: "Remember that my favorite color is blue"}]
  # )
  # ```
  struct MemoryTool < ServerTool
    include JSON::Serializable

    getter type : String = "memory_20250818"
    getter name : String = "memory"

    def initialize
    end
  end

  # Legacy bash tool (October 2024 version, beta-only)
  struct BashToolLegacy < ServerTool
    include JSON::Serializable

    getter type : String = "bash_20241022"
    getter name : String = "bash"

    def initialize
    end
  end

  # Legacy text editor tool (October 2024 version, beta-only)
  struct TextEditorToolLegacy < ServerTool
    include JSON::Serializable

    getter type : String = "text_editor_20241022"
    getter name : String = "str_replace_editor"

    def initialize
    end
  end

  # Legacy computer use tool (October 2024 version, beta-only)
  struct ComputerUseToolLegacy < ServerTool
    include JSON::Serializable

    getter type : String = "computer_20241022"
    getter name : String = "computer"

    @[JSON::Field(key: "display_width_px")]
    getter display_width_px : Int32

    @[JSON::Field(key: "display_height_px")]
    getter display_height_px : Int32

    @[JSON::Field(key: "display_number", emit_null: false)]
    getter display_number : Int32?

    def initialize(
      @display_width_px : Int32,
      @display_height_px : Int32,
      @display_number : Int32? = nil,
    )
    end
  end

  # Tool search (BM25) - allows Claude to search through available tools
  struct ToolSearchBM25Tool < ServerTool
    include JSON::Serializable

    getter type : String = "tool_search_tool_bm25_20251119"
    getter name : String = "tool_search_tool_bm25"

    def initialize
    end
  end

  # Tool search (Regex) - allows Claude to search through available tools using regex
  struct ToolSearchRegexTool < ServerTool
    include JSON::Serializable

    getter type : String = "tool_search_tool_regex_20251119"
    getter name : String = "tool_search_tool_regex"

    def initialize
    end
  end

  # MCP toolset configuration for controlling individual tool behavior
  struct MCPToolsetConfig
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "defer_loading", emit_null: false)]
    getter defer_loading : Bool?

    def initialize(
      @enabled : Bool? = nil,
      @defer_loading : Bool? = nil,
    )
    end
  end

  # MCP toolset tool — declares an MCP server's tools for the mcp-client beta
  #
  # Used together with `mcp_servers` parameter. Each MCPToolset entry tells the
  # API which MCP server's tools to expose, with optional per-tool configuration.
  #
  # ```
  # message = client.beta.messages.create(
  #   betas: [Anthropic::MCP_CLIENT_BETA],
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 1024,
  #   mcp_servers: [server_def],
  #   server_tools: [Anthropic::MCPToolset.new(mcp_server_name: "my-server")],
  #   messages: [{role: "user", content: "Use my MCP tools"}]
  # )
  # ```
  struct MCPToolset < ServerTool
    include JSON::Serializable

    getter type : String = "mcp_toolset"

    @[JSON::Field(key: "mcp_server_name")]
    getter mcp_server_name : String

    @[JSON::Field(key: "default_config", emit_null: false)]
    getter default_config : MCPToolsetConfig?

    @[JSON::Field(emit_null: false)]
    getter configs : Hash(String, MCPToolsetConfig)?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    def initialize(
      @mcp_server_name : String,
      @default_config : MCPToolsetConfig? = nil,
      @configs : Hash(String, MCPToolsetConfig)? = nil,
      @cache_control : CacheControl? = nil,
    )
    end
  end

  # Union type for all server tools
  alias AnyServerTool = WebSearchTool | CodeExecutionTool | MCPTool |
                        BashTool | TextEditorTool | ComputerUseTool |
                        WebFetchTool | MemoryTool |
                        ToolSearchBM25Tool | ToolSearchRegexTool |
                        MCPToolset |
                        BashToolLegacy | TextEditorToolLegacy | ComputerUseToolLegacy

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

    @[JSON::Field(emit_null: false)]
    getter caller : String?

    def initialize(@id : String, @name : String, @input : JSON::Any, @caller : String? = nil)
    end

    # Parse input into a typed struct
    def input_as(type : T.class) : T forall T
      T.from_json(input.to_json)
    end
  end

  # Code execution tool result content block
  struct CodeExecutionToolResultContent
    include JSON::Serializable

    getter type : String = "code_execution_tool_result"

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter content : JSON::Any

    def initialize(@tool_use_id : String, @content : JSON::Any)
    end
  end

  # Web fetch tool result content block
  struct WebFetchToolResultContent
    include JSON::Serializable

    getter type : String = "web_fetch_tool_result"

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter content : JSON::Any

    def initialize(@tool_use_id : String, @content : JSON::Any)
    end
  end

  # MCP tool use content block (Claude using an MCP tool)
  struct MCPToolUseContent
    include JSON::Serializable

    getter type : String = "mcp_tool_use"
    getter id : String
    getter name : String

    @[JSON::Field(key: "server_name")]
    getter server_name : String

    getter input : JSON::Any

    def initialize(@id : String, @name : String, @server_name : String, @input : JSON::Any)
    end

    # Parse input into a typed struct
    def input_as(type : T.class) : T forall T
      T.from_json(input.to_json)
    end
  end

  # MCP tool result content block
  struct MCPToolResultContent
    include JSON::Serializable

    getter type : String = "mcp_tool_result"

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter content : JSON::Any

    @[JSON::Field(key: "is_error")]
    getter? is_error : Bool

    def initialize(@tool_use_id : String, @content : JSON::Any, @is_error : Bool = false)
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
