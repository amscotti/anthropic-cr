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

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
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

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end
end
