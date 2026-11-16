module Anthropic
  struct BetaManagedAgentsAgentParam
    include JSON::Serializable

    getter id : String
    getter type : String = "agent"

    @[JSON::Field(emit_null: false)]
    getter version : Int32?

    def initialize(@id : String, @version : Int32? = nil)
    end
  end

  alias BetaManagedAgentsAgentParamLike = String | BetaManagedAgentsAgentParam | JSON::Any | Hash(String, JSON::Any)

  struct BetaManagedAgentsBranchCheckoutParam
    include JSON::Serializable

    getter name : String
    getter type : String = "branch"

    def initialize(@name : String)
    end
  end

  struct BetaManagedAgentsCommitCheckoutParam
    include JSON::Serializable

    getter sha : String
    getter type : String = "commit"

    def initialize(@sha : String)
    end
  end

  alias BetaManagedAgentsCheckoutParam = BetaManagedAgentsBranchCheckoutParam | BetaManagedAgentsCommitCheckoutParam

  # Discriminated-union converter for branch/commit checkouts.
  module BetaManagedAgentsCheckoutConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsCheckoutParam?
      return nil if pull.kind.null?

      json = JSON::Any.new(pull)
      raw = json.to_json

      case json["type"]?.try(&.as_s?)
      when "commit"
        BetaManagedAgentsCommitCheckoutParam.from_json(raw)
      when "branch", nil
        BetaManagedAgentsBranchCheckoutParam.from_json(raw)
      else
        raise JSON::ParseException.new("Unknown checkout type: #{json["type"]?}", 0, 0)
      end
    end

    def self.to_json(value : BetaManagedAgentsCheckoutParam?, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaManagedAgentsGitHubRepositoryResourceParam
    include JSON::Serializable

    @[JSON::Field(key: "authorization_token")]
    getter authorization_token : String

    getter type : String = "github_repository"
    getter url : String

    @[JSON::Field(emit_null: false)]
    getter checkout : BetaManagedAgentsCheckoutParam?

    @[JSON::Field(key: "mount_path", emit_null: false)]
    getter mount_path : String?

    def initialize(
      @authorization_token : String,
      @url : String,
      @checkout : BetaManagedAgentsCheckoutParam? = nil,
      @mount_path : String? = nil,
    )
    end
  end

  struct BetaManagedAgentsFileResourceParam
    include JSON::Serializable

    @[JSON::Field(key: "file_id")]
    getter file_id : String

    getter type : String = "file"

    @[JSON::Field(key: "mount_path", emit_null: false)]
    getter mount_path : String?

    def initialize(@file_id : String, @mount_path : String? = nil)
    end
  end

  struct BetaManagedAgentsMemoryStoreResourceParam
    include JSON::Serializable

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    getter type : String = "memory_store"

    @[JSON::Field(emit_null: false)]
    getter access : String?

    @[JSON::Field(emit_null: false)]
    getter instructions : String?

    def initialize(
      @memory_store_id : String,
      @access : String? = nil,
      @instructions : String? = nil,
    )
    end
  end

  alias BetaManagedAgentsSessionResourceParam = BetaManagedAgentsGitHubRepositoryResourceParam | BetaManagedAgentsFileResourceParam | BetaManagedAgentsMemoryStoreResourceParam | JSON::Any | Hash(String, JSON::Any)

  # A monetary amount in a specific currency.
  #
  # `amount` is in minor units as an integer decimal string with no leading
  # zeros (`"2500"` is $25.00). A string rather than a number so no float
  # rounding is ever applied. `currency` is an uppercase ISO-4217 code
  # (`"USD"` is currently the only supported currency).
  struct BetaMonetaryAmount
    include JSON::Serializable

    getter amount : String
    getter currency : String

    def initialize(@amount : String, @currency : String)
    end
  end

  # A hard spend ceiling for a session. The session stops issuing new model
  # requests once the tracked list cost reaches `max_list_cost`.
  struct BetaManagedAgentsBudgetLimit
    include JSON::Serializable

    @[JSON::Field(key: "max_list_cost")]
    getter max_list_cost : BetaMonetaryAmount

    getter type : String = "limit"

    def initialize(@max_list_cost : BetaMonetaryAmount)
      @type = "limit"
    end
  end

  # Prompt-cache creation token usage broken down by cache lifetime.
  struct BetaManagedAgentsCacheCreationUsage
    include JSON::Serializable

    # Tokens used to create 1-hour ephemeral cache entries.
    @[JSON::Field(key: "ephemeral_1h_input_tokens", emit_null: false)]
    getter ephemeral_1h_input_tokens : Int32? = nil

    # Tokens used to create 5-minute ephemeral cache entries.
    @[JSON::Field(key: "ephemeral_5m_input_tokens", emit_null: false)]
    getter ephemeral_5m_input_tokens : Int32? = nil

    def initialize(
      @ephemeral_1h_input_tokens : Int32? = nil,
      @ephemeral_5m_input_tokens : Int32? = nil,
    )
    end
  end

  # Server-executed tool usage counters for a session or thread.
  struct BetaManagedAgentsServerToolUsage
    include JSON::Serializable

    # Number of server-executed web fetch requests.
    @[JSON::Field(key: "web_fetch_requests", emit_null: false)]
    getter web_fetch_requests : Int32? = nil

    # Number of server-executed web search requests.
    @[JSON::Field(key: "web_search_requests", emit_null: false)]
    getter web_search_requests : Int32? = nil

    def initialize(
      @web_fetch_requests : Int32? = nil,
      @web_search_requests : Int32? = nil,
    )
    end
  end

  # Cumulative token, runtime, cost, and server tool usage for a session or thread.
  struct BetaManagedAgentsSessionUsage
    include JSON::Serializable

    # Cumulative time in seconds during which the session (or thread) was running.
    @[JSON::Field(key: "active_seconds", emit_null: false)]
    getter active_seconds : Float64? = nil

    # Tokens used to create prompt cache entries, broken down by cache TTL.
    @[JSON::Field(key: "cache_creation", emit_null: false)]
    getter cache_creation : BetaManagedAgentsCacheCreationUsage? = nil

    # Total tokens read from prompt cache.
    @[JSON::Field(key: "cache_read_input_tokens", emit_null: false)]
    getter cache_read_input_tokens : Int64? = nil

    # Total input tokens consumed across all turns.
    @[JSON::Field(key: "input_tokens", emit_null: false)]
    getter input_tokens : Int64? = nil

    # Cumulative list cost across all turns, priced at public list rates.
    @[JSON::Field(key: "list_cost", emit_null: false)]
    getter list_cost : BetaMonetaryAmount? = nil

    # Total output tokens generated across all turns.
    @[JSON::Field(key: "output_tokens", emit_null: false)]
    getter output_tokens : Int64? = nil

    # Cumulative server-executed tool usage across all turns.
    @[JSON::Field(key: "server_tool_use", emit_null: false)]
    getter server_tool_use : BetaManagedAgentsServerToolUsage? = nil
  end

  alias BetaManagedAgentsSessionThreadUsage = BetaManagedAgentsSessionUsage
  alias BetaManagedAgentsSessionUsageSnapshot = BetaManagedAgentsSessionUsage

  # Timing statistics for a session.
  struct BetaManagedAgentsSessionStats
    include JSON::Serializable

    @[JSON::Field(key: "active_seconds", emit_null: false)]
    getter active_seconds : Float64? = nil

    @[JSON::Field(key: "duration_seconds", emit_null: false)]
    getter duration_seconds : Float64? = nil
  end

  # Timing statistics for a session thread.
  struct BetaManagedAgentsSessionThreadStats
    include JSON::Serializable

    @[JSON::Field(key: "active_seconds", emit_null: false)]
    getter active_seconds : Float64? = nil

    @[JSON::Field(key: "duration_seconds", emit_null: false)]
    getter duration_seconds : Float64? = nil

    @[JSON::Field(key: "startup_seconds", emit_null: false)]
    getter startup_seconds : Float64? = nil
  end

  # Tolerant converter for `model` on session/thread agent snapshots (handles
  # `{id, ...}`, bare string model IDs, empty `{}` in mocks, and `null`).
  module BetaManagedAgentsNullableModelConfigConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsModelConfig?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      if str = json.as_s?
        return BetaManagedAgentsModelConfig.new(id: str)
      end
      if hash = json.as_h?
        return nil if hash.empty? || !hash.has_key?("id")
      end
      BetaManagedAgentsModelConfig.from_json(json.to_json)
    end

    def self.to_json(value : BetaManagedAgentsModelConfig?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Resolved agent definition for a single `session_thread`.
  struct BetaManagedAgentsSessionThreadAgent
    include JSON::Serializable

    getter id : String = ""
    getter description : String? = nil

    @[JSON::Field(key: "execution_identity", converter: Anthropic::BetaManagedAgentsExecutionIdentityConverter, emit_null: false)]
    getter execution_identity : BetaManagedAgentsExecutionIdentity? = nil

    @[JSON::Field(key: "mcp_servers")]
    getter mcp_servers : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsNullableModelConfigConverter, emit_null: false)]
    getter model : BetaManagedAgentsModelConfig? = nil

    getter name : String = ""
    getter skills : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(key: "system")]
    getter system_ : String? = nil

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsToolsetArrayConverter)]
    getter tools : Array(BetaManagedAgentsToolset)? = nil

    getter type : String = "agent"
    getter version : Int32 = 0
  end

  # Inline agent definition spawned on a thread (not saved as a reusable agent).
  struct BetaManagedAgentsInlineAgent
    include JSON::Serializable

    getter description : String? = nil

    @[JSON::Field(key: "execution_identity", converter: Anthropic::BetaManagedAgentsExecutionIdentityConverter, emit_null: false)]
    getter execution_identity : BetaManagedAgentsExecutionIdentity? = nil

    @[JSON::Field(key: "mcp_servers")]
    getter mcp_servers : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsNullableModelConfigConverter, emit_null: false)]
    getter model : BetaManagedAgentsModelConfig? = nil

    getter name : String = ""
    getter skills : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(key: "system")]
    getter system_ : String? = nil

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsToolsetArrayConverter)]
    getter tools : Array(BetaManagedAgentsToolset)? = nil

    getter type : String = "inline"
  end

  # Forward-compatible fallback for unrecognized thread agent variants.
  struct GenericBetaManagedAgentsThreadAgent
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsThreadAgent = BetaManagedAgentsSessionThreadAgent | BetaManagedAgentsAdvisor | BetaManagedAgentsInlineAgent | GenericBetaManagedAgentsThreadAgent
  alias BetaManagedAgentsCoordinatorMember = BetaManagedAgentsSessionThreadAgent | BetaManagedAgentsAdvisor | GenericBetaManagedAgentsThreadAgent

  module BetaManagedAgentsThreadAgentConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsThreadAgent
      json = JSON::Any.new(pull)
      raw = json.to_json
      case type = json["type"]?.try(&.as_s?)
      when "agent", nil
        BetaManagedAgentsSessionThreadAgent.from_json(raw)
      when "advisor"
        BetaManagedAgentsAdvisor.from_json(raw)
      when "inline"
        BetaManagedAgentsInlineAgent.from_json(raw)
      else
        GenericBetaManagedAgentsThreadAgent.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsThreadAgent, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  module BetaManagedAgentsCoordinatorMemberArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaManagedAgentsCoordinatorMember)
      result = [] of BetaManagedAgentsCoordinatorMember
      pull.read_array do
        json = JSON::Any.new(pull)
        raw = json.to_json
        member = case type = json["type"]?.try(&.as_s?)
                 when "agent", nil
                   BetaManagedAgentsSessionThreadAgent.from_json(raw)
                 when "advisor"
                   BetaManagedAgentsAdvisor.from_json(raw)
                 else
                   GenericBetaManagedAgentsThreadAgent.new(type: type, raw: json)
                 end
        result << member.as(BetaManagedAgentsCoordinatorMember)
      end
      result
    end

    def self.to_json(value : Array(BetaManagedAgentsCoordinatorMember), builder : JSON::Builder) : Nil
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end

  # Resolved coordinator topology with full agent definitions on a session.
  struct BetaManagedAgentsSessionMultiagentCoordinator
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsCoordinatorMemberArrayConverter)]
    getter agents : Array(BetaManagedAgentsCoordinatorMember) = [] of BetaManagedAgentsCoordinatorMember

    getter type : String = "coordinator"
  end

  # Resolved enabled subagents config on a session.
  struct BetaManagedAgentsSessionMultiagentSubagentsEnabled
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", converter: Anthropic::BetaManagedAgentsMultiagentInlineAgentsConverter)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgents

    @[JSON::Field(key: "predefined_agents")]
    getter predefined_agents : Array(BetaManagedAgentsSessionThreadAgent) = [] of BetaManagedAgentsSessionThreadAgent

    getter type : String = "enabled"
  end

  alias BetaManagedAgentsSessionMultiagentSubagents = BetaManagedAgentsSessionMultiagentSubagentsEnabled | BetaManagedAgentsMultiagentSubagentsDisabled | GenericBetaManagedAgentsMultiagentOption

  module BetaManagedAgentsSessionMultiagentSubagentsConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionMultiagentSubagents
      json = JSON::Any.new(pull)
      raw = json.to_json
      case type = json["type"]?.try(&.as_s?) || "unknown"
      when "enabled"
        BetaManagedAgentsSessionMultiagentSubagentsEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentSubagentsDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsSessionMultiagentSubagents, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Resolved enabled workflows config on a session.
  struct BetaManagedAgentsSessionMultiagentWorkflowsEnabled
    include JSON::Serializable

    @[JSON::Field(key: "inline_agents", converter: Anthropic::BetaManagedAgentsMultiagentInlineAgentsConverter)]
    getter inline_agents : BetaManagedAgentsMultiagentInlineAgents

    @[JSON::Field(key: "predefined_agents")]
    getter predefined_agents : Array(BetaManagedAgentsSessionThreadAgent) = [] of BetaManagedAgentsSessionThreadAgent

    getter type : String = "enabled"
  end

  alias BetaManagedAgentsSessionMultiagentWorkflows = BetaManagedAgentsSessionMultiagentWorkflowsEnabled | BetaManagedAgentsMultiagentWorkflowsDisabled | GenericBetaManagedAgentsMultiagentOption

  module BetaManagedAgentsSessionMultiagentWorkflowsConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionMultiagentWorkflows
      json = JSON::Any.new(pull)
      raw = json.to_json
      case type = json["type"]?.try(&.as_s?) || "unknown"
      when "enabled"
        BetaManagedAgentsSessionMultiagentWorkflowsEnabled.from_json(raw)
      when "disabled"
        BetaManagedAgentsMultiagentWorkflowsDisabled.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagentOption.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsSessionMultiagentWorkflows, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Resolved multiagent configuration (`multiagent_20261001`) on a session.
  struct BetaManagedAgentsSessionMultiagent20261001
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsMultiagentAdvisorConverter)]
    getter advisor : BetaManagedAgentsMultiagentAdvisor

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsSessionMultiagentSubagentsConverter)]
    getter subagents : BetaManagedAgentsSessionMultiagentSubagents

    getter type : String = "multiagent_20261001"

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsSessionMultiagentWorkflowsConverter)]
    getter workflows : BetaManagedAgentsSessionMultiagentWorkflows
  end

  alias BetaManagedAgentsSessionMultiagent = BetaManagedAgentsSessionMultiagentCoordinator | BetaManagedAgentsSessionMultiagent20261001 | GenericBetaManagedAgentsMultiagent

  module BetaManagedAgentsSessionMultiagentConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionMultiagent?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "coordinator"
        BetaManagedAgentsSessionMultiagentCoordinator.from_json(raw)
      when "multiagent_20261001"
        BetaManagedAgentsSessionMultiagent20261001.from_json(raw)
      else
        GenericBetaManagedAgentsMultiagent.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsSessionMultiagent?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Resolved agent snapshot attached to a session.
  struct BetaManagedAgentsSessionAgent
    include JSON::Serializable

    getter id : String = ""
    getter description : String? = nil

    @[JSON::Field(key: "execution_identity", converter: Anthropic::BetaManagedAgentsExecutionIdentityConverter, emit_null: false)]
    getter execution_identity : BetaManagedAgentsExecutionIdentity? = nil

    @[JSON::Field(key: "mcp_servers")]
    getter mcp_servers : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsNullableModelConfigConverter, emit_null: false)]
    getter model : BetaManagedAgentsModelConfig? = nil

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsSessionMultiagentConverter, emit_null: false)]
    getter multiagent : BetaManagedAgentsSessionMultiagent? = nil

    getter name : String = ""
    getter skills : Array(JSON::Any) = [] of JSON::Any

    @[JSON::Field(key: "system")]
    getter system_ : String? = nil

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsToolsetArrayConverter)]
    getter tools : Array(BetaManagedAgentsToolset)? = nil

    getter type : String = "agent"
    getter version : Int32 = 0
  end

  struct BetaManagedAgentsSession
    include JSON::Serializable

    getter id : String
    getter agent : BetaManagedAgentsSessionAgent
    getter stats : BetaManagedAgentsSessionStats
    getter usage : BetaManagedAgentsSessionUsage
    getter type : String = "session"
    getter status : String # "rescheduling" | "running" | "idle" | "terminated"
    getter title : String?

    @[JSON::Field(key: "environment_id")]
    getter environment_id : String

    @[JSON::Field(key: "vault_ids")]
    getter vault_ids : Array(String)

    @[JSON::Field(key: "outcome_evaluations")]
    getter outcome_evaluations : Array(JSON::Any)

    getter resources : Array(JSON::Any)
    getter metadata : Hash(String, String)

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?

    # Hard spend ceiling (`nil` when the session has no budget).
    @[JSON::Field(emit_null: false)]
    getter budget : BetaManagedAgentsBudgetLimit?

    # Deployment ID when the session was created from a deployment reference.
    @[JSON::Field(key: "deployment_id", emit_null: false)]
    getter deployment_id : String? = nil
  end

  struct BetaManagedAgentsDeletedSession
    include JSON::Serializable
    getter id : String
    getter type : String = "session_deleted"
  end

  struct BetaSessionListResponse
    include JSON::Serializable
    include PageCursorMethods
    getter data : Array(BetaManagedAgentsSession)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?

    @[JSON::Field(key: "prev_page")]
    getter prev_page : String?
  end

  # Execution status values for a Managed Agents session thread.
  module BetaManagedAgentsSessionThreadStatus
    RUNNING      = "running"
    IDLE         = "idle"
    RESCHEDULING = "rescheduling"
    TERMINATED   = "terminated"
  end

  struct BetaManagedAgentsSessionThread
    include JSON::Serializable

    getter id : String

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsThreadAgentConverter)]
    getter agent : BetaManagedAgentsThreadAgent

    getter type : String = "session_thread"
    getter status : String # "running" | "idle" | "rescheduling" | "terminated"

    @[JSON::Field(key: "session_id")]
    getter session_id : String

    @[JSON::Field(key: "parent_thread_id")]
    getter parent_thread_id : String?

    getter stats : BetaManagedAgentsSessionThreadStats? = nil
    getter usage : BetaManagedAgentsSessionThreadUsage? = nil

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?

    # Identifier of the workflow run that created the thread, or `nil`.
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String? = nil
  end

  struct BetaSessionThreadListResponse
    include JSON::Serializable
    include PageCursorMethods
    getter data : Array(BetaManagedAgentsSessionThread)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # A file attached to an agent session.
  struct BetaSessionFileResource
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "file_id")]
    getter file_id : String

    @[JSON::Field(key: "mount_path")]
    getter mount_path : String

    getter type : String = "file"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  # A GitHub repository attached to an agent session.
  struct BetaSessionGitHubRepositoryResource
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "mount_path")]
    getter mount_path : String

    getter type : String = "github_repository"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    getter url : String

    # Branch or commit checkout, when pinned.
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsCheckoutConverter, emit_null: false)]
    getter checkout : BetaManagedAgentsCheckoutParam?
  end

  # A memory store attached to an agent session.
  struct BetaSessionMemoryStoreResource
    include JSON::Serializable

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    getter type : String = "memory_store"

    # Access mode: `"read_write"` or `"read_only"`.
    @[JSON::Field(emit_null: false)]
    getter access : String?

    # Store description, snapshotted at attach time.
    @[JSON::Field(emit_null: false)]
    getter description : String?

    # Per-attachment guidance for the agent.
    @[JSON::Field(emit_null: false)]
    getter instructions : String?

    # Filesystem mount path. Output-only.
    @[JSON::Field(key: "mount_path", emit_null: false)]
    getter mount_path : String?

    # Store display name, snapshotted at attach time.
    @[JSON::Field(emit_null: false)]
    getter name : String?
  end

  # A future session resource type, preserved with its raw payload so
  # unknown shapes don't break response parsing.
  struct GenericSessionResource
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    # Serialize back to the original JSON payload.
    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  # A resource attached to an agent session.
  alias BetaSessionResource = BetaSessionFileResource | BetaSessionGitHubRepositoryResource | BetaSessionMemoryStoreResource | GenericSessionResource

  # Discriminated-union converter for session resources.
  module BetaSessionResourceConverter
    def self.from_json(pull : JSON::PullParser) : BetaSessionResource
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "file"
        BetaSessionFileResource.from_json(raw)
      when "github_repository"
        BetaSessionGitHubRepositoryResource.from_json(raw)
      when "memory_store"
        BetaSessionMemoryStoreResource.from_json(raw)
      else
        GenericSessionResource.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaSessionResource, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Confirmation returned when a session resource is deleted.
  struct BetaSessionResourceDeleted
    include JSON::Serializable

    getter id : String
    getter type : String = "session_resource_deleted"
  end

  # Paginated list of session resources.
  struct BetaSessionResourceListResponse
    include JSON::Serializable
    include PageCursorMethods

    @[JSON::Field(converter: Anthropic::BetaSessionResourceArrayConverter)]
    getter data : Array(BetaSessionResource)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Array converter for session resources discriminated by `"type"`.
  module BetaSessionResourceArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaSessionResource)
      result = [] of BetaSessionResource
      pull.read_array do
        result << BetaSessionResourceConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BetaSessionResource), builder : JSON::Builder)
      builder.array do
        value.each &.to_json(builder)
      end
    end
  end

  # Plain-text content block for session input events.
  struct BetaSessionTextBlock
    include JSON::Serializable

    getter text : String
    getter type : String = "text"

    def initialize(@text : String)
      @type = "text"
    end
  end

  # Redacted content block for session input events.
  struct BetaSessionRedactedBlock
    include JSON::Serializable

    getter type : String = "redacted"
  end

  # Content for session input events. Image, document, and search-result
  # blocks pass through as `JSON::Any`.
  alias BetaSessionEventContent = BetaSessionTextBlock | BetaSessionRedactedBlock | JSON::Any

  # File-backed outcome rubric for `user.define_outcome` events.
  struct BetaSessionFileRubric
    include JSON::Serializable

    @[JSON::Field(key: "file_id")]
    getter file_id : String

    getter type : String = "file"

    def initialize(@file_id : String)
      @type = "file"
    end
  end

  # Text outcome rubric for `user.define_outcome` events.
  struct BetaSessionTextRubric
    include JSON::Serializable

    getter content : String
    getter type : String = "text"

    def initialize(@content : String)
      @type = "text"
    end
  end

  # Outcome rubric for `user.define_outcome` events.
  alias BetaSessionRubric = BetaSessionFileRubric | BetaSessionTextRubric

  # A user message to send to a session.
  struct BetaSessionUserMessageEvent
    include JSON::Serializable

    getter content : Array(BetaSessionEventContent)
    getter type : String = "user.message"

    def initialize(@content : Array(BetaSessionEventContent))
      @type = "user.message"
    end

    # Convenience for a single text message.
    def self.message(text : String) : self
      new([BetaSessionTextBlock.new(text)] of BetaSessionEventContent)
    end
  end

  # An interrupt to send to a session.
  struct BetaSessionUserInterruptEvent
    include JSON::Serializable

    getter type : String = "user.interrupt"

    @[JSON::Field(key: "session_thread_id", emit_null: false)]
    getter session_thread_id : String?

    def initialize(@session_thread_id : String? = nil)
      @type = "user.interrupt"
    end
  end

  # A tool-approval decision to send to a session.
  struct BetaSessionUserToolConfirmationEvent
    include JSON::Serializable

    # `"allow"` or `"deny"`.
    getter result : String

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter type : String = "user.tool_confirmation"

    @[JSON::Field(key: "deny_message", emit_null: false)]
    getter deny_message : String?

    def initialize(@result : String, @tool_use_id : String, @deny_message : String? = nil)
      @type = "user.tool_confirmation"
    end
  end

  # A custom-tool result to send to a session.
  struct BetaSessionUserCustomToolResultEvent
    include JSON::Serializable

    @[JSON::Field(key: "custom_tool_use_id")]
    getter custom_tool_use_id : String

    getter type : String = "user.custom_tool_result"

    @[JSON::Field(emit_null: false)]
    getter content : Array(BetaSessionEventContent)?

    @[JSON::Field(key: "is_error", emit_null: false)]
    getter is_error : Bool?

    def initialize(
      @custom_tool_use_id : String,
      @content : Array(BetaSessionEventContent)? = nil,
      @is_error : Bool? = nil,
    )
      @type = "user.custom_tool_result"
    end
  end

  # An outcome definition to send to a session.
  struct BetaSessionUserDefineOutcomeEvent
    include JSON::Serializable

    getter description : String
    getter rubric : BetaSessionRubric
    getter type : String = "user.define_outcome"

    @[JSON::Field(key: "max_iterations", emit_null: false)]
    getter max_iterations : Int32?

    def initialize(@description : String, @rubric : BetaSessionRubric, @max_iterations : Int32? = nil)
      @type = "user.define_outcome"
    end
  end

  # A tool result to send to a session.
  struct BetaSessionUserToolResultEvent
    include JSON::Serializable

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter type : String = "user.tool_result"

    @[JSON::Field(emit_null: false)]
    getter content : Array(BetaSessionEventContent)?

    @[JSON::Field(key: "is_error", emit_null: false)]
    getter is_error : Bool?

    def initialize(
      @tool_use_id : String,
      @content : Array(BetaSessionEventContent)? = nil,
      @is_error : Bool? = nil,
    )
      @type = "user.tool_result"
    end
  end

  # A system message to send to a session.
  struct BetaSessionSystemMessageEvent
    include JSON::Serializable

    getter content : Array(BetaSessionTextBlock)
    getter type : String = "system.message"

    def initialize(@content : Array(BetaSessionTextBlock))
      @type = "system.message"
    end

    # Convenience for a single text message.
    def self.message(text : String) : self
      new([BetaSessionTextBlock.new(text)])
    end
  end

  # An event to send to a session.
  alias BetaSessionInputEvent = BetaSessionUserMessageEvent | BetaSessionUserInterruptEvent | BetaSessionUserToolConfirmationEvent | BetaSessionUserCustomToolResultEvent | BetaSessionUserDefineOutcomeEvent | BetaSessionUserToolResultEvent | BetaSessionSystemMessageEvent

  # All Managed Agents session/thread/workflow event type discriminators.
  module BetaManagedAgentsSessionEventType
    USER_MESSAGE                      = "user.message"
    USER_INTERRUPT                    = "user.interrupt"
    USER_TOOL_CONFIRMATION            = "user.tool_confirmation"
    USER_CUSTOM_TOOL_RESULT           = "user.custom_tool_result"
    AGENT_CUSTOM_TOOL_USE             = "agent.custom_tool_use"
    AGENT_MESSAGE                     = "agent.message"
    AGENT_THINKING                    = "agent.thinking"
    AGENT_MCP_TOOL_USE                = "agent.mcp_tool_use"
    AGENT_MCP_TOOL_RESULT             = "agent.mcp_tool_result"
    AGENT_TOOL_USE                    = "agent.tool_use"
    AGENT_TOOL_RESULT                 = "agent.tool_result"
    AGENT_THREAD_MESSAGE_RECEIVED     = "agent.thread_message_received"
    AGENT_THREAD_MESSAGE_SENT         = "agent.thread_message_sent"
    AGENT_THREAD_CONTEXT_COMPACTED    = "agent.thread_context_compacted"
    SESSION_ERROR                     = "session.error"
    SESSION_STATUS_RESCHEDULED        = "session.status_rescheduled"
    SESSION_STATUS_RUNNING            = "session.status_running"
    SESSION_STATUS_IDLE               = "session.status_idle"
    SESSION_STATUS_TERMINATED         = "session.status_terminated"
    SESSION_THREAD_CREATED            = "session.thread_created"
    SPAN_OUTCOME_EVALUATION_START     = "span.outcome_evaluation_start"
    SPAN_OUTCOME_EVALUATION_END       = "span.outcome_evaluation_end"
    SPAN_MODEL_REQUEST_START          = "span.model_request_start"
    SPAN_MODEL_REQUEST_END            = "span.model_request_end"
    SPAN_OUTCOME_EVALUATION_ONGOING   = "span.outcome_evaluation_ongoing"
    USER_DEFINE_OUTCOME               = "user.define_outcome"
    SESSION_THREAD_STATUS_RUNNING     = "session.thread_status_running"
    SESSION_THREAD_STATUS_IDLE        = "session.thread_status_idle"
    SESSION_THREAD_STATUS_TERMINATED  = "session.thread_status_terminated"
    USER_TOOL_RESULT                  = "user.tool_result"
    SESSION_THREAD_STATUS_RESCHEDULED = "session.thread_status_rescheduled"
    SESSION_UPDATED                   = "session.updated"
    SYSTEM_MESSAGE                    = "system.message"
    SESSION_USAGE                     = "session.usage"
    WORKFLOW_RUN_CREATED              = "workflow_run.created"
    WORKFLOW_RUN_STATUS_RUNNING       = "workflow_run.status_running"
    WORKFLOW_RUN_STATUS_IDLE          = "workflow_run.status_idle"
    WORKFLOW_RUN_STATUS_ENDED         = "workflow_run.status_ended"
    WORKFLOW_RUN_ERROR                = "workflow_run.error"
    WORKFLOW_RUN_PHASE_STARTED        = "workflow_run.phase_started"
    WORKFLOW_RUN_PHASE_ENDED          = "workflow_run.phase_ended"

    def self.values : Array(String)
      [
        USER_MESSAGE, USER_INTERRUPT, USER_TOOL_CONFIRMATION, USER_CUSTOM_TOOL_RESULT,
        AGENT_CUSTOM_TOOL_USE, AGENT_MESSAGE, AGENT_THINKING, AGENT_MCP_TOOL_USE,
        AGENT_MCP_TOOL_RESULT, AGENT_TOOL_USE, AGENT_TOOL_RESULT,
        AGENT_THREAD_MESSAGE_RECEIVED, AGENT_THREAD_MESSAGE_SENT, AGENT_THREAD_CONTEXT_COMPACTED,
        SESSION_ERROR, SESSION_STATUS_RESCHEDULED, SESSION_STATUS_RUNNING, SESSION_STATUS_IDLE,
        SESSION_STATUS_TERMINATED, SESSION_THREAD_CREATED,
        SPAN_OUTCOME_EVALUATION_START, SPAN_OUTCOME_EVALUATION_END,
        SPAN_MODEL_REQUEST_START, SPAN_MODEL_REQUEST_END, SPAN_OUTCOME_EVALUATION_ONGOING,
        USER_DEFINE_OUTCOME, SESSION_THREAD_STATUS_RUNNING, SESSION_THREAD_STATUS_IDLE,
        SESSION_THREAD_STATUS_TERMINATED, USER_TOOL_RESULT, SESSION_THREAD_STATUS_RESCHEDULED,
        SESSION_UPDATED, SYSTEM_MESSAGE, SESSION_USAGE,
        WORKFLOW_RUN_CREATED, WORKFLOW_RUN_STATUS_RUNNING, WORKFLOW_RUN_STATUS_IDLE,
        WORKFLOW_RUN_STATUS_ENDED, WORKFLOW_RUN_ERROR, WORKFLOW_RUN_PHASE_STARTED,
        WORKFLOW_RUN_PHASE_ENDED,
      ]
    end
  end

  # --- Retry Status ---

  struct BetaManagedAgentsRetryStatusRetrying
    include JSON::Serializable
    getter type : String = "retrying"
  end

  struct BetaManagedAgentsRetryStatusExhausted
    include JSON::Serializable
    getter type : String = "exhausted"
  end

  struct BetaManagedAgentsRetryStatusTerminal
    include JSON::Serializable
    getter type : String = "terminal"
  end

  struct GenericBetaManagedAgentsRetryStatus
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsRetryStatus = BetaManagedAgentsRetryStatusRetrying | BetaManagedAgentsRetryStatusExhausted | BetaManagedAgentsRetryStatusTerminal | GenericBetaManagedAgentsRetryStatus

  module BetaManagedAgentsRetryStatusConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsRetryStatus
      json = JSON::Any.new(pull)
      raw = json.to_json
      case type = json["type"]?.try(&.as_s?) || "unknown"
      when "retrying"
        BetaManagedAgentsRetryStatusRetrying.from_json(raw)
      when "exhausted"
        BetaManagedAgentsRetryStatusExhausted.from_json(raw)
      when "terminal"
        BetaManagedAgentsRetryStatusTerminal.from_json(raw)
      else
        GenericBetaManagedAgentsRetryStatus.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsRetryStatus, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # --- Session Idle Stop Reasons & Refusal Details ---

  module BetaManagedAgentsSessionRefusalCategory
    CYBER                = "cyber"
    BIO                  = "bio"
    FRONTIER_LLM         = "frontier_llm"
    REASONING_EXTRACTION = "reasoning_extraction"
    GENERAL_HARMS        = "general_harms"
  end

  # Structured information about why a session or thread refused a turn.
  struct BetaManagedAgentsSessionRefusalStopDetails
    include JSON::Serializable

    getter category : String? = nil
    getter explanation : String? = nil
    getter type : String = "refusal"
  end

  struct BetaManagedAgentsSessionEndTurn
    include JSON::Serializable
    getter type : String = "end_turn"
  end

  struct BetaManagedAgentsSessionRequiresAction
    include JSON::Serializable

    @[JSON::Field(key: "event_ids")]
    getter event_ids : Array(String) = [] of String

    getter type : String = "requires_action"
  end

  struct BetaManagedAgentsSessionRetriesExhausted
    include JSON::Serializable
    getter type : String = "retries_exhausted"
  end

  struct BetaManagedAgentsSessionBudgetReached
    include JSON::Serializable
    getter type : String = "budget_reached"
  end

  # The turn ended because the model's response was refused (e.g. by a safety classifier).
  struct BetaManagedAgentsSessionRefusal
    include JSON::Serializable
    getter type : String = "refusal"
  end

  struct GenericBetaManagedAgentsSessionStopReason
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsSessionStopReason = BetaManagedAgentsSessionEndTurn | BetaManagedAgentsSessionRequiresAction | BetaManagedAgentsSessionRetriesExhausted | BetaManagedAgentsSessionBudgetReached | BetaManagedAgentsSessionRefusal | GenericBetaManagedAgentsSessionStopReason

  module BetaManagedAgentsSessionStopReasonConverter
    PARSERS = {
      "end_turn"          => ->(raw : String) { BetaManagedAgentsSessionEndTurn.from_json(raw).as(BetaManagedAgentsSessionStopReason) },
      "requires_action"   => ->(raw : String) { BetaManagedAgentsSessionRequiresAction.from_json(raw).as(BetaManagedAgentsSessionStopReason) },
      "retries_exhausted" => ->(raw : String) { BetaManagedAgentsSessionRetriesExhausted.from_json(raw).as(BetaManagedAgentsSessionStopReason) },
      "budget_reached"    => ->(raw : String) { BetaManagedAgentsSessionBudgetReached.from_json(raw).as(BetaManagedAgentsSessionStopReason) },
      "refusal"           => ->(raw : String) { BetaManagedAgentsSessionRefusal.from_json(raw).as(BetaManagedAgentsSessionStopReason) },
    }

    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionStopReason
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      if parser = PARSERS[type]?
        parser.call(json.to_json)
      else
        GenericBetaManagedAgentsSessionStopReason.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsSessionStopReason, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # --- Session Error Variants (15 types + fallback) ---

  struct BetaManagedAgentsUnknownError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "unknown_error"
  end

  struct BetaManagedAgentsModelOverloadedError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "model_overloaded_error"
  end

  struct BetaManagedAgentsModelRateLimitedError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "model_rate_limited_error"
  end

  struct BetaManagedAgentsModelRequestFailedError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "model_request_failed_error"
  end

  struct BetaManagedAgentsMCPConnectionFailedError
    include JSON::Serializable
    @[JSON::Field(key: "mcp_server_name")]
    getter mcp_server_name : String
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "mcp_connection_failed_error"
  end

  struct BetaManagedAgentsMCPAuthenticationFailedError
    include JSON::Serializable
    @[JSON::Field(key: "mcp_server_name")]
    getter mcp_server_name : String
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "mcp_authentication_failed_error"
  end

  struct BetaManagedAgentsBillingError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "billing_error"
  end

  struct BetaManagedAgentsCredentialHostUnreachableError
    include JSON::Serializable
    @[JSON::Field(key: "credential_id")]
    getter credential_id : String
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    @[JSON::Field(key: "vault_id")]
    getter vault_id : String
    getter type : String = "credential_host_unreachable_error"
  end

  struct BetaManagedAgentsToolUseLimitReachedError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "tool_use_limit_reached_error"
  end

  struct BetaManagedAgentsCompactionLimitReachedError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "compaction_limit_reached_error"
  end

  struct BetaManagedAgentsRepositoryAuthenticationError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "repository_url")]
    getter repository_url : String? = nil
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "repository_authentication_error"
  end

  struct BetaManagedAgentsRepositoryForbiddenError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "repository_url")]
    getter repository_url : String? = nil
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "repository_forbidden_error"
  end

  struct BetaManagedAgentsRepositoryNotFoundError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "repository_url")]
    getter repository_url : String? = nil
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "repository_not_found_error"
  end

  struct BetaManagedAgentsRepositoryCheckoutError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "repository_url")]
    getter repository_url : String? = nil
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "repository_checkout_error"
  end

  struct BetaManagedAgentsRepositoryCloneError
    include JSON::Serializable
    getter message : String
    @[JSON::Field(key: "repository_url")]
    getter repository_url : String? = nil
    @[JSON::Field(key: "retry_status", converter: Anthropic::BetaManagedAgentsRetryStatusConverter)]
    getter retry_status : BetaManagedAgentsRetryStatus
    getter type : String = "repository_clone_error"
  end

  struct GenericBetaManagedAgentsSessionError
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def message : String?
      raw["message"]?.try(&.as_s?)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsSessionError = BetaManagedAgentsUnknownError |
                                        BetaManagedAgentsModelOverloadedError |
                                        BetaManagedAgentsModelRateLimitedError |
                                        BetaManagedAgentsModelRequestFailedError |
                                        BetaManagedAgentsMCPConnectionFailedError |
                                        BetaManagedAgentsMCPAuthenticationFailedError |
                                        BetaManagedAgentsBillingError |
                                        BetaManagedAgentsCredentialHostUnreachableError |
                                        BetaManagedAgentsToolUseLimitReachedError |
                                        BetaManagedAgentsCompactionLimitReachedError |
                                        BetaManagedAgentsRepositoryAuthenticationError |
                                        BetaManagedAgentsRepositoryForbiddenError |
                                        BetaManagedAgentsRepositoryNotFoundError |
                                        BetaManagedAgentsRepositoryCheckoutError |
                                        BetaManagedAgentsRepositoryCloneError |
                                        GenericBetaManagedAgentsSessionError

  module BetaManagedAgentsSessionErrorConverter
    PARSERS = {
      "unknown_error"                     => ->(raw : String) { BetaManagedAgentsUnknownError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "model_overloaded_error"            => ->(raw : String) { BetaManagedAgentsModelOverloadedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "model_rate_limited_error"          => ->(raw : String) { BetaManagedAgentsModelRateLimitedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "model_request_failed_error"        => ->(raw : String) { BetaManagedAgentsModelRequestFailedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "mcp_connection_failed_error"       => ->(raw : String) { BetaManagedAgentsMCPConnectionFailedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "mcp_authentication_failed_error"   => ->(raw : String) { BetaManagedAgentsMCPAuthenticationFailedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "billing_error"                     => ->(raw : String) { BetaManagedAgentsBillingError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "credential_host_unreachable_error" => ->(raw : String) { BetaManagedAgentsCredentialHostUnreachableError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "tool_use_limit_reached_error"      => ->(raw : String) { BetaManagedAgentsToolUseLimitReachedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "compaction_limit_reached_error"    => ->(raw : String) { BetaManagedAgentsCompactionLimitReachedError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "repository_authentication_error"   => ->(raw : String) { BetaManagedAgentsRepositoryAuthenticationError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "repository_forbidden_error"        => ->(raw : String) { BetaManagedAgentsRepositoryForbiddenError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "repository_not_found_error"        => ->(raw : String) { BetaManagedAgentsRepositoryNotFoundError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "repository_checkout_error"         => ->(raw : String) { BetaManagedAgentsRepositoryCheckoutError.from_json(raw).as(BetaManagedAgentsSessionError) },
      "repository_clone_error"            => ->(raw : String) { BetaManagedAgentsRepositoryCloneError.from_json(raw).as(BetaManagedAgentsSessionError) },
    }

    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionError
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      if parser = PARSERS[type]?
        parser.call(json.to_json)
      else
        GenericBetaManagedAgentsSessionError.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsSessionError, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # --- Workflow Run Errors, Phases, and Results ---

  struct BetaManagedAgentsTimeoutWorkflowRunError
    include JSON::Serializable
    getter message : String
    getter type : String = "timeout_error"
  end

  struct BetaManagedAgentsProgramWorkflowRunError
    include JSON::Serializable
    getter message : String
    getter type : String = "program_error"
  end

  struct BetaManagedAgentsUnknownWorkflowRunError
    include JSON::Serializable
    getter message : String
    getter type : String = "unknown_error"
  end

  struct BetaManagedAgentsThreadLimitWorkflowRunError
    include JSON::Serializable
    getter message : String
    getter type : String = "thread_limit_error"
  end

  struct BetaManagedAgentsMaxWorkflowRunsWorkflowRunError
    include JSON::Serializable
    getter message : String
    getter type : String = "max_workflow_runs_error"
  end

  struct GenericBetaManagedAgentsWorkflowRunError
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def message : String?
      raw["message"]?.try(&.as_s?)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsWorkflowRunError = BetaManagedAgentsTimeoutWorkflowRunError |
                                            BetaManagedAgentsProgramWorkflowRunError |
                                            BetaManagedAgentsUnknownWorkflowRunError |
                                            BetaManagedAgentsThreadLimitWorkflowRunError |
                                            BetaManagedAgentsMaxWorkflowRunsWorkflowRunError |
                                            GenericBetaManagedAgentsWorkflowRunError

  module BetaManagedAgentsWorkflowRunErrorConverter
    PARSERS = {
      "timeout_error"           => ->(raw : String) { BetaManagedAgentsTimeoutWorkflowRunError.from_json(raw).as(BetaManagedAgentsWorkflowRunError) },
      "program_error"           => ->(raw : String) { BetaManagedAgentsProgramWorkflowRunError.from_json(raw).as(BetaManagedAgentsWorkflowRunError) },
      "unknown_error"           => ->(raw : String) { BetaManagedAgentsUnknownWorkflowRunError.from_json(raw).as(BetaManagedAgentsWorkflowRunError) },
      "thread_limit_error"      => ->(raw : String) { BetaManagedAgentsThreadLimitWorkflowRunError.from_json(raw).as(BetaManagedAgentsWorkflowRunError) },
      "max_workflow_runs_error" => ->(raw : String) { BetaManagedAgentsMaxWorkflowRunsWorkflowRunError.from_json(raw).as(BetaManagedAgentsWorkflowRunError) },
    }

    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsWorkflowRunError
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      if parser = PARSERS[type]?
        parser.call(json.to_json)
      else
        GenericBetaManagedAgentsWorkflowRunError.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsWorkflowRunError, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  struct BetaManagedAgentsWorkflowRunPhase
    include JSON::Serializable
    getter id : String
    getter description : String? = nil
    getter name : String
  end

  struct BetaManagedAgentsWorkflowRunResultCompleted
    include JSON::Serializable
    getter type : String = "completed"
  end

  struct BetaManagedAgentsWorkflowRunResultStopped
    include JSON::Serializable
    getter type : String = "stopped"
  end

  struct BetaManagedAgentsWorkflowRunResultError
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaManagedAgentsWorkflowRunErrorConverter)]
    getter error : BetaManagedAgentsWorkflowRunError

    getter type : String = "error"
  end

  struct GenericBetaManagedAgentsWorkflowRunResult
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsWorkflowRunResult = BetaManagedAgentsWorkflowRunResultCompleted | BetaManagedAgentsWorkflowRunResultError | BetaManagedAgentsWorkflowRunResultStopped | GenericBetaManagedAgentsWorkflowRunResult

  module BetaManagedAgentsWorkflowRunResultConverter
    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsWorkflowRunResult
      json = JSON::Any.new(pull)
      raw = json.to_json
      case type = json["type"]?.try(&.as_s?) || "unknown"
      when "completed"
        BetaManagedAgentsWorkflowRunResultCompleted.from_json(raw)
      when "stopped"
        BetaManagedAgentsWorkflowRunResultStopped.from_json(raw)
      when "error"
        BetaManagedAgentsWorkflowRunResultError.from_json(raw)
      else
        GenericBetaManagedAgentsWorkflowRunResult.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaManagedAgentsWorkflowRunResult, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # --- Typed Session, Thread, and Workflow Run Output Events ---

  struct BetaManagedAgentsSessionErrorEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsSessionErrorConverter)]
    getter error : BetaManagedAgentsSessionError
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.error"
  end

  struct BetaManagedAgentsSessionStatusRunningEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.status_running"
  end

  struct BetaManagedAgentsSessionStatusIdleEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "stop_details")]
    getter stop_details : BetaManagedAgentsSessionRefusalStopDetails? = nil
    @[JSON::Field(key: "stop_reason", converter: Anthropic::BetaManagedAgentsSessionStopReasonConverter)]
    getter stop_reason : BetaManagedAgentsSessionStopReason
    getter type : String = "session.status_idle"
  end

  struct BetaManagedAgentsSessionStatusRescheduledEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.status_rescheduled"
  end

  struct BetaManagedAgentsSessionStatusTerminatedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.status_terminated"
  end

  struct BetaManagedAgentsSessionDeletedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.deleted"
  end

  struct BetaManagedAgentsSessionUpdatedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.updated"
    @[JSON::Field(emit_null: false)]
    getter agent : BetaManagedAgentsSessionAgent? = nil
    @[JSON::Field(emit_null: false)]
    getter budget : BetaManagedAgentsBudgetLimit? = nil
    @[JSON::Field(emit_null: false)]
    getter metadata : Hash(String, String)? = nil
    @[JSON::Field(emit_null: false)]
    getter title : String? = nil
  end

  struct BetaManagedAgentsSessionUsageEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "session.usage"
    getter usage : BetaManagedAgentsSessionUsageSnapshot
    @[JSON::Field(emit_null: false)]
    getter budget : BetaManagedAgentsBudgetLimit? = nil
  end

  struct BetaManagedAgentsSessionThreadCreatedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "agent_name")]
    getter agent_name : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "session_thread_id")]
    getter session_thread_id : String
    getter type : String = "session.thread_created"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String? = nil
  end

  struct BetaManagedAgentsSessionThreadStatusRunningEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "agent_name")]
    getter agent_name : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "session_thread_id")]
    getter session_thread_id : String
    getter type : String = "session.thread_status_running"
  end

  struct BetaManagedAgentsSessionThreadStatusIdleEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "agent_name")]
    getter agent_name : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "session_thread_id")]
    getter session_thread_id : String
    @[JSON::Field(key: "stop_details")]
    getter stop_details : BetaManagedAgentsSessionRefusalStopDetails? = nil
    @[JSON::Field(key: "stop_reason", converter: Anthropic::BetaManagedAgentsSessionStopReasonConverter)]
    getter stop_reason : BetaManagedAgentsSessionStopReason
    getter type : String = "session.thread_status_idle"
  end

  struct BetaManagedAgentsSessionThreadStatusRescheduledEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "agent_name")]
    getter agent_name : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "session_thread_id")]
    getter session_thread_id : String
    getter type : String = "session.thread_status_rescheduled"
  end

  struct BetaManagedAgentsSessionThreadStatusTerminatedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "agent_name")]
    getter agent_name : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(key: "session_thread_id")]
    getter session_thread_id : String
    getter type : String = "session.thread_status_terminated"
  end

  struct BetaManagedAgentsWorkflowRunCreatedEvent
    include JSON::Serializable
    getter id : String
    getter description : String? = nil
    getter name : String
    getter phases : Array(BetaManagedAgentsWorkflowRunPhase) = [] of BetaManagedAgentsWorkflowRunPhase
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.created"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
  end

  struct BetaManagedAgentsWorkflowRunStatusRunningEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.status_running"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
  end

  struct BetaManagedAgentsWorkflowRunStatusIdleEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.status_idle"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
  end

  struct BetaManagedAgentsWorkflowRunStatusEndedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsWorkflowRunResultConverter)]
    getter result : BetaManagedAgentsWorkflowRunResult
    getter type : String = "workflow_run.status_ended"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
  end

  struct BetaManagedAgentsWorkflowRunErrorEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(converter: Anthropic::BetaManagedAgentsWorkflowRunErrorConverter)]
    getter error : BetaManagedAgentsWorkflowRunError
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.error"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String? = nil
  end

  struct BetaManagedAgentsWorkflowRunPhaseStartedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.phase_started"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
    @[JSON::Field(key: "workflow_run_phase_id")]
    getter workflow_run_phase_id : String
  end

  struct BetaManagedAgentsWorkflowRunPhaseEndedEvent
    include JSON::Serializable
    getter id : String
    @[JSON::Field(key: "phase_started_id")]
    getter phase_started_id : String
    @[JSON::Field(key: "processed_at")]
    getter processed_at : String
    getter type : String = "workflow_run.phase_ended"
    @[JSON::Field(key: "workflow_run_id")]
    getter workflow_run_id : String
    @[JSON::Field(key: "workflow_run_phase_id")]
    getter workflow_run_phase_id : String
  end

  # Forward-compatible fallback for stream/history event types without dedicated typed structs.
  struct GenericBetaManagedAgentsSessionEvent
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def id : String?
      raw["id"]?.try(&.as_s?)
    end

    def processed_at : String?
      raw["processed_at"]?.try(&.as_s?)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaManagedAgentsSessionEvent = BetaManagedAgentsSessionErrorEvent |
                                        BetaManagedAgentsSessionStatusRunningEvent |
                                        BetaManagedAgentsSessionStatusIdleEvent |
                                        BetaManagedAgentsSessionStatusRescheduledEvent |
                                        BetaManagedAgentsSessionStatusTerminatedEvent |
                                        BetaManagedAgentsSessionDeletedEvent |
                                        BetaManagedAgentsSessionUpdatedEvent |
                                        BetaManagedAgentsSessionUsageEvent |
                                        BetaManagedAgentsSessionThreadCreatedEvent |
                                        BetaManagedAgentsSessionThreadStatusRunningEvent |
                                        BetaManagedAgentsSessionThreadStatusIdleEvent |
                                        BetaManagedAgentsSessionThreadStatusRescheduledEvent |
                                        BetaManagedAgentsSessionThreadStatusTerminatedEvent |
                                        BetaManagedAgentsWorkflowRunCreatedEvent |
                                        BetaManagedAgentsWorkflowRunStatusRunningEvent |
                                        BetaManagedAgentsWorkflowRunStatusIdleEvent |
                                        BetaManagedAgentsWorkflowRunStatusEndedEvent |
                                        BetaManagedAgentsWorkflowRunErrorEvent |
                                        BetaManagedAgentsWorkflowRunPhaseStartedEvent |
                                        BetaManagedAgentsWorkflowRunPhaseEndedEvent |
                                        GenericBetaManagedAgentsSessionEvent

  module BetaManagedAgentsSessionEventConverter
    PARSERS = {
      "session.error"                     => ->(raw : String) { BetaManagedAgentsSessionErrorEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.status_running"            => ->(raw : String) { BetaManagedAgentsSessionStatusRunningEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.status_idle"               => ->(raw : String) { BetaManagedAgentsSessionStatusIdleEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.status_rescheduled"        => ->(raw : String) { BetaManagedAgentsSessionStatusRescheduledEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.status_terminated"         => ->(raw : String) { BetaManagedAgentsSessionStatusTerminatedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.deleted"                   => ->(raw : String) { BetaManagedAgentsSessionDeletedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.updated"                   => ->(raw : String) { BetaManagedAgentsSessionUpdatedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.usage"                     => ->(raw : String) { BetaManagedAgentsSessionUsageEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.thread_created"            => ->(raw : String) { BetaManagedAgentsSessionThreadCreatedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.thread_status_running"     => ->(raw : String) { BetaManagedAgentsSessionThreadStatusRunningEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.thread_status_idle"        => ->(raw : String) { BetaManagedAgentsSessionThreadStatusIdleEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.thread_status_rescheduled" => ->(raw : String) { BetaManagedAgentsSessionThreadStatusRescheduledEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "session.thread_status_terminated"  => ->(raw : String) { BetaManagedAgentsSessionThreadStatusTerminatedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.created"              => ->(raw : String) { BetaManagedAgentsWorkflowRunCreatedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.status_running"       => ->(raw : String) { BetaManagedAgentsWorkflowRunStatusRunningEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.status_idle"          => ->(raw : String) { BetaManagedAgentsWorkflowRunStatusIdleEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.status_ended"         => ->(raw : String) { BetaManagedAgentsWorkflowRunStatusEndedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.error"                => ->(raw : String) { BetaManagedAgentsWorkflowRunErrorEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.phase_started"        => ->(raw : String) { BetaManagedAgentsWorkflowRunPhaseStartedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
      "workflow_run.phase_ended"          => ->(raw : String) { BetaManagedAgentsWorkflowRunPhaseEndedEvent.from_json(raw).as(BetaManagedAgentsSessionEvent) },
    }

    def self.parse_any(json : JSON::Any) : BetaManagedAgentsSessionEvent
      type = json["type"]?.try(&.as_s?) || "unknown"
      if parser = PARSERS[type]?
        parser.call(json.to_json)
      else
        GenericBetaManagedAgentsSessionEvent.new(type: type, raw: json)
      end
    end

    def self.from_json(pull : JSON::PullParser) : BetaManagedAgentsSessionEvent
      parse_any(JSON::Any.new(pull))
    end

    def self.to_json(value : BetaManagedAgentsSessionEvent, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end
end
