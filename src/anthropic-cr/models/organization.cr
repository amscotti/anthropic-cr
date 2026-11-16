module Anthropic
  # Organization information for the authenticated API key.
  struct BetaOrganization
    include JSON::Serializable

    # ID of the organization.
    getter id : String

    # Name of the organization.
    getter name : String

    # Object type. Always `"organization"`.
    getter type : String = "organization"
  end

  alias Organization = BetaOrganization

  # Organization-level roles for users and invites.
  #
  # Includes GA/2026-10-21 roles (`"admin"`, `"billing"`,
  # `"claude_code_user"`, `"developer"`, `"managed"`, `"membership_admin"`,
  # `"owner"`, `"primary_owner"`, `"user"`) and legacy `"support"`.
  module OrganizationRole
    ADMIN            = "admin"
    BILLING          = "billing"
    CLAUDE_CODE_USER = "claude_code_user"
    DEVELOPER        = "developer"
    MANAGED          = "managed"
    MEMBERSHIP_ADMIN = "membership_admin"
    OWNER            = "owner"
    PRIMARY_OWNER    = "primary_owner"
    SUPPORT          = "support"
    USER             = "user"
  end

  # Workspace roles assignable to members and service accounts.
  #
  # Canonical roles are `"workspace_admin"`, `"workspace_billing"`,
  # `"workspace_developer"`, `"workspace_restricted_developer"`, and
  # `"workspace_user"`. Legacy short names are retained for backwards
  # compatibility.
  module WorkspaceRole
    WORKSPACE_ADMIN                = "workspace_admin"
    WORKSPACE_BILLING              = "workspace_billing"
    WORKSPACE_DEVELOPER            = "workspace_developer"
    WORKSPACE_RESTRICTED_DEVELOPER = "workspace_restricted_developer"
    WORKSPACE_USER                 = "workspace_user"

    # Legacy short names retained for backwards compatibility.
    ADMIN      = "admin"
    DEVELOPER  = "developer"
    USER       = "user"
    BILLING    = "billing"
    SUPPORT    = "support"
    NO_BILLING = "no_billing"
  end

  # Non-billing workspace roles for workspace membership updates and
  # service-account workspace memberships.
  module NoBillingWorkspaceRole
    WORKSPACE_ADMIN                = "workspace_admin"
    WORKSPACE_DEVELOPER            = "workspace_developer"
    WORKSPACE_RESTRICTED_DEVELOPER = "workspace_restricted_developer"
    WORKSPACE_USER                 = "workspace_user"
  end

  # API key lifecycle statuses.
  module APIKeyStatus
    ACTIVE   = "active"
    ARCHIVED = "archived"
    EXPIRED  = "expired"
    INACTIVE = "inactive"
  end

  alias BetaAPIKeyStatus = APIKeyStatus

  # Actor that created an API key.
  struct APIKeyCreatedBy
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter id : String?

    getter type : String

    def initialize(@type : String, @id : String? = nil)
    end
  end

  # Organization-level scope for an API key.
  struct APIKeyOrganizationScope
    include JSON::Serializable

    getter type : String = "organization"

    def initialize(@type : String = "organization")
    end
  end

  # Workspace-level scope for an API key.
  struct APIKeyWorkspaceScope
    include JSON::Serializable

    getter type : String = "workspace"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    def initialize(@workspace_id : String, @type : String = "workspace")
    end
  end

  # User actor principal bound to an API key.
  struct APIKeyUserActor
    include JSON::Serializable

    getter type : String = "user_actor"

    @[JSON::Field(key: "user_id")]
    getter user_id : String

    def initialize(@user_id : String, @type : String = "user_actor")
    end
  end

  # Service account actor principal bound to an API key.
  struct APIKeyServiceAccountActor
    include JSON::Serializable

    @[JSON::Field(key: "service_account_id")]
    getter service_account_id : String

    getter type : String = "service_account_actor"

    def initialize(@service_account_id : String, @type : String = "service_account_actor")
    end
  end

  alias APIKeyScope = APIKeyOrganizationScope | APIKeyWorkspaceScope
  alias APIKeyPrincipal = APIKeyOrganizationScope | APIKeyWorkspaceScope | APIKeyUserActor | APIKeyServiceAccountActor

  # An API key in the organization.
  struct BetaAPIKey
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Actor that created the key (`nil` for system/legacy keys).
    @[JSON::Field(key: "created_by", emit_null: false)]
    getter created_by : JSON::Any? = nil

    @[JSON::Field(key: "expires_at", emit_null: false)]
    getter expires_at : String? = nil

    getter name : String

    @[JSON::Field(key: "partial_key_hint", emit_null: false)]
    getter partial_key_hint : String? = nil

    # Principal the API key acts as (`user_actor`, `service_account_actor`, or `nil`).
    @[JSON::Field(emit_null: false)]
    getter principal : JSON::Any? = nil

    # Key scope shape (`{"type": "organization"}` or `{"type": "workspace", "workspace_id": ...}`).
    getter scope : JSON::Any

    # Key status: `"active"`, `"archived"`, `"expired"`, or `"inactive"`.
    getter status : String

    # Object type. Always `"api_key"`.
    getter type : String = "api_key"

    @[JSON::Field(key: "workspace_id", emit_null: false)]
    getter raw_workspace_id : String? = nil

    # Workspace ID when explicitly present or carried inside a workspace `scope`.
    def workspace_id : String?
      @raw_workspace_id || scope["workspace_id"]?.try(&.as_s?)
    end

    # Parse `scope` into a typed scope struct when recognized.
    def parsed_scope : APIKeyScope?
      case scope["type"]?.try(&.as_s?)
      when "organization"
        APIKeyOrganizationScope.from_json(scope.to_json)
      when "workspace"
        APIKeyWorkspaceScope.from_json(scope.to_json) if scope["workspace_id"]?.try(&.as_s?)
      else
        nil
      end
    end

    # Parse `principal` into a typed principal/actor struct when present and recognized.
    def parsed_principal : APIKeyPrincipal?
      raw = @principal
      return nil unless raw

      case raw["type"]?.try(&.as_s?)
      when "user_actor"
        APIKeyUserActor.from_json(raw.to_json) if raw["user_id"]?.try(&.as_s?)
      when "service_account_actor"
        APIKeyServiceAccountActor.from_json(raw.to_json) if raw["service_account_id"]?.try(&.as_s?)
      when "organization", "organization_scope"
        APIKeyOrganizationScope.new(type: raw["type"].as_s)
      when "workspace", "workspace_scope"
        if ws_id = raw["workspace_id"]?.try(&.as_s?)
          APIKeyWorkspaceScope.new(workspace_id: ws_id, type: raw["type"].as_s)
        end
      else
        nil
      end
    end

    # Parse `created_by` into a typed actor struct when present.
    def parsed_created_by : APIKeyCreatedBy?
      raw = @created_by
      return nil unless raw && raw["type"]?.try(&.as_s?)
      APIKeyCreatedBy.from_json(raw.to_json)
    end
  end

  alias APIKey = BetaAPIKey

  # Paginated list of organization API keys.
  struct BetaAPIKeyListResponse
    include JSON::Serializable

    getter data : Array(BetaAPIKey)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  alias APIKeyListResponse = BetaAPIKeyListResponse

  # An external (BYO-cloud) key attached to the organization.
  #
  # `attachment` and `provider_config` carry provider-specific shapes and
  # are exposed as `JSON::Any`.
  struct BetaExternalKey
    include JSON::Serializable

    getter id : String

    getter attachment : JSON::Any

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "display_name", emit_null: false)]
    getter display_name : String?

    # Key geography (e.g. `"us"`).
    getter geo : String

    @[JSON::Field(key: "provider_config")]
    getter provider_config : JSON::Any

    # Object type. Always `"external_key"`.
    getter type : String = "external_key"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "user_profile_id", emit_null: false)]
    getter user_profile_id : String? = nil
  end

  alias ExternalKey = BetaExternalKey

  # Paginated list of external keys.
  struct BetaExternalKeyListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaExternalKey)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias ExternalKeyListResponse = BetaExternalKeyListResponse

  # Confirmation returned when an external key is deleted.
  struct BetaDeletedExternalKey
    include JSON::Serializable

    getter id : String

    # Object type. Always `"external_key_deleted"`.
    getter type : String = "external_key_deleted"
  end

  alias DeletedExternalKey = BetaDeletedExternalKey

  # Result of validating an external key.
  struct BetaExternalKeyValidation
    include JSON::Serializable

    # Validation error detail (`nil` when valid).
    @[JSON::Field(emit_null: false)]
    getter error : String?

    # Validation status: `"valid"` or `"invalid"`.
    getter status : String

    # Object type. Always `"external_key_validation"`.
    getter type : String = "external_key_validation"
  end

  alias ExternalKeyValidation = BetaExternalKeyValidation

  # A pending or accepted organization invite.
  struct BetaOrganizationInvite
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "accepted_at", emit_null: false)]
    getter accepted_at : String?

    getter email : String

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    @[JSON::Field(key: "invited_at")]
    getter invited_at : String

    @[JSON::Field(key: "rbac_group_ids")]
    getter rbac_group_ids : Array(String) = [] of String

    getter role : String

    # Invite status: `"pending"`, `"accepted"`, `"expired"`, or `"deleted"`.
    getter status : String

    # Object type. Always `"invite"`.
    getter type : String = "invite"
  end

  alias OrganizationInvite = BetaOrganizationInvite

  # Paginated list of organization invites.
  struct BetaOrganizationInviteListResponse
    include JSON::Serializable

    getter data : Array(BetaOrganizationInvite)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  alias OrganizationInviteListResponse = BetaOrganizationInviteListResponse

  # Confirmation returned when an invite is deleted.
  struct BetaDeletedInvite
    include JSON::Serializable

    getter id : String

    # Object type. Always `"invite_deleted"`.
    getter type : String = "invite_deleted"
  end

  alias DeletedInvite = BetaDeletedInvite

  # A member user of the organization.
  struct BetaOrganizationUser
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "added_at")]
    getter added_at : String

    getter email : String

    getter name : String

    getter role : String

    # Object type. Always `"user"`.
    getter type : String = "user"
  end

  alias OrganizationUser = BetaOrganizationUser

  # Paginated list of organization users.
  struct BetaOrganizationUserListResponse
    include JSON::Serializable

    getter data : Array(BetaOrganizationUser)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  alias OrganizationUserListResponse = BetaOrganizationUserListResponse

  # Confirmation returned when a user is removed.
  struct BetaDeletedOrganizationUser
    include JSON::Serializable

    getter id : String

    # Object type. Always `"user_deleted"`.
    getter type : String = "user_deleted"
  end

  alias DeletedOrganizationUser = BetaDeletedOrganizationUser

  # A single rate-limit value entry.
  struct BetaOrganizationRateLimitValue
    include JSON::Serializable

    getter type : String
    getter value : Int64

    def initialize(@type : String, @value : Int64)
    end
  end

  alias OrganizationRateLimitValue = BetaOrganizationRateLimitValue

  # A rate-limit group applying to a model.
  struct BetaOrganizationRateLimitModelGroup
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Group type. Always `"model_group"`.
    getter type : String = "model_group"
  end

  alias OrganizationRateLimitModelGroup = BetaOrganizationRateLimitModelGroup

  # A rate-limit group applying to batches.
  struct BetaOrganizationRateLimitBatchGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"batch"`.
    getter type : String = "batch"
  end

  alias OrganizationRateLimitBatchGroup = BetaOrganizationRateLimitBatchGroup

  # A rate-limit group applying to files.
  struct BetaOrganizationRateLimitFilesGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"files"`.
    getter type : String = "files"
  end

  alias OrganizationRateLimitFilesGroup = BetaOrganizationRateLimitFilesGroup

  # A rate-limit group applying to skills.
  struct BetaOrganizationRateLimitSkillsGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"skills"`.
    getter type : String = "skills"
  end

  alias OrganizationRateLimitSkillsGroup = BetaOrganizationRateLimitSkillsGroup

  # A rate-limit group applying to token counting.
  struct BetaOrganizationRateLimitTokenCountGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"token_count"`.
    getter type : String = "token_count"
  end

  alias OrganizationRateLimitTokenCountGroup = BetaOrganizationRateLimitTokenCountGroup

  # A rate-limit group applying to web search.
  struct BetaOrganizationRateLimitWebSearchGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"web_search"`.
    getter type : String = "web_search"
  end

  alias OrganizationRateLimitWebSearchGroup = BetaOrganizationRateLimitWebSearchGroup

  # A future rate-limit group type, preserved with its raw payload so
  # unknown shapes don't break response parsing.
  struct BetaOrganizationRateLimitGenericGroup
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    # Serialize back to the original JSON payload.
    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias OrganizationRateLimitGenericGroup = BetaOrganizationRateLimitGenericGroup

  # Discriminated union of rate-limit group variants.
  alias BetaOrganizationRateLimitGroup = BetaOrganizationRateLimitModelGroup | BetaOrganizationRateLimitBatchGroup | BetaOrganizationRateLimitFilesGroup | BetaOrganizationRateLimitSkillsGroup | BetaOrganizationRateLimitTokenCountGroup | BetaOrganizationRateLimitWebSearchGroup | BetaOrganizationRateLimitGenericGroup
  alias OrganizationRateLimitGroup = BetaOrganizationRateLimitGroup

  # Converter for a single BetaOrganizationRateLimitGroup discriminated by `"type"`.
  module BetaOrganizationRateLimitGroupConverter
    def self.from_json(pull : JSON::PullParser) : BetaOrganizationRateLimitGroup
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "model_group"
        BetaOrganizationRateLimitModelGroup.from_json(raw)
      when "batch"
        BetaOrganizationRateLimitBatchGroup.from_json(raw)
      when "files"
        BetaOrganizationRateLimitFilesGroup.from_json(raw)
      when "skills"
        BetaOrganizationRateLimitSkillsGroup.from_json(raw)
      when "token_count"
        BetaOrganizationRateLimitTokenCountGroup.from_json(raw)
      when "web_search"
        BetaOrganizationRateLimitWebSearchGroup.from_json(raw)
      else
        BetaOrganizationRateLimitGenericGroup.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaOrganizationRateLimitGroup, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # A rate limit applying to a model/group combination.
  struct BetaOrganizationRateLimit
    include JSON::Serializable

    getter id : String

    # The group this limit applies to (carries `display_name` on model groups).
    @[JSON::Field(converter: Anthropic::BetaOrganizationRateLimitGroupConverter)]
    getter group : BetaOrganizationRateLimitGroup

    # Deprecated in favor of `group`; omitted in newer API payloads.
    @[JSON::Field(key: "group_type", emit_null: false)]
    getter group_type : String? = nil

    getter limits : JSON::Any

    # Models covered by this limit (`nil` for non-model groups).
    @[JSON::Field(emit_null: false)]
    getter models : Array(String)?

    # Object type. Always `"rate_limit"`.
    getter type : String = "rate_limit"

    # Extract limiter entries whether `limits` is returned as an array or object.
    def limit_values : Array(BetaOrganizationRateLimitValue)
      if arr = limits.as_a?
        return arr.map { |item| BetaOrganizationRateLimitValue.from_json(item.to_json) }
      end
      if obj = limits.as_h?
        return obj.compact_map do |key, entry|
          if val = entry["value"]?.try(&.as_i64?)
            BetaOrganizationRateLimitValue.new(type: key, value: val)
          end
        end
      end
      [] of BetaOrganizationRateLimitValue
    end
  end

  alias OrganizationRateLimit = BetaOrganizationRateLimit

  # Paginated list of organization rate limits.
  struct BetaOrganizationRateLimitListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaOrganizationRateLimit)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias OrganizationRateLimitListResponse = BetaOrganizationRateLimitListResponse

  # Known workspace rate-limit limiter types.
  module WorkspaceRateLimitType
    FAST_ITPMCA                         = "fast_itpmca"
    FAST_OTPM                           = "fast_otpm"
    INPUT_TOKENS_PER_MINUTE             = "input_tokens_per_minute"
    INPUT_TOKENS_PER_MINUTE_CACHE_AWARE = "input_tokens_per_minute_cache_aware"
    OUTPUT_TOKENS_PER_MINUTE            = "output_tokens_per_minute"
    REQUESTS_PER_MINUTE                 = "requests_per_minute"
    TOKENS_PER_DAY                      = "tokens_per_day"
    TOKENS_PER_MINUTE                   = "tokens_per_minute"
    TOOL_USES_PER_SECOND                = "tool_uses_per_second"
  end

  # Indicates a workspace rate-limit value comes from a workspace override.
  struct WorkspaceRateLimitWorkspaceSource
    include JSON::Serializable

    getter type : String = "workspace"
  end

  # Indicates a workspace rate-limit value is inherited from the organization.
  struct WorkspaceRateLimitOrganizationSource
    include JSON::Serializable

    getter type : String = "organization"
  end

  # Forward-compatible fallback for future workspace rate-limit source variants.
  struct WorkspaceRateLimitGenericSource
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias WorkspaceRateLimitSource = WorkspaceRateLimitWorkspaceSource | WorkspaceRateLimitOrganizationSource | WorkspaceRateLimitGenericSource

  module WorkspaceRateLimitSourceConverter
    def self.from_json(pull : JSON::PullParser) : WorkspaceRateLimitSource
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "workspace"
        WorkspaceRateLimitWorkspaceSource.from_json(raw)
      when "organization"
        WorkspaceRateLimitOrganizationSource.from_json(raw)
      else
        WorkspaceRateLimitGenericSource.new(type: type, raw: json)
      end
    end

    def self.to_json(value : WorkspaceRateLimitSource, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # Single rate-limit value entry on a workspace rate limit.
  struct WorkspaceRateLimitValue
    include JSON::Serializable

    @[JSON::Field(key: "org_limit", emit_null: false)]
    getter org_limit : Int64?

    @[JSON::Field(converter: Anthropic::WorkspaceRateLimitSourceConverter)]
    getter source : WorkspaceRateLimitSource

    getter type : String
    getter value : Int64
  end

  # Update payload item for `workspaces.rate_limits.update`.
  #
  # Pass `value: nil` to clear a workspace override so the workspace inherits
  # the organization-level limit.
  struct WorkspaceRateLimitUpdateValue
    include JSON::Serializable

    getter type : String

    @[JSON::Field(emit_null: true)]
    getter value : Int64?

    def initialize(@type : String, @value : Int64? = nil)
    end
  end

  # Rate-limit overrides for a workspace group.
  struct WorkspaceRateLimit
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaOrganizationRateLimitGroupConverter)]
    getter group : BetaOrganizationRateLimitGroup

    getter limits : Array(WorkspaceRateLimitValue)

    @[JSON::Field(emit_null: false)]
    getter models : Array(String)?

    @[JSON::Field(key: "rate_limit_id")]
    getter rate_limit_id : String

    getter type : String = "workspace_rate_limit"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  alias BetaWorkspaceRateLimit = WorkspaceRateLimit
  alias BetaWorkspaceRateLimitValue = WorkspaceRateLimitValue
  alias BetaWorkspaceRateLimitUpdateValue = WorkspaceRateLimitUpdateValue
  alias BetaWorkspaceRateLimitType = WorkspaceRateLimitType

  # Paginated list of workspace rate limits.
  struct WorkspaceRateLimitListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(WorkspaceRateLimit)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias BetaWorkspaceRateLimitListResponse = WorkspaceRateLimitListResponse

  # Organization compliance settings state.
  #
  # `state` is `{type: "enabled"}` or `{type: "disabled"}` (retention
  # details ride along on the enabled shape) and is exposed as `JSON::Any`.
  struct BetaComplianceSettings
    include JSON::Serializable

    getter state : JSON::Any

    # Object type. Always `"compliance_settings"`.
    getter type : String = "compliance_settings"
  end

  alias ComplianceSettings = BetaComplianceSettings

  # Allowed inference geographies for beta data-residency configuration.
  module BetaAllowedInferenceGeo
    GLOBAL = "global"
    US     = "us"
  end

  alias AllowedInferenceGeo = BetaAllowedInferenceGeo

  # Data-residency configuration for a workspace.
  #
  # `allowed_inference_geos` is either a list of
  # `BetaAllowedInferenceGeo` values or the string `"unrestricted"`,
  # which allows all geos.
  struct BetaDataResidency
    include JSON::Serializable

    # Sentinel meaning all inference geos are allowed.
    UNRESTRICTED = "unrestricted"

    @[JSON::Field(key: "allowed_inference_geos")]
    getter allowed_inference_geos : Array(String) | String

    @[JSON::Field(key: "default_inference_geo")]
    getter default_inference_geo : String

    @[JSON::Field(key: "workspace_geo")]
    getter workspace_geo : String

    def initialize(
      @allowed_inference_geos : Array(String) | String,
      @default_inference_geo : String,
      @workspace_geo : String,
    )
    end

    # Whether all inference geos are allowed.
    def unrestricted? : Bool
      allowed_inference_geos == UNRESTRICTED
    end
  end

  alias DataResidency = BetaDataResidency

  # Data-residency configuration accepted when creating a workspace.
  #
  # Omitted fields fall back to API defaults (`allowed_inference_geos`
  # defaults to `"unrestricted"`, `default_inference_geo` to `"global"`,
  # and `workspace_geo` to `"us"`).
  struct BetaDataResidencyCreateConfig
    include JSON::Serializable

    @[JSON::Field(key: "allowed_inference_geos", emit_null: false)]
    getter allowed_inference_geos : Array(String) | String?

    @[JSON::Field(key: "default_inference_geo", emit_null: false)]
    getter default_inference_geo : String?

    @[JSON::Field(key: "workspace_geo", emit_null: false)]
    getter workspace_geo : String?

    def initialize(
      @allowed_inference_geos : Array(String) | String? = nil,
      @default_inference_geo : String? = nil,
      @workspace_geo : String? = nil,
    )
    end
  end

  alias DataResidencyCreateConfig = BetaDataResidencyCreateConfig

  # Data-residency configuration accepted when updating a workspace.
  struct BetaDataResidencyUpdateConfig
    include JSON::Serializable

    @[JSON::Field(key: "allowed_inference_geos", emit_null: false)]
    getter allowed_inference_geos : Array(String) | String?

    @[JSON::Field(key: "default_inference_geo", emit_null: false)]
    getter default_inference_geo : String?

    def initialize(
      @allowed_inference_geos : Array(String) | String? = nil,
      @default_inference_geo : String? = nil,
    )
    end
  end

  alias DataResidencyUpdateConfig = BetaDataResidencyUpdateConfig

  # A workspace in the organization.
  struct BetaWorkspace
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "compartment_id")]
    getter compartment_id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "data_residency", emit_null: false)]
    getter data_residency : BetaDataResidency?

    @[JSON::Field(key: "display_color")]
    getter display_color : String

    @[JSON::Field(key: "external_key_id", emit_null: false)]
    getter external_key_id : String?

    getter name : String

    getter tags : Hash(String, String)

    # Object type. Always `"workspace"`.
    getter type : String = "workspace"

    @[JSON::Field(key: "user_profile_id", emit_null: false)]
    getter user_profile_id : String? = nil
  end

  alias Workspace = BetaWorkspace

  # Paginated list of workspaces.
  struct BetaWorkspaceListResponse
    include JSON::Serializable

    getter data : Array(BetaWorkspace)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  alias WorkspaceListResponse = BetaWorkspaceListResponse

  # A user's membership in a workspace.
  struct BetaWorkspaceMember
    include JSON::Serializable

    # Object type. Always `"workspace_member"`.
    getter type : String = "workspace_member"

    @[JSON::Field(key: "user_id")]
    getter user_id : String

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    @[JSON::Field(key: "workspace_role")]
    getter workspace_role : String
  end

  alias WorkspaceMember = BetaWorkspaceMember

  # Confirmation returned when a user is removed from a workspace.
  struct BetaDeletedWorkspaceMember
    include JSON::Serializable

    # Object type. Always `"workspace_member_deleted"`.
    getter type : String = "workspace_member_deleted"

    @[JSON::Field(key: "user_id")]
    getter user_id : String

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  alias DeletedWorkspaceMember = BetaDeletedWorkspaceMember

  # Paginated list of workspace members.
  struct BetaWorkspaceMemberListResponse
    include JSON::Serializable

    getter data : Array(BetaWorkspaceMember)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  alias WorkspaceMemberListResponse = BetaWorkspaceMemberListResponse

  # A service account in the organization.
  struct BetaServiceAccount
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "archived_by_actor_id", emit_null: false)]
    getter archived_by_actor_id : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by_actor_id", emit_null: false)]
    getter created_by_actor_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter description : String? = nil

    getter name : String

    @[JSON::Field(key: "organization_role")]
    getter organization_role : JSON::Any

    # Object type. Always `"service_account"`.
    getter type : String = "service_account"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "updated_by_actor_id", emit_null: false)]
    getter updated_by_actor_id : String? = nil
  end

  alias ServiceAccount = BetaServiceAccount

  # Paginated list of service accounts.
  struct BetaServiceAccountListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaServiceAccount)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias ServiceAccountListResponse = BetaServiceAccountListResponse

  # A service account's membership in a workspace.
  struct BetaServiceAccountWorkspaceMember
    include JSON::Serializable

    @[JSON::Field(key: "created_by_actor_id", emit_null: false)]
    getter created_by_actor_id : String? = nil

    getter? implicit : Bool

    @[JSON::Field(key: "service_account_id")]
    getter service_account_id : String

    # Object type. Always `"service_account_workspace_member"`.
    getter type : String = "service_account_workspace_member"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    @[JSON::Field(key: "workspace_role")]
    getter workspace_role : String
  end

  alias ServiceAccountWorkspaceMember = BetaServiceAccountWorkspaceMember

  # Paginated list of service-account workspace memberships.
  struct BetaServiceAccountWorkspaceMemberListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaServiceAccountWorkspaceMember)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias ServiceAccountWorkspaceMemberListResponse = BetaServiceAccountWorkspaceMemberListResponse

  # Confirmation returned when a service account is removed from a workspace.
  struct BetaDeletedServiceAccountWorkspaceMember
    include JSON::Serializable

    @[JSON::Field(key: "service_account_id")]
    getter service_account_id : String

    # Object type. Always `"service_account_workspace_member_deleted"`.
    getter type : String = "service_account_workspace_member_deleted"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  alias DeletedServiceAccountWorkspaceMember = BetaDeletedServiceAccountWorkspaceMember

  # JWKS polling status for a federation issuer.
  struct BetaFederationIssuerPollStatus
    include JSON::Serializable

    @[JSON::Field(key: "consecutive_failures")]
    getter consecutive_failures : Int64

    @[JSON::Field(key: "last_fetched_at")]
    getter last_fetched_at : String

    @[JSON::Field(key: "next_poll_at")]
    getter next_poll_at : String
  end

  alias FederationIssuerPollStatus = BetaFederationIssuerPollStatus

  # A workload-identity federation issuer.
  #
  # `jwks` carries one of the `discovery`, `explicit_url`, or `inline`
  # shapes and is exposed as `JSON::Any`.
  struct BetaFederationIssuer
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "archived_by_actor_id", emit_null: false)]
    getter archived_by_actor_id : String?

    @[JSON::Field(key: "check_jti")]
    getter? check_jti : Bool

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by_actor_id", emit_null: false)]
    getter created_by_actor_id : String? = nil

    @[JSON::Field(key: "issuer_url")]
    getter issuer_url : String

    getter jwks : JSON::Any

    @[JSON::Field(key: "jwks_polling_disabled_at", emit_null: false)]
    getter jwks_polling_disabled_at : String?

    @[JSON::Field(key: "max_jwt_lifetime_seconds")]
    getter max_jwt_lifetime_seconds : Int64

    getter name : String

    @[JSON::Field(key: "poll_status")]
    getter poll_status : BetaFederationIssuerPollStatus

    # Object type. Always `"federation_issuer"`.
    getter type : String = "federation_issuer"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "updated_by_actor_id", emit_null: false)]
    getter updated_by_actor_id : String? = nil
  end

  alias FederationIssuer = BetaFederationIssuer

  # Paginated list of federation issuers.
  struct BetaFederationIssuerListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaFederationIssuer)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias FederationIssuerListResponse = BetaFederationIssuerListResponse

  # JWT match conditions for a federation rule.
  struct BetaFederationRuleMatch
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter audience : String?

    @[JSON::Field(emit_null: false)]
    getter claims : Hash(String, String)?

    @[JSON::Field(emit_null: false)]
    getter condition : String?

    @[JSON::Field(key: "subject_prefix", emit_null: false)]
    getter subject_prefix : String?

    def initialize(
      @audience : String? = nil,
      @claims : Hash(String, String)? = nil,
      @condition : String? = nil,
      @subject_prefix : String? = nil,
    )
    end
  end

  alias FederationRuleMatch = BetaFederationRuleMatch

  # A workload-identity federation rule.
  struct BetaFederationRule
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "applies_to_all_workspaces")]
    getter? applies_to_all_workspaces : Bool

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "archived_by_actor_id", emit_null: false)]
    getter archived_by_actor_id : String?

    # Not yet supported; always null.
    getter attributes : Hash(String, String)?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by_actor_id")]
    getter created_by_actor_id : String?

    getter description : String?

    @[JSON::Field(key: "issuer_id")]
    getter issuer_id : String

    @[JSON::Field(key: "issuer_name")]
    getter issuer_name : String?

    getter match : BetaFederationRuleMatch

    getter name : String

    @[JSON::Field(key: "oauth_scope")]
    getter oauth_scope : String

    # Service-account target shape (`{type: "service_account", ...}`).
    getter target : JSON::Any

    @[JSON::Field(key: "token_lifetime_seconds")]
    getter token_lifetime_seconds : Int64

    # Object type. Always `"federation_rule"`.
    getter type : String = "federation_rule"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "updated_by_actor_id")]
    getter updated_by_actor_id : String?

    @[JSON::Field(key: "workspace_id", emit_null: false)]
    getter workspace_id : String?

    @[JSON::Field(key: "workspace_ids")]
    getter workspace_ids : Array(String)
  end

  alias FederationRule = BetaFederationRule

  # Paginated list of federation rules.
  struct BetaFederationRuleListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaFederationRule)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias FederationRuleListResponse = BetaFederationRuleListResponse

  # A workspace attached to a federation rule.
  struct BetaFederationRuleWorkspace
    include JSON::Serializable

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "created_by_actor_id")]
    getter created_by_actor_id : String?

    @[JSON::Field(key: "federation_rule_id")]
    getter federation_rule_id : String

    # Object type. Always `"federation_rule_workspace"`.
    getter type : String = "federation_rule_workspace"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    @[JSON::Field(key: "workspace_name")]
    getter workspace_name : String?
  end

  alias FederationRuleWorkspace = BetaFederationRuleWorkspace

  # Paginated list of workspaces a federation rule is enabled for.
  struct BetaFederationRuleWorkspaceListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaFederationRuleWorkspace)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias FederationRuleWorkspaceListResponse = BetaFederationRuleWorkspaceListResponse

  # Confirmation returned when a federation rule is disabled for a workspace.
  struct BetaDeletedFederationRuleWorkspace
    include JSON::Serializable

    @[JSON::Field(key: "federation_rule_id")]
    getter federation_rule_id : String

    getter type : String = "federation_rule_workspace_deleted"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  alias DeletedFederationRuleWorkspace = BetaDeletedFederationRuleWorkspace
end
