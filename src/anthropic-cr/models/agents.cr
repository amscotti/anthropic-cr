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
    getter tools : Array(JSON::Any)?

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

    # Whether there are more pages available
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?
  end
end
