module Anthropic
  # Installation preferences for plugins and plugin marketplaces.
  module BetaPluginInstallationPreference
    AUTO_INSTALL  = "auto_install"
    AVAILABLE     = "available"
    NOT_AVAILABLE = "not_available"
    REQUIRED      = "required"
  end

  # Marketplace sync statuses.
  module BetaPluginMarketplaceSyncStatus
    FAILED_AUTH      = "failed_auth"
    FAILED_CONTENT   = "failed_content"
    FAILED_LIMITS    = "failed_limits"
    FAILED_TRANSIENT = "failed_transient"
    IN_PROGRESS      = "in_progress"
    SUCCESS          = "success"
  end

  # Marketplace source types.
  module BetaPluginMarketplaceSource
    DIRECTORY  = "directory"
    GITHUB     = "github"
    GITLAB     = "gitlab"
    MANUAL     = "manual"
    PUBLIC_GIT = "public_git"
  end

  # Plugin reach classifications.
  module BetaPluginReach
    CONTAINED  = "contained"
    PRIVILEGED = "privileged"
    REMOTE     = "remote"
  end

  # Component declared inside a plugin or plugin version.
  struct BetaPluginComponent
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter description : String?

    getter name : String
    getter type : String
  end

  # Security / content scan state for a plugin or version.
  struct BetaPluginContentScan
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter assessment : String?

    @[JSON::Field(emit_null: false)]
    getter reason : String?

    getter status : String
  end

  # User actor that created or uploaded a plugin.
  struct BetaPluginUserActor
    include JSON::Serializable

    @[JSON::Field(key: "email_address", emit_null: false)]
    getter email_address : String?

    getter type : String = "user_actor"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  # API key actor that created or uploaded a plugin.
  struct BetaPluginAPIActor
    include JSON::Serializable

    @[JSON::Field(key: "api_key_id")]
    getter api_key_id : String

    getter type : String = "api_actor"
  end

  struct BetaPluginGenericActor
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaPluginCreatedBy = BetaPluginUserActor | BetaPluginAPIActor | BetaPluginGenericActor

  module NullableBetaPluginCreatedByConverter
    def self.from_json(pull : JSON::PullParser) : BetaPluginCreatedBy?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "user_actor"
        BetaPluginUserActor.from_json(raw)
      when "api_actor"
        BetaPluginAPIActor.from_json(raw)
      else
        BetaPluginGenericActor.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaPluginCreatedBy?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  # Organization owner of a plugin or marketplace.
  struct BetaPluginOwnerOrganization
    include JSON::Serializable

    getter type : String = "organization"
  end

  # Member user owner of a plugin or marketplace.
  struct BetaPluginOwnerUser
    include JSON::Serializable

    getter type : String = "user"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  struct BetaPluginGenericOwner
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaPluginOwner = BetaPluginOwnerOrganization | BetaPluginOwnerUser | BetaPluginGenericOwner

  module BetaPluginOwnerConverter
    def self.from_json(pull : JSON::PullParser) : BetaPluginOwner
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "organization"
        BetaPluginOwnerOrganization.from_json(raw)
      when "user"
        BetaPluginOwnerUser.from_json(raw)
      else
        BetaPluginGenericOwner.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaPluginOwner, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Organization target for plugin installation settings and shares.
  struct BetaPluginTargetOrganization
    include JSON::Serializable

    getter type : String = "organization"
  end

  # RBAC group target for plugin installation settings and shares.
  struct BetaPluginTargetRbacGroup
    include JSON::Serializable

    @[JSON::Field(key: "rbac_group_id")]
    getter rbac_group_id : String

    getter type : String = "rbac_group"
  end

  alias BetaPluginTargetRBACGroup = BetaPluginTargetRbacGroup

  # Organization member target for plugin shares.
  struct BetaPluginTargetOrganizationMember
    include JSON::Serializable

    getter type : String = "organization_member"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  struct BetaPluginGenericTarget
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaPluginTarget = BetaPluginTargetOrganization |
                           BetaPluginTargetRbacGroup |
                           BetaPluginTargetOrganizationMember |
                           BetaPluginGenericTarget

  module BetaPluginTargetConverter
    def self.from_json(pull : JSON::PullParser) : BetaPluginTarget
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "organization"
        BetaPluginTargetOrganization.from_json(raw)
      when "rbac_group"
        BetaPluginTargetRbacGroup.from_json(raw)
      when "organization_member"
        BetaPluginTargetOrganizationMember.from_json(raw)
      else
        BetaPluginGenericTarget.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaPluginTarget, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # A Claude Enterprise plugin in the organization or owned by a member.
  struct BetaPlugin
    include JSON::Serializable

    getter id : String

    @[JSON::Field(emit_null: false)]
    getter components : Array(BetaPluginComponent)?

    @[JSON::Field(key: "content_scan", emit_null: false)]
    getter content_scan : BetaPluginContentScan?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by", converter: Anthropic::NullableBetaPluginCreatedByConverter, emit_null: false)]
    getter created_by : BetaPluginCreatedBy?

    @[JSON::Field(emit_null: false)]
    getter description : String?

    @[JSON::Field(key: "display_name", emit_null: false)]
    getter display_name : String?

    @[JSON::Field(key: "latest_version_id")]
    getter latest_version_id : String

    @[JSON::Field(key: "manifest_version", emit_null: false)]
    getter manifest_version : String?

    @[JSON::Field(key: "marketplace_id")]
    getter marketplace_id : String

    getter name : String

    @[JSON::Field(key: "organization_installation_preference", emit_null: false)]
    getter organization_installation_preference : String?

    @[JSON::Field(key: "organization_installation_preference_inherited", emit_null: false)]
    getter organization_installation_preference_inherited : Bool?

    @[JSON::Field(converter: Anthropic::BetaPluginOwnerConverter)]
    getter owner : BetaPluginOwner

    @[JSON::Field(emit_null: false)]
    getter reach : String?

    @[JSON::Field(key: "served_version_id")]
    getter served_version_id : String

    @[JSON::Field(key: "served_version_pinned")]
    getter? served_version_pinned : Bool

    getter type : String = "plugin"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  struct BetaDeletedPlugin
    include JSON::Serializable

    getter id : String
    getter type : String = "plugin_deleted"
  end

  struct BetaPluginVersion
    include JSON::Serializable

    getter id : String

    @[JSON::Field(emit_null: false)]
    getter components : Array(BetaPluginComponent)?

    @[JSON::Field(key: "content_scan", emit_null: false)]
    getter content_scan : BetaPluginContentScan?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by", converter: Anthropic::NullableBetaPluginCreatedByConverter, emit_null: false)]
    getter created_by : BetaPluginCreatedBy?

    @[JSON::Field(emit_null: false)]
    getter description : String?

    @[JSON::Field(key: "display_name", emit_null: false)]
    getter display_name : String?

    @[JSON::Field(key: "manifest_version", emit_null: false)]
    getter manifest_version : String?

    @[JSON::Field(key: "plugin_id")]
    getter plugin_id : String

    @[JSON::Field(emit_null: false)]
    getter reach : String?

    @[JSON::Field(key: "release_notes", emit_null: false)]
    getter release_notes : String?

    getter type : String = "plugin_version"
  end

  struct BetaPluginInstallationSetting
    include JSON::Serializable

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "installation_preference")]
    getter installation_preference : String

    @[JSON::Field(key: "plugin_id")]
    getter plugin_id : String

    @[JSON::Field(converter: Anthropic::BetaPluginTargetConverter)]
    getter target : BetaPluginTarget

    getter type : String = "plugin_installation_setting"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  struct BetaDeletedPluginInstallationSetting
    include JSON::Serializable

    @[JSON::Field(key: "plugin_id")]
    getter plugin_id : String

    @[JSON::Field(converter: Anthropic::BetaPluginTargetConverter)]
    getter target : BetaPluginTarget

    getter type : String = "plugin_installation_setting_deleted"
  end

  struct BetaPluginShare
    include JSON::Serializable

    @[JSON::Field(key: "granted_at")]
    getter granted_at : String

    @[JSON::Field(key: "plugin_id")]
    getter plugin_id : String

    @[JSON::Field(converter: Anthropic::BetaPluginTargetConverter)]
    getter target : BetaPluginTarget

    getter type : String = "plugin_share"
  end

  struct BetaPluginMarketplace
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "default_installation_preference", emit_null: false)]
    getter default_installation_preference : String?

    @[JSON::Field(key: "last_sync_ended_at", emit_null: false)]
    getter last_sync_ended_at : String?

    @[JSON::Field(key: "last_sync_read_sha", emit_null: false)]
    getter last_sync_read_sha : String?

    getter name : String

    @[JSON::Field(converter: Anthropic::BetaPluginOwnerConverter)]
    getter owner : BetaPluginOwner

    getter source : String

    @[JSON::Field(key: "sync_status", emit_null: false)]
    getter sync_status : String?

    getter type : String = "plugin_marketplace"
  end

  struct BetaPluginMarketplaceValidationPluginError
    include JSON::Serializable

    getter error : String

    @[JSON::Field(key: "error_code")]
    getter error_code : String

    getter name : String
  end

  struct BetaPluginMarketplaceValidationPluginWarning
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String

    getter message : String
  end

  struct BetaPluginMarketplaceValidationPluginWarnings
    include JSON::Serializable

    getter name : String
    getter warnings : Array(BetaPluginMarketplaceValidationPluginWarning)
  end

  struct BetaPluginMarketplaceValidationReport
    include JSON::Serializable

    @[JSON::Field(key: "commit_sha", emit_null: false)]
    getter commit_sha : String?

    @[JSON::Field(key: "manifest_error", emit_null: false)]
    getter manifest_error : String?

    @[JSON::Field(key: "manifest_error_code", emit_null: false)]
    getter manifest_error_code : String?

    @[JSON::Field(key: "plugin_errors")]
    getter plugin_errors : Array(BetaPluginMarketplaceValidationPluginError)

    @[JSON::Field(key: "plugin_warnings")]
    getter plugin_warnings : Array(BetaPluginMarketplaceValidationPluginWarnings)

    @[JSON::Field(emit_null: false)]
    getter ref : String?

    @[JSON::Field(key: "total_plugin_count")]
    getter total_plugin_count : Int64

    getter type : String = "plugin_marketplace_validation_report"
    getter? valid : Bool
  end
end
