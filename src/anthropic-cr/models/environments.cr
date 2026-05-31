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

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end
end
