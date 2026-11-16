require "json"

module Anthropic
  # Model identifiers supported by Managed Agents.
  module BetaManagedAgentsModel
    CLAUDE_FABLE_5_2           = "claude-fable-5-2"
    CLAUDE_HAIKU_5_5           = "claude-haiku-5-5"
    CLAUDE_SONNET_5_5          = "claude-sonnet-5-5"
    CLAUDE_OPUS_5_5            = "claude-opus-5-5"
    CLAUDE_FABLE_5_1           = "claude-fable-5-1"
    CLAUDE_SONNET_5            = "claude-sonnet-5"
    CLAUDE_FABLE_5             = "claude-fable-5"
    CLAUDE_OPUS_5              = "claude-opus-5"
    CLAUDE_OPUS_4_8            = "claude-opus-4-8"
    CLAUDE_OPUS_4_7            = "claude-opus-4-7"
    CLAUDE_OPUS_4_6            = "claude-opus-4-6"
    CLAUDE_SONNET_4_6          = "claude-sonnet-4-6"
    CLAUDE_HAIKU_4_5           = "claude-haiku-4-5"
    CLAUDE_HAIKU_4_5_20251001  = "claude-haiku-4-5-20251001"
    CLAUDE_OPUS_4_5            = "claude-opus-4-5"
    CLAUDE_OPUS_4_5_20251101   = "claude-opus-4-5-20251101"
    CLAUDE_SONNET_4_5          = "claude-sonnet-4-5"
    CLAUDE_SONNET_4_5_20250929 = "claude-sonnet-4-5-20250929"
  end

  # Service-account execution identity for Managed Agents.
  struct BetaManagedAgentsServiceAccountExecutionIdentity
    include JSON::Serializable

    getter type : String = "service_account"

    def initialize(@type : String = "service_account")
    end
  end

  # AWS IAM role execution identity for Managed Agents.
  struct BetaManagedAgentsAWSRoleExecutionIdentity
    include JSON::Serializable

    @[JSON::Field(key: "role_arn")]
    getter role_arn : String

    getter type : String = "aws_role"

    def initialize(@role_arn : String, @type : String = "aws_role")
    end
  end

  # Forward-compatible fallback for unrecognized execution identity types.
  struct GenericBetaManagedAgentsExecutionIdentity
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  # Execution principal for a Managed Agent or thread.
  alias BetaManagedAgentsExecutionIdentity = BetaManagedAgentsServiceAccountExecutionIdentity | BetaManagedAgentsAWSRoleExecutionIdentity | GenericBetaManagedAgentsExecutionIdentity

  alias BetaManagedAgentsServiceAccountExecutionIdentityParams = BetaManagedAgentsServiceAccountExecutionIdentity
  alias BetaManagedAgentsAWSRoleExecutionIdentityParams = BetaManagedAgentsAWSRoleExecutionIdentity
  alias BetaManagedAgentsExecutionIdentityParams = BetaManagedAgentsServiceAccountExecutionIdentity | BetaManagedAgentsAWSRoleExecutionIdentity
  alias BetaManagedAgentsExecutionIdentityParamLike = BetaManagedAgentsExecutionIdentityParams | JSON::Any | Hash(String, JSON::Any)

  # Discriminated-union converter for `execution_identity`.
  module BetaManagedAgentsExecutionIdentityConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsExecutionIdentity?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "service_account"
        BetaManagedAgentsServiceAccountExecutionIdentity.from_json(raw)
      when "aws_role"
        BetaManagedAgentsAWSRoleExecutionIdentity.from_json(raw)
      else
        GenericBetaManagedAgentsExecutionIdentity.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsExecutionIdentity?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Reference to a saved agent by ID and version.
  struct BetaManagedAgentsAgentReference
    include JSON::Serializable

    getter id : String
    getter type : String = "agent"
    getter version : Int32

    def initialize(@id : String, @version : Int32, @type : String = "agent")
    end
  end

  # Advisor model entry in a multiagent configuration.
  struct BetaManagedAgentsAdvisor
    include JSON::Serializable

    getter model : String
    getter type : String = "advisor"

    def initialize(model : String | Symbol, @type : String = "advisor")
      @model = model.is_a?(Symbol) ? Anthropic.model_name(model) : model
    end
  end

  alias BetaManagedAgentsAdvisorParams = BetaManagedAgentsAdvisor

  # Self reference in a multiagent predefined-agents or coordinator roster.
  struct BetaManagedAgentsMultiagentSelfParams
    include JSON::Serializable

    getter type : String = "self"

    def initialize(@type : String = "self")
    end
  end

  # Forward-compatible fallback for unrecognized multiagent sub-option shapes.
  struct GenericBetaManagedAgentsMultiagentOption
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsMultiagentCoordinatorAgent = BetaManagedAgentsAgentReference | BetaManagedAgentsAdvisor | GenericBetaManagedAgentsMultiagentOption

  module BetaManagedAgentsMultiagentCoordinatorAgentArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaManagedAgentsMultiagentCoordinatorAgent)
      result = [] of BetaManagedAgentsMultiagentCoordinatorAgent
      pull.read_array do
        json = JSON::Any.new(pull)
        type = json["type"]?.try(&.as_s?) || "unknown"
        raw = json.to_json
        result << case type
        when "agent"
          BetaManagedAgentsAgentReference.from_json(raw)
        when "advisor"
          BetaManagedAgentsAdvisor.from_json(raw)
        else
          GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
        end
      end
      result
    end

    def self.to_json(value : Array(BetaManagedAgentsMultiagentCoordinatorAgent), builder : JSON::Builder) : Nil
      builder.array do
        value.each &.to_json(builder)
      end
    end
  end

  # Coordinator multiagent topology (response).
  struct BetaManagedAgentsMultiagentCoordinator
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentCoordinatorAgentArrayConverter)]
    getter agents : Array(BetaManagedAgentsMultiagentCoordinatorAgent)

    getter type : String = "coordinator"
  end

  alias BetaManagedAgentsMultiagentRosterEntryParams = String | BetaManagedAgentsAgentParam | BetaManagedAgentsMultiagentSelfParams | BetaManagedAgentsAdvisor | JSON::Any | Hash(String, JSON::Any)

  # Coordinator multiagent topology (request).
  struct BetaManagedAgentsMultiagentCoordinatorParams
    include JSON::Serializable

    getter agents : Array(BetaManagedAgentsMultiagentRosterEntryParams)
    getter type : String = "coordinator"

    def initialize(
      agents : Enumerable(BetaManagedAgentsMultiagentRosterEntryParams),
      @type : String = "coordinator",
    )
      @agents = agents.map(&.as(BetaManagedAgentsMultiagentRosterEntryParams))
    end
  end

  # Advisor enabled option for `multiagent_20261001`.
  struct BetaManagedAgentsMultiagentAdvisorEnabled
    include JSON::Serializable

    getter model : String
    getter type : String = "enabled"

    def initialize(model : String | Symbol, @type : String = "enabled")
      @model = model.is_a?(Symbol) ? Anthropic.model_name(model) : model
    end
  end

  # Advisor disabled option for `multiagent_20261001`.
  struct BetaManagedAgentsMultiagentAdvisorDisabled
    include JSON::Serializable

    getter type : String = "disabled"

    def initialize(@type : String = "disabled")
    end
  end

  alias BetaManagedAgentsMultiagentAdvisorEnabledParams = BetaManagedAgentsMultiagentAdvisorEnabled
  alias BetaManagedAgentsMultiagentAdvisorDisabledParams = BetaManagedAgentsMultiagentAdvisorDisabled
  alias BetaManagedAgentsMultiagentAdvisor = BetaManagedAgentsMultiagentAdvisorEnabled | BetaManagedAgentsMultiagentAdvisorDisabled | GenericBetaManagedAgentsMultiagentOption
  alias BetaManagedAgentsMultiagentAdvisorParams = BetaManagedAgentsMultiagentAdvisorEnabled | BetaManagedAgentsMultiagentAdvisorDisabled | JSON::Any | Hash(String, JSON::Any)

  module BetaManagedAgentsMultiagentAdvisorConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsMultiagentAdvisor
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json
      case type
      when "enabled"
        BetaManagedAgentsMultiagentAdvisorEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentAdvisorDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsMultiagentAdvisor, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Inline agents enabled option for `subagents` / `workflows`.
  struct BetaManagedAgentsMultiagentInlineAgentsEnabled
    include JSON::Serializable

    getter type : String = "enabled"

    def initialize(@type : String = "enabled")
    end
  end

  # Inline agents disabled option for `subagents` / `workflows`.
  struct BetaManagedAgentsMultiagentInlineAgentsDisabled
    include JSON::Serializable

    getter type : String = "disabled"

    def initialize(@type : String = "disabled")
    end
  end

  alias BetaManagedAgentsMultiagentInlineAgentsEnabledParams = BetaManagedAgentsMultiagentInlineAgentsEnabled
  alias BetaManagedAgentsMultiagentInlineAgentsDisabledParams = BetaManagedAgentsMultiagentInlineAgentsDisabled
  alias BetaManagedAgentsMultiagentInlineAgents = BetaManagedAgentsMultiagentInlineAgentsEnabled | BetaManagedAgentsMultiagentInlineAgentsDisabled | GenericBetaManagedAgentsMultiagentOption
  alias BetaManagedAgentsMultiagentInlineAgentsParams = BetaManagedAgentsMultiagentInlineAgentsEnabled | BetaManagedAgentsMultiagentInlineAgentsDisabled | JSON::Any | Hash(String, JSON::Any)

  module BetaManagedAgentsMultiagentInlineAgentsConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsMultiagentInlineAgents
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json
      case type
      when "enabled"
        BetaManagedAgentsMultiagentInlineAgentsEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentInlineAgentsDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsMultiagentInlineAgents, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Subagents enabled configuration on an agent (response).
  struct BetaManagedAgentsMultiagentSubagentsEnabled
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", converter: Anthropic::BetaManagedAgentsMultiagentInlineAgentsConverter)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgents

    @[JSON::Field(key: "predefined_agents")]
    getter predefined_agents : Array(BetaManagedAgentsAgentReference)

    getter type : String = "enabled"
  end

  # Subagents disabled configuration.
  struct BetaManagedAgentsMultiagentSubagentsDisabled
    include JSON::Serializable

    getter type : String = "disabled"

    def initialize(@type : String = "disabled")
    end
  end

  alias BetaManagedAgentsMultiagentSubagentsDisabledParams = BetaManagedAgentsMultiagentSubagentsDisabled
  alias BetaManagedAgentsMultiagentSubagents = BetaManagedAgentsMultiagentSubagentsEnabled | BetaManagedAgentsMultiagentSubagentsDisabled | GenericBetaManagedAgentsMultiagentOption

  module BetaManagedAgentsMultiagentSubagentsConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsMultiagentSubagents
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json
      case type
      when "enabled"
        BetaManagedAgentsMultiagentSubagentsEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentSubagentsDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsMultiagentSubagents, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  alias BetaManagedAgentsMultiagentPredefinedAgentParams = String | BetaManagedAgentsAgentParam | BetaManagedAgentsMultiagentSelfParams | JSON::Any | Hash(String, JSON::Any)

  # Subagents enabled configuration on an agent (request).
  struct BetaManagedAgentsMultiagentSubagentsEnabledParams
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", emit_null: false)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgentsParams? = nil

    @[JSON::Field(key: "predefined_agents", emit_null: false)]
    getter predefined_agents : Array(BetaManagedAgentsMultiagentPredefinedAgentParams)? = nil

    getter type : String = "enabled"

    def initialize(
      @inline_agents : BetaManagedAgentsMultiagentInlineAgentsParams? = nil,
      predefined_agents : Enumerable(BetaManagedAgentsMultiagentPredefinedAgentParams)? = nil,
      @type : String = "enabled",
    )
      @predefined_agents = predefined_agents.try(&.map(&.as(BetaManagedAgentsMultiagentPredefinedAgentParams)))
    end
  end

  alias BetaManagedAgentsMultiagentSubagentsParams = BetaManagedAgentsMultiagentSubagentsEnabledParams | BetaManagedAgentsMultiagentSubagentsDisabled | JSON::Any | Hash(String, JSON::Any)

  # Workflows enabled configuration on an agent (response).
  struct BetaManagedAgentsMultiagentWorkflowsEnabled
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", converter: Anthropic::BetaManagedAgentsMultiagentInlineAgentsConverter)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgents

    @[JSON::Field(key: "predefined_agents")]
    getter predefined_agents : Array(BetaManagedAgentsAgentReference)

    getter type : String = "enabled"
  end

  # Workflows disabled configuration.
  struct BetaManagedAgentsMultiagentWorkflowsDisabled
    include JSON::Serializable

    getter type : String = "disabled"

    def initialize(@type : String = "disabled")
    end
  end

  alias BetaManagedAgentsMultiagentWorkflowsDisabledParams = BetaManagedAgentsMultiagentWorkflowsDisabled
  alias BetaManagedAgentsMultiagentWorkflows = BetaManagedAgentsMultiagentWorkflowsEnabled | BetaManagedAgentsMultiagentWorkflowsDisabled | GenericBetaManagedAgentsMultiagentOption

  module BetaManagedAgentsMultiagentWorkflowsConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsMultiagentWorkflows
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json
      case type
      when "enabled"
        BetaManagedAgentsMultiagentWorkflowsEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentWorkflowsDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsMultiagentWorkflows, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Workflows enabled configuration on an agent (request).
  struct BetaManagedAgentsMultiagentWorkflowsEnabledParams
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", emit_null: false)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgentsParams? = nil

    @[JSON::Field(key: "predefined_agents", emit_null: false)]
    getter predefined_agents : Array(BetaManagedAgentsMultiagentPredefinedAgentParams)? = nil

    getter type : String = "enabled"

    def initialize(
      @inline_agents : BetaManagedAgentsMultiagentInlineAgentsParams? = nil,
      predefined_agents : Enumerable(BetaManagedAgentsMultiagentPredefinedAgentParams)? = nil,
      @type : String = "enabled",
    )
      @predefined_agents = predefined_agents.try(&.map(&.as(BetaManagedAgentsMultiagentPredefinedAgentParams)))
    end
  end

  alias BetaManagedAgentsMultiagentWorkflowsParams = BetaManagedAgentsMultiagentWorkflowsEnabledParams | BetaManagedAgentsMultiagentWorkflowsDisabled | JSON::Any | Hash(String, JSON::Any)

  # `multiagent_20261001` configuration on an agent (response).
  struct BetaManagedAgentsMultiagent20261001
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentAdvisorConverter)]
    getter advisor : BetaManagedAgentsMultiagentAdvisor

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentSubagentsConverter)]
    getter subagents : BetaManagedAgentsMultiagentSubagents

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentWorkflowsConverter)]
    getter workflows : BetaManagedAgentsMultiagentWorkflows

    getter type : String = "multiagent_20261001"
  end

  # `multiagent_20261001` configuration on an agent (request).
  struct BetaManagedAgentsMultiagent20261001Params
    include JSON::Serializable

    getter type : String = "multiagent_20261001"

    @[JSON::Field(emit_null: false)]
    getter advisor : BetaManagedAgentsMultiagentAdvisorParams? = nil

    @[JSON::Field(emit_null: false)]
    getter subagents : BetaManagedAgentsMultiagentSubagentsParams? = nil

    @[JSON::Field(emit_null: false)]
    getter workflows : BetaManagedAgentsMultiagentWorkflowsParams? = nil

    def initialize(
      @advisor : BetaManagedAgentsMultiagentAdvisorParams? = nil,
      @subagents : BetaManagedAgentsMultiagentSubagentsParams? = nil,
      @workflows : BetaManagedAgentsMultiagentWorkflowsParams? = nil,
      @type : String = "multiagent_20261001",
    )
    end
  end

  # Forward-compatible fallback for unrecognized multiagent configurations.
  struct GenericBetaManagedAgentsMultiagent
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsMultiagent = BetaManagedAgentsMultiagentCoordinator | BetaManagedAgentsMultiagent20261001 | GenericBetaManagedAgentsMultiagent
  alias BetaManagedAgentsMultiagentParams = BetaManagedAgentsMultiagentCoordinatorParams | BetaManagedAgentsMultiagent20261001Params
  alias BetaManagedAgentsMultiagentParamLike = BetaManagedAgentsMultiagentParams | JSON::Any | Hash(String, JSON::Any)

  module BetaManagedAgentsMultiagentConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsMultiagent?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "coordinator"
        BetaManagedAgentsMultiagentCoordinator.from_json(raw)
      when "multiagent_20261001"
        BetaManagedAgentsMultiagent20261001.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagent.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsMultiagent?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

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

    # Execution identity for the agent (`service_account` or `aws_role`)
    @[JSON::Field(key: "execution_identity", converter: Anthropic::BetaManagedAgentsExecutionIdentityConverter, emit_null: false)]
    getter execution_identity : BetaManagedAgentsExecutionIdentity? = nil

    # Multiagent topology configuration (`coordinator` or `multiagent_20261001`)
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentConverter, emit_null: false)]
    getter multiagent : BetaManagedAgentsMultiagent? = nil

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

  alias BetaManagedAgentsAgent = BetaAgent

  # Response for listing agents
  struct BetaAgentListResponse
    include JSON::Serializable
    include PageCursorMethods

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

  # Shorthand values for `BetaManagedAgentsWebFetchURLSourcesParams` filters.
  module BetaManagedAgentsWebFetchURLSourceShorthand
    ALL  = "all"
    NONE = "none"
  end

  # Tool reference in Managed Agents `web_fetch` `url_sources` (`only` / `except`).
  struct BetaManagedAgentsWebFetchURLSourceToolReference
    include JSON::Serializable

    getter name : String
    getter type : String = "tool_reference"

    def initialize(@name : String, @type : String = "tool_reference")
    end
  end

  # Allow URLs from all sources in a category for Managed Agents `web_fetch`.
  struct BetaManagedAgentsWebFetchURLSourceAll
    include JSON::Serializable

    getter type : String = "all"

    def initialize(@type : String = "all")
    end
  end

  # Allow no URLs from a category for Managed Agents `web_fetch`.
  struct BetaManagedAgentsWebFetchURLSourceNone
    include JSON::Serializable

    getter type : String = "none"

    def initialize(@type : String = "none")
    end
  end

  # Allow URLs only from the named tools for Managed Agents `web_fetch`.
  struct BetaManagedAgentsWebFetchURLSourceOnly
    include JSON::Serializable

    getter tools : Array(BetaManagedAgentsWebFetchURLSourceToolReference)
    getter type : String = "only"

    def initialize(@tools : Array(BetaManagedAgentsWebFetchURLSourceToolReference), @type : String = "only")
    end

    def self.tools(*names : String) : self
      new(names.map { |name| BetaManagedAgentsWebFetchURLSourceToolReference.new(name) }.to_a)
    end
  end

  # Allow URLs from all tools except the named ones for Managed Agents `web_fetch`.
  struct BetaManagedAgentsWebFetchURLSourceExcept
    include JSON::Serializable

    getter tools : Array(BetaManagedAgentsWebFetchURLSourceToolReference)
    getter type : String = "except"

    def initialize(@tools : Array(BetaManagedAgentsWebFetchURLSourceToolReference), @type : String = "except")
    end

    def self.tools(*names : String) : self
      new(names.map { |name| BetaManagedAgentsWebFetchURLSourceToolReference.new(name) }.to_a)
    end
  end

  alias BetaManagedAgentsWebFetchURLSourceToolFilter = BetaManagedAgentsWebFetchURLSourceAll | BetaManagedAgentsWebFetchURLSourceNone | BetaManagedAgentsWebFetchURLSourceOnly | BetaManagedAgentsWebFetchURLSourceExcept
  alias BetaManagedAgentsWebFetchURLSourceUserInput = BetaManagedAgentsWebFetchURLSourceAll | BetaManagedAgentsWebFetchURLSourceNone

  # Converter for Managed Agents `client_tool_results` / `server_tool_results`
  # accepting either scope objects or `"all"`/`"none"` shorthands.
  module BetaManagedAgentsWebFetchURLSourceScopeConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsWebFetchURLSourceToolFilter?
      case pull.kind
      when .null?
        pull.read_null
        nil
      when .string?
        case value = pull.read_string
        when "all"  then BetaManagedAgentsWebFetchURLSourceAll.new
        when "none" then BetaManagedAgentsWebFetchURLSourceNone.new
        else
          raise JSON::ParseException.new(
            "Unknown web-fetch URL source shorthand: #{value.inspect}",
            pull.line_number,
            pull.column_number
          )
        end
      else
        json = JSON::Any.new(pull)
        type = json["type"]?.try(&.as_s?)
        raw = json.to_json
        case type
        when "all"    then BetaManagedAgentsWebFetchURLSourceAll.from_json(raw)
        when "none"   then BetaManagedAgentsWebFetchURLSourceNone.from_json(raw)
        when "only"   then BetaManagedAgentsWebFetchURLSourceOnly.from_json(raw)
        when "except" then BetaManagedAgentsWebFetchURLSourceExcept.from_json(raw)
        else
          raise JSON::ParseException.new(
            "Unknown web-fetch URL source scope type: #{type.inspect}",
            pull.line_number,
            pull.column_number
          )
        end
      end
    end

    def self.to_json(value : BetaManagedAgentsWebFetchURLSourceToolFilter?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Converter for Managed Agents `user_input` scope accepting objects or `"all"`/`"none"`.
  module BetaManagedAgentsWebFetchUserInputScopeConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsWebFetchURLSourceUserInput?
      case pull.kind
      when .null?
        pull.read_null
        nil
      when .string?
        case value = pull.read_string
        when "all"  then BetaManagedAgentsWebFetchURLSourceAll.new
        when "none" then BetaManagedAgentsWebFetchURLSourceNone.new
        else
          raise JSON::ParseException.new(
            "Unknown web-fetch user-input shorthand: #{value.inspect}",
            pull.line_number,
            pull.column_number
          )
        end
      else
        json = JSON::Any.new(pull)
        type = json["type"]?.try(&.as_s?)
        raw = json.to_json
        case type
        when "all"  then BetaManagedAgentsWebFetchURLSourceAll.from_json(raw)
        when "none" then BetaManagedAgentsWebFetchURLSourceNone.from_json(raw)
        else
          raise JSON::ParseException.new(
            "Unknown web-fetch user-input scope type: #{type.inspect}",
            pull.line_number,
            pull.column_number
          )
        end
      end
    end

    def self.to_json(value : BetaManagedAgentsWebFetchURLSourceUserInput?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Resolved URL-source filters for Managed Agents `web_fetch` tool config.
  struct BetaManagedAgentsWebFetchURLSources
    include JSON::Serializable

    @[JSON::Field(key: "client_tool_results", converter: Anthropic::BetaManagedAgentsWebFetchURLSourceScopeConverter, emit_null: false)]
    getter client_tool_results : BetaManagedAgentsWebFetchURLSourceToolFilter? = nil

    @[JSON::Field(key: "server_tool_results", converter: Anthropic::BetaManagedAgentsWebFetchURLSourceScopeConverter, emit_null: false)]
    getter server_tool_results : BetaManagedAgentsWebFetchURLSourceToolFilter? = nil

    @[JSON::Field(key: "user_input", converter: Anthropic::BetaManagedAgentsWebFetchUserInputScopeConverter, emit_null: false)]
    getter user_input : BetaManagedAgentsWebFetchURLSourceUserInput? = nil

    def initialize(
      @client_tool_results : BetaManagedAgentsWebFetchURLSourceToolFilter? = nil,
      @server_tool_results : BetaManagedAgentsWebFetchURLSourceToolFilter? = nil,
      @user_input : BetaManagedAgentsWebFetchURLSourceUserInput? = nil,
    )
    end
  end

  alias BetaManagedAgentsWebFetchURLSourceToolFilterParam = String | BetaManagedAgentsWebFetchURLSourceToolFilter
  alias BetaManagedAgentsWebFetchURLSourceUserInputParam = String | BetaManagedAgentsWebFetchURLSourceUserInput

  # Request parameters for Managed Agents `web_fetch` `url_sources`.
  # Accepts either scope structs (`BetaManagedAgentsWebFetchURLSourceAll`,
  # `BetaManagedAgentsWebFetchURLSourceOnly`, etc.), `WebFetchURLSource*`,
  # or the shorthand strings `"all"` / `"none"`.
  struct BetaManagedAgentsWebFetchURLSourcesParams
    include JSON::Serializable

    @[JSON::Field(key: "client_tool_results", emit_null: false)]
    getter client_tool_results : JSON::Any? = nil

    @[JSON::Field(key: "server_tool_results", emit_null: false)]
    getter server_tool_results : JSON::Any? = nil

    @[JSON::Field(key: "user_input", emit_null: false)]
    getter user_input : JSON::Any? = nil

    def initialize(
      client_tool_results = nil,
      server_tool_results = nil,
      user_input = nil,
    )
      @client_tool_results = client_tool_results.nil? ? nil : JSON.parse(client_tool_results.to_json)
      @server_tool_results = server_tool_results.nil? ? nil : JSON.parse(server_tool_results.to_json)
      @user_input = user_input.nil? ? nil : JSON.parse(user_input.to_json)
    end
  end

  alias BetaManagedAgentsWebFetchURLSourcesParamLike = BetaManagedAgentsWebFetchURLSourcesParams | BetaManagedAgentsWebFetchURLSources | JSON::Any

  # Resolved configuration override for one agent-toolset tool.
  #
  # Upstream models one struct per tool; the shapes are identical except
  # for the web tools, whose extra fields (`allowed_domains`,
  # `blocked_domains`, `max_content_tokens`, `url_sources`, `user_location`)
  # live here as optionals so no response data is dropped.
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

    # Web-fetch only.
    @[JSON::Field(key: "url_sources", emit_null: false)]
    getter url_sources : BetaManagedAgentsWebFetchURLSources? = nil

    # Web-search only.
    @[JSON::Field(key: "user_location", emit_null: false)]
    getter user_location : BetaManagedAgentsUserLocation?
  end

  alias BetaManagedAgentsWebFetchToolConfig = BetaManagedAgentsAgentToolConfig

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

    # Web-fetch only.
    @[JSON::Field(key: "url_sources", emit_null: false)]
    getter url_sources : JSON::Any? = nil

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
      url_sources : BetaManagedAgentsWebFetchURLSourcesParamLike | WebFetchURLSources | Nil = nil,
      @user_location : BetaManagedAgentsUserLocation? = nil,
    )
      @url_sources = url_sources.nil? ? nil : JSON.parse(url_sources.to_json)
    end
  end

  # Dedicated request params struct for `web_fetch` agent-toolset overrides.
  struct BetaManagedAgentsWebFetchToolConfigParams
    include JSON::Serializable

    getter name : String = BetaManagedAgentsAgentToolName::WEB_FETCH

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool? = nil

    @[JSON::Field(key: "permission_policy", emit_null: false)]
    getter permission_policy : BetaManagedAgentsPermissionPolicy? = nil

    @[JSON::Field(emit_null: false)]
    getter type : String? = BetaManagedAgentsAgentToolName::WEB_FETCH

    @[JSON::Field(key: "allowed_domains", emit_null: false)]
    getter allowed_domains : Array(String)? = nil

    @[JSON::Field(key: "blocked_domains", emit_null: false)]
    getter blocked_domains : Array(String)? = nil

    @[JSON::Field(key: "max_content_tokens", emit_null: false)]
    getter max_content_tokens : Int32? = nil

    @[JSON::Field(key: "url_sources", emit_null: false)]
    getter url_sources : JSON::Any? = nil

    def initialize(
      @enabled : Bool? = nil,
      @permission_policy : BetaManagedAgentsPermissionPolicy? = nil,
      @allowed_domains : Array(String)? = nil,
      @blocked_domains : Array(String)? = nil,
      @max_content_tokens : Int32? = nil,
      url_sources : BetaManagedAgentsWebFetchURLSourcesParamLike | WebFetchURLSources | Nil = nil,
      @type : String? = BetaManagedAgentsAgentToolName::WEB_FETCH,
      @name : String = BetaManagedAgentsAgentToolName::WEB_FETCH,
    )
      @url_sources = url_sources.nil? ? nil : JSON.parse(url_sources.to_json)
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

  alias BetaManagedAgentsAgentToolConfigParam = BetaManagedAgentsAgentToolConfigParams | BetaManagedAgentsWebFetchToolConfigParams

  # The built-in agent toolset (request).
  struct BetaManagedAgentsAgentToolset20260401Params
    include JSON::Serializable

    getter type : String = "agent_toolset_20260401"

    @[JSON::Field(emit_null: false)]
    getter configs : Array(BetaManagedAgentsAgentToolConfigParam)?

    @[JSON::Field(key: "default_config", emit_null: false)]
    getter default_config : BetaManagedAgentsToolsetDefaultConfigParams?

    def initialize(
      configs : Enumerable(BetaManagedAgentsAgentToolConfigParam)? = nil,
      @default_config : BetaManagedAgentsToolsetDefaultConfigParams? = nil,
    )
      @configs = configs.try(&.map(&.as(BetaManagedAgentsAgentToolConfigParam)))
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

  alias BetaManagedAgentsCustomToolParams = BetaManagedAgentsCustomTool

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
