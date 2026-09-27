module Anthropic
  struct BetaPackages
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter apt : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter cargo : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter gem : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter go : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter npm : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter pip : Array(String)?

    getter type : String = "packages"

    def initialize(
      @apt : Array(String)? = nil,
      @cargo : Array(String)? = nil,
      @gem : Array(String)? = nil,
      @go : Array(String)? = nil,
      @npm : Array(String)? = nil,
      @pip : Array(String)? = nil,
    )
    end
  end

  struct BetaUnrestrictedNetwork
    include JSON::Serializable
    getter type : String = "unrestricted"

    def initialize
    end
  end

  struct BetaLimitedNetwork
    include JSON::Serializable

    getter type : String = "limited"

    @[JSON::Field(key: "allow_mcp_servers")]
    getter? allow_mcp_servers : Bool

    @[JSON::Field(key: "allow_package_managers")]
    getter? allow_package_managers : Bool

    @[JSON::Field(key: "allowed_hosts")]
    getter allowed_hosts : Array(String)

    def initialize(
      @allow_mcp_servers : Bool,
      @allow_package_managers : Bool,
      @allowed_hosts : Array(String),
    )
    end
  end

  struct BetaLimitedNetworkParams
    include JSON::Serializable

    getter type : String = "limited"

    @[JSON::Field(key: "allow_mcp_servers", emit_null: false)]
    getter? allow_mcp_servers : Bool?

    @[JSON::Field(key: "allow_package_managers", emit_null: false)]
    getter? allow_package_managers : Bool?

    @[JSON::Field(key: "allowed_hosts", emit_null: false)]
    getter allowed_hosts : Array(String)?

    def initialize(
      @allow_mcp_servers : Bool? = nil,
      @allow_package_managers : Bool? = nil,
      @allowed_hosts : Array(String)? = nil,
    )
    end
  end

  alias BetaNetworkingConfig = BetaUnrestrictedNetwork | BetaLimitedNetwork
  alias BetaNetworkingConfigParam = BetaNetworkingConfig | BetaLimitedNetworkParams

  struct BetaCloudConfig
    include JSON::Serializable

    getter type : String = "cloud"
    getter networking : BetaNetworkingConfig
    getter packages : BetaPackages

    def initialize(@networking : BetaNetworkingConfig, @packages : BetaPackages)
    end
  end

  struct BetaCloudConfigParams
    include JSON::Serializable

    getter type : String = "cloud"

    @[JSON::Field(emit_null: false)]
    getter networking : BetaNetworkingConfigParam?

    @[JSON::Field(emit_null: false)]
    getter packages : BetaPackages?

    def initialize(@networking : BetaNetworkingConfigParam? = nil, @packages : BetaPackages? = nil)
    end
  end

  struct BetaSelfHostedConfig
    include JSON::Serializable
    getter type : String = "self_hosted"

    def initialize
    end
  end

  alias BetaEnvironmentConfig = BetaCloudConfig | BetaSelfHostedConfig
  alias BetaEnvironmentConfigParam = BetaEnvironmentConfig | BetaCloudConfigParams

  struct BetaEnvironment
    include JSON::Serializable

    getter id : String
    getter name : String
    getter type : String = "environment"
    getter config : BetaEnvironmentConfig
    getter description : String?
    getter metadata : Hash(String, String)
    getter scope : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  struct BetaEnvironmentDeleteResponse
    include JSON::Serializable
    getter id : String
    getter type : String = "environment_deleted"
  end

  struct BetaEnvironmentListResponse
    include JSON::Serializable
    getter data : Array(BetaEnvironment)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Work payload for session-backed self-hosted work.
  struct BetaSessionWorkData
    include JSON::Serializable

    getter id : String
    getter type : String = "session"
  end

  # Work payload for healthcheck self-hosted work.
  struct BetaHealthCheckWorkData
    include JSON::Serializable

    getter id : String
    getter type : String = "healthcheck"
  end

  # Payload carried by a self-hosted work item.
  alias BetaSelfHostedWorkData = BetaSessionWorkData | BetaHealthCheckWorkData

  # Discriminated-union converter for work payloads.
  module BetaSelfHostedWorkDataConverter
    def self.from_json(pull : JSON::PullParser) : BetaSelfHostedWorkData
      if pull.kind.null?
        raise JSON::ParseException.new("Missing work data", 0, 0)
      end

      json = JSON::Any.new(pull)
      raw = json.to_json

      case json["type"]?.try(&.as_s?)
      when "healthcheck"
        BetaHealthCheckWorkData.from_json(raw)
      when "session", nil
        BetaSessionWorkData.from_json(raw)
      else
        raise JSON::ParseException.new("Unknown work data type: #{json["type"]?}", 0, 0)
      end
    end

    def self.to_json(value : BetaSelfHostedWorkData, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # A unit of work queued for a self-hosted environment worker.
  struct BetaSelfHostedWork
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "acknowledged_at")]
    getter acknowledged_at : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(converter: Anthropic::BetaSelfHostedWorkDataConverter)]
    getter data : BetaSelfHostedWorkData

    @[JSON::Field(key: "environment_id")]
    getter environment_id : String

    @[JSON::Field(key: "latest_heartbeat_at")]
    getter latest_heartbeat_at : String?

    getter metadata : Hash(String, String)

    getter secret : String?

    @[JSON::Field(key: "started_at")]
    getter started_at : String?

    # `"queued"` | `"starting"` | `"active"` | `"stopping"` | `"stopped"`
    getter state : String

    @[JSON::Field(key: "stop_requested_at")]
    getter stop_requested_at : String?

    @[JSON::Field(key: "stopped_at")]
    getter stopped_at : String?

    getter type : String = "work"
  end

  # Paginated list of self-hosted work items.
  struct BetaSelfHostedWorkListResponse
    include JSON::Serializable
    getter data : Array(BetaSelfHostedWork)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Response to a work heartbeat, carrying the renewed lease.
  struct BetaSelfHostedWorkHeartbeatResponse
    include JSON::Serializable

    @[JSON::Field(key: "last_heartbeat")]
    getter last_heartbeat : String

    @[JSON::Field(key: "lease_extended")]
    getter? lease_extended : Bool

    # `"queued"` | `"starting"` | `"active"` | `"stopping"` | `"stopped"`
    getter state : String

    @[JSON::Field(key: "ttl_seconds")]
    getter ttl_seconds : Int32

    getter type : String = "work_heartbeat"
  end

  # Queue statistics for a self-hosted environment.
  struct BetaSelfHostedWorkQueueStats
    include JSON::Serializable

    getter depth : Int32

    @[JSON::Field(key: "oldest_queued_at")]
    getter oldest_queued_at : String?

    getter pending : Int32
    getter type : String = "work_queue_stats"

    @[JSON::Field(key: "workers_polling")]
    getter workers_polling : Int32?
  end
end
