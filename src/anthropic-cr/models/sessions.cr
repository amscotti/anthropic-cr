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

  struct BetaManagedAgentsSession
    include JSON::Serializable

    getter id : String
    getter agent : JSON::Any
    getter stats : JSON::Any
    getter usage : JSON::Any
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
  end

  struct BetaManagedAgentsDeletedSession
    include JSON::Serializable
    getter id : String
    getter type : String = "session_deleted"
  end

  struct BetaSessionListResponse
    include JSON::Serializable
    getter data : Array(BetaManagedAgentsSession)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?

    @[JSON::Field(key: "prev_page")]
    getter prev_page : String?
  end

  struct BetaManagedAgentsSessionThread
    include JSON::Serializable

    getter id : String
    getter agent : JSON::Any
    getter type : String = "session_thread"
    getter status : String # "running" | "idle" | "terminated"

    @[JSON::Field(key: "session_id")]
    getter session_id : String

    @[JSON::Field(key: "parent_thread_id")]
    getter parent_thread_id : String?

    getter stats : JSON::Any?
    getter usage : JSON::Any?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  struct BetaSessionThreadListResponse
    include JSON::Serializable
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
end
