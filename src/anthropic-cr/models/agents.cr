require "json"

module Anthropic
  # Effort level object for Managed Agents model config.
  #
  # API params also accept the bare string form (`"high"`); responses use the
  # object form (`{"type": "high"}`).
  #
  # ```
  # Anthropic::BetaManagedAgentsEffort.high          # => {type: "high"}
  # Anthropic::BetaManagedAgentsEffort.new("medium") # => {type: "medium"}
  # ```
  struct BetaManagedAgentsEffort
    include JSON::Serializable

    # One of `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"`.
    getter type : String

    def initialize(@type : String)
    end

    def self.low : self
      new("low")
    end

    def self.medium : self
      new("medium")
    end

    def self.high : self
      new("high")
    end

    def self.xhigh : self
      new("xhigh")
    end

    def self.max : self
      new("max")
    end
  end

  # Model identifier and configuration for Managed Agents.
  #
  # Used as the `model` parameter on agent create/update (in place of a bare
  # model string) and mirrors the shape returned on agent resources.
  #
  # ```
  # # Bare model string still works on create:
  # client.beta.agents.create(model: :sonnet, name: "Helper")
  #
  # # Or pass a config object for effort / speed control:
  # client.beta.agents.create(
  #   model: Anthropic::BetaManagedAgentsModelConfig.new(
  #     id: :sonnet,
  #     effort: "high",
  #     speed: "fast",
  #   ),
  #   name: "Helper",
  # )
  # ```
  struct BetaManagedAgentsModelConfig
    include JSON::Serializable

    # The model that will power your agent (e.g. `"claude-sonnet-4-6"`).
    getter id : String

    # How hard Claude works on each turn. Params accept a bare level string
    # (`"high"`) or an object (`{"type": "high"}`). On create, omitting it
    # resolves the per-model default; on update, omitting it leaves the stored
    # value unchanged.
    @[JSON::Field(emit_null: false)]
    getter effort : JSON::Any?

    # Inference speed mode: `"standard"` or `"fast"`.
    # `fast` provides significantly faster output token generation at premium
    # pricing. Not all models support `fast`.
    @[JSON::Field(emit_null: false)]
    getter speed : String?

    def initialize(
      id : String | Symbol,
      effort : String | BetaManagedAgentsEffort | JSON::Any | Nil = nil,
      @speed : String? = nil,
    )
      @id = id.is_a?(Symbol) ? Anthropic.model_name(id) : id
      @effort = case effort
                when String
                  JSON::Any.new(effort)
                when BetaManagedAgentsEffort
                  JSON.parse(effort.to_json)
                when JSON::Any
                  effort
                else
                  nil
                end
    end
  end

  # Values accepted for the agent `model` parameter on create/update.
  alias BetaManagedAgentsModelParamLike = String | Symbol | BetaManagedAgentsModelConfig | JSON::Any | Hash(String, JSON::Any)

  # Stateful Managed Agent returned by the Agents API (beta)
  struct BetaAgent
    include JSON::Serializable

    # Unique agent identifier
    getter id : String

    # Human-readable name for the agent
    getter name : String

    # Type of resource (always "agent")
    getter type : String = "agent"

    # Current version number of the agent configuration
    getter version : Int32

    # Description of what the agent does
    getter description : String?

    # Arbitrary key-value metadata attached to the agent
    getter metadata : Hash(String, String)?

    # Model configuration (e.g. model ID, effort, speed)
    getter model : JSON::Any

    # Coordinator topology configurations for multiagent settings
    getter multiagent : JSON::Any?

    # MCP servers this agent connects to
    @[JSON::Field(key: "mcp_servers")]
    getter mcp_servers : Array(JSON::Any)?

    # Skills available to the agent
    getter skills : Array(JSON::Any)?

    # System prompt for the agent
    @[JSON::Field(key: "system")]
    getter system_ : String?

    # Tool configurations available to the agent
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsToolsetArrayConverter)]
    getter tools : Array(BetaManagedAgentsToolset)?

    # Timestamp when the agent was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Timestamp when the agent was last updated
    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Timestamp when the agent was archived, or nil if active
    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  # Response for listing agents
  struct BetaAgentListResponse
    include JSON::Serializable

    # Array of retrieved agents
    getter data : Array(BetaAgent)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Permission policy for tool execution within a toolset.
  struct BetaManagedAgentsPermissionPolicy
    include JSON::Serializable

    getter type : String

    def initialize(@type : String)
    end
  end

  # Permission policy types for toolset tools.
  module BetaManagedAgentsPermissionPolicyType
    ALWAYS_ALLOW = "always_allow"
    ALWAYS_ASK   = "always_ask"
    AUTO         = "auto"
  end

  # Tool names in the `agent_toolset_20260401` toolset.
  module BetaManagedAgentsAgentToolName
    BASH       = "bash"
    EDIT       = "edit"
    READ       = "read"
    WRITE      = "write"
    GLOB       = "glob"
    GREP       = "grep"
    WEB_FETCH  = "web_fetch"
    WEB_SEARCH = "web_search"
  end

  # Approximate user location for location-aware tools.
  struct BetaManagedAgentsUserLocation
    include JSON::Serializable

    getter type : String = "approximate"

    @[JSON::Field(emit_null: false)]
    getter city : String?

    @[JSON::Field(emit_null: false)]
    getter country : String?

    @[JSON::Field(emit_null: false)]
    getter region : String?

    @[JSON::Field(emit_null: false)]
    getter timezone : String?

    def initialize(
      @city : String? = nil,
      @country : String? = nil,
      @region : String? = nil,
      @timezone : String? = nil,
    )
      @type = "approximate"
    end
  end

  # Resolved configuration override for one agent-toolset tool.
  #
  # Upstream models one struct per tool; the shapes are identical except
  # for the web tools, whose extra fields (`allowed_domains`,
  # `blocked_domains`, `max_content_tokens`, `user_location`) live here
  # as optionals so no response data is dropped.
  struct BetaManagedAgentsAgentToolConfig
    include JSON::Serializable

    getter? enabled : Bool
    getter name : String

    @[JSON::Field(key: "permission_policy")]
    getter permission_policy : BetaManagedAgentsPermissionPolicy

    getter type : String

    # Web-fetch / web-search only.
    @[JSON::Field(key: "allowed_domains", emit_null: false)]
    getter allowed_domains : Array(String)?

    @[JSON::Field(key: "blocked_domains", emit_null: false)]
    getter blocked_domains : Array(String)?

    # Web-fetch only.
    @[JSON::Field(key: "max_content_tokens", emit_null: false)]
    getter max_content_tokens : Int32?

    # Web-search only.
    @[JSON::Field(key: "user_location", emit_null: false)]
    getter user_location : BetaManagedAgentsUserLocation?
  end

  # Configuration override for one agent-toolset tool (request).
  struct BetaManagedAgentsAgentToolConfigParams
    include JSON::Serializable

    getter name : String

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "permission_policy", emit_null: false)]
    getter permission_policy : BetaManagedAgentsPermissionPolicy?

    @[JSON::Field(emit_null: false)]
    getter type : String?

    # Web-fetch / web-search only.
    @[JSON::Field(key: "allowed_domains", emit_null: false)]
    getter allowed_domains : Array(String)?

    @[JSON::Field(key: "blocked_domains", emit_null: false)]
    getter blocked_domains : Array(String)?

    # Web-fetch only.
    @[JSON::Field(key: "max_content_tokens", emit_null: false)]
    getter max_content_tokens : Int32?

    # Web-search only.
    @[JSON::Field(key: "user_location", emit_null: false)]
    getter user_location : BetaManagedAgentsUserLocation?

    def initialize(
      @name : String,
      @enabled : Bool? = nil,
      @permission_policy : BetaManagedAgentsPermissionPolicy? = nil,
      @type : String? = nil,
      @allowed_domains : Array(String)? = nil,
      @blocked_domains : Array(String)? = nil,
      @max_content_tokens : Int32? = nil,
      @user_location : BetaManagedAgentsUserLocation? = nil,
    )
    end
  end

  # Resolved configuration override for one MCP tool.
  struct BetaManagedAgentsMCPToolConfig
    include JSON::Serializable

    getter? enabled : Bool
    getter name : String

    @[JSON::Field(key: "permission_policy")]
    getter permission_policy : BetaManagedAgentsPermissionPolicy
  end

  # Configuration override for one MCP tool (request).
  struct BetaManagedAgentsMCPToolConfigParams
    include JSON::Serializable

    getter name : String

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "permission_policy", emit_null: false)]
    getter permission_policy : BetaManagedAgentsPermissionPolicy?

    def initialize(
      @name : String,
      @enabled : Bool? = nil,
      @permission_policy : BetaManagedAgentsPermissionPolicy? = nil,
    )
    end
  end

  # Resolved default configuration for all tools in a toolset.
  struct BetaManagedAgentsToolsetDefaultConfig
    include JSON::Serializable

    getter? enabled : Bool

    @[JSON::Field(key: "permission_policy")]
    getter permission_policy : BetaManagedAgentsPermissionPolicy
  end

  # Default configuration for all tools in a toolset (request).
  struct BetaManagedAgentsToolsetDefaultConfigParams
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "permission_policy", emit_null: false)]
    getter permission_policy : BetaManagedAgentsPermissionPolicy?

    def initialize(
      @enabled : Bool? = nil,
      @permission_policy : BetaManagedAgentsPermissionPolicy? = nil,
    )
    end
  end

  # The built-in agent toolset (response).
  struct BetaManagedAgentsAgentToolset20260401
    include JSON::Serializable

    getter configs : Array(BetaManagedAgentsAgentToolConfig)

    @[JSON::Field(key: "default_config")]
    getter default_config : BetaManagedAgentsToolsetDefaultConfig

    getter type : String = "agent_toolset_20260401"
  end

  # The built-in agent toolset (request).
  struct BetaManagedAgentsAgentToolset20260401Params
    include JSON::Serializable

    getter type : String = "agent_toolset_20260401"

    @[JSON::Field(emit_null: false)]
    getter configs : Array(BetaManagedAgentsAgentToolConfigParams)?

    @[JSON::Field(key: "default_config", emit_null: false)]
    getter default_config : BetaManagedAgentsToolsetDefaultConfigParams?

    def initialize(
      @configs : Array(BetaManagedAgentsAgentToolConfigParams)? = nil,
      @default_config : BetaManagedAgentsToolsetDefaultConfigParams? = nil,
    )
      @type = "agent_toolset_20260401"
    end
  end

  # An MCP-server toolset (response).
  struct BetaManagedAgentsMCPToolset
    include JSON::Serializable

    getter configs : Array(BetaManagedAgentsMCPToolConfig)

    @[JSON::Field(key: "default_config")]
    getter default_config : BetaManagedAgentsToolsetDefaultConfig

    @[JSON::Field(key: "mcp_server_name")]
    getter mcp_server_name : String

    getter type : String = "mcp_toolset"
  end

  # An MCP-server toolset (request).
  struct BetaManagedAgentsMCPToolsetParams
    include JSON::Serializable

    @[JSON::Field(key: "mcp_server_name")]
    getter mcp_server_name : String

    getter type : String = "mcp_toolset"

    @[JSON::Field(emit_null: false)]
    getter configs : Array(BetaManagedAgentsMCPToolConfigParams)?

    @[JSON::Field(key: "default_config", emit_null: false)]
    getter default_config : BetaManagedAgentsToolsetDefaultConfigParams?

    def initialize(
      @mcp_server_name : String,
      @configs : Array(BetaManagedAgentsMCPToolConfigParams)? = nil,
      @default_config : BetaManagedAgentsToolsetDefaultConfigParams? = nil,
    )
      @type = "mcp_toolset"
    end
  end

  # Input schema for a user-defined custom tool.
  struct BetaManagedAgentsCustomToolInputSchema
    include JSON::Serializable

    getter type : String = "object"

    @[JSON::Field(emit_null: false)]
    getter properties : Hash(String, JSON::Any)?

    @[JSON::Field(emit_null: false)]
    getter required : Array(String)?

    def initialize(
      @properties : Hash(String, JSON::Any)? = nil,
      @required : Array(String)? = nil,
    )
      @type = "object"
    end
  end

  # A user-defined custom tool attached to an agent. The wire shape is
  # identical on requests and responses, so one struct serves both.
  struct BetaManagedAgentsCustomTool
    include JSON::Serializable

    getter description : String

    @[JSON::Field(key: "input_schema")]
    getter input_schema : BetaManagedAgentsCustomToolInputSchema

    getter name : String
    getter type : String = "custom"

    def initialize(
      @description : String,
      @input_schema : BetaManagedAgentsCustomToolInputSchema,
      @name : String,
    )
      @type = "custom"
    end
  end

  # A toolset attached to an agent.
  alias BetaManagedAgentsToolset = BetaManagedAgentsAgentToolset20260401 | BetaManagedAgentsMCPToolset | BetaManagedAgentsCustomTool

  # A toolset to attach to an agent (request).
  alias BetaManagedAgentsToolsetParam = BetaManagedAgentsAgentToolset20260401Params | BetaManagedAgentsMCPToolsetParams | BetaManagedAgentsCustomTool

  # Discriminated-union converter for toolsets.
  module BetaManagedAgentsToolsetConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsToolset
      json = JSON::Any.new(pull)
      raw = json.to_json

      case json["type"]?.try(&.as_s?)
      when "mcp_toolset"
        BetaManagedAgentsMCPToolset.from_json(raw)
      when "custom"
        BetaManagedAgentsCustomTool.from_json(raw)
      when "agent_toolset_20260401"
        BetaManagedAgentsAgentToolset20260401.from_json(raw)
      else
        raise JSON::ParseException.new("Unknown toolset type: #{json["type"]?}", 0, 0)
      end
    end

    def self.to_json(value : BetaManagedAgentsToolset, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Array converter for toolsets discriminated by `"type"`.
  module BetaManagedAgentsToolsetArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaManagedAgentsToolset)?
      return nil if pull.kind.null?

      result = [] of BetaManagedAgentsToolset
      pull.read_array do
        result << BetaManagedAgentsToolsetConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BetaManagedAgentsToolset)?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        builder.array do
          value.each &.to_json(builder)
        end
      end
    end
  end
end
