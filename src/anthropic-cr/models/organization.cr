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

  # Organization-level roles for users and invites.
  #
  # One of `"admin"`, `"billing"`, `"claude_code_user"`, `"developer"`,
  # `"managed"`, `"membership_admin"`, `"support"`, `"user"`.
  module OrganizationRole
    ADMIN            = "admin"
    BILLING          = "billing"
    CLAUDE_CODE_USER = "claude_code_user"
    DEVELOPER        = "developer"
    MANAGED          = "managed"
    MEMBERSHIP_ADMIN = "membership_admin"
    SUPPORT          = "support"
    USER             = "user"
  end

  # Workspace roles assignable to members and service accounts.
  #
  # One of `"admin"`, `"developer"`, `"user"`, `"billing"`,
  # `"support"`, `"no_billing"`.
  module WorkspaceRole
    ADMIN      = "admin"
    DEVELOPER  = "developer"
    USER       = "user"
    BILLING    = "billing"
    SUPPORT    = "support"
    NO_BILLING = "no_billing"
  end

  # An API key in the organization.
  struct BetaAPIKey
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Actor that created the key (user or service-account shape).
    @[JSON::Field(key: "created_by")]
    getter created_by : JSON::Any

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    getter name : String

    @[JSON::Field(key: "partial_key_hint")]
    getter partial_key_hint : String

    # Key principal (organization or workspace scope shape).
    getter principal : JSON::Any

    # Key scope shape.
    getter scope : JSON::Any

    # Key status: `"active"`, `"archived"`, or `"inactive"`.
    getter status : String

    # Object type. Always `"api_key"`.
    getter type : String = "api_key"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

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

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Key geography (e.g. `"us"`).
    getter geo : String

    @[JSON::Field(key: "provider_config")]
    getter provider_config : JSON::Any

    # Object type. Always `"external_key"`.
    getter type : String = "external_key"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  # Paginated list of external keys.
  struct BetaExternalKeyListResponse
    include JSON::Serializable

    getter data : Array(BetaExternalKey)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Confirmation returned when an external key is deleted.
  struct BetaDeletedExternalKey
    include JSON::Serializable

    getter id : String

    # Object type. Always `"external_key_deleted"`.
    getter type : String = "external_key_deleted"
  end

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
    getter rbac_group_ids : Array(String)

    getter role : String

    # Invite status: `"pending"`, `"accepted"`, `"expired"`, or `"deleted"`.
    getter status : String

    # Object type. Always `"invite"`.
    getter type : String = "invite"
  end

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

  # Confirmation returned when an invite is deleted.
  struct BetaDeletedInvite
    include JSON::Serializable

    getter id : String

    # Object type. Always `"invite_deleted"`.
    getter type : String = "invite_deleted"
  end

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

  # Confirmation returned when a user is removed.
  struct BetaDeletedOrganizationUser
    include JSON::Serializable

    getter id : String

    # Object type. Always `"user_deleted"`.
    getter type : String = "user_deleted"
  end

  # A single rate-limit value entry.
  struct BetaOrganizationRateLimitValue
    include JSON::Serializable

    getter type : String
    getter value : Int64
  end

  # A rate-limit group applying to a model.
  struct BetaOrganizationRateLimitModelGroup
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Group type. Always `"model_group"`.
    getter type : String = "model_group"
  end

  # A rate-limit group applying to batches.
  struct BetaOrganizationRateLimitBatchGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"batch"`.
    getter type : String = "batch"
  end

  # A rate-limit group applying to files.
  struct BetaOrganizationRateLimitFilesGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"files"`.
    getter type : String = "files"
  end

  # A rate-limit group applying to skills.
  struct BetaOrganizationRateLimitSkillsGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"skills"`.
    getter type : String = "skills"
  end

  # A rate-limit group applying to token counting.
  struct BetaOrganizationRateLimitTokenCountGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"token_count"`.
    getter type : String = "token_count"
  end

  # A rate-limit group applying to web search.
  struct BetaOrganizationRateLimitWebSearchGroup
    include JSON::Serializable

    getter id : String

    # Group type. Always `"web_search"`.
    getter type : String = "web_search"
  end

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

  # Discriminated union of rate-limit group variants.
  alias BetaOrganizationRateLimitGroup = BetaOrganizationRateLimitModelGroup | BetaOrganizationRateLimitBatchGroup | BetaOrganizationRateLimitFilesGroup | BetaOrganizationRateLimitSkillsGroup | BetaOrganizationRateLimitTokenCountGroup | BetaOrganizationRateLimitWebSearchGroup | BetaOrganizationRateLimitGenericGroup

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

    # Deprecated in favor of `group`; still returned by the API.
    @[JSON::Field(key: "group_type")]
    getter group_type : String

    getter limits : JSON::Any

    # Models covered by this limit (`nil` for non-model groups).
    @[JSON::Field(emit_null: false)]
    getter models : Array(String)?

    # Object type. Always `"rate_limit"`.
    getter type : String = "rate_limit"
  end

  # Paginated list of organization rate limits.
  struct BetaOrganizationRateLimitListResponse
    include JSON::Serializable

    getter data : Array(BetaOrganizationRateLimit)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

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

  # Allowed inference geographies for beta data-residency configuration.
  module BetaAllowedInferenceGeo
    GLOBAL = "global"
    US     = "us"
  end

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
  end

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

    @[JSON::Field(key: "created_by_actor_id")]
    getter created_by_actor_id : String

    getter description : String

    getter name : String

    @[JSON::Field(key: "organization_role")]
    getter organization_role : JSON::Any

    # Object type. Always `"service_account"`.
    getter type : String = "service_account"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "updated_by_actor_id")]
    getter updated_by_actor_id : String
  end

  # Paginated list of service accounts.
  struct BetaServiceAccountListResponse
    include JSON::Serializable

    getter data : Array(BetaServiceAccount)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # A service account's membership in a workspace.
  struct BetaServiceAccountWorkspaceMember
    include JSON::Serializable

    @[JSON::Field(key: "created_by_actor_id")]
    getter created_by_actor_id : String

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

  # Paginated list of service-account workspace memberships.
  struct BetaServiceAccountWorkspaceMemberListResponse
    include JSON::Serializable

    getter data : Array(BetaServiceAccountWorkspaceMember)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

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

    @[JSON::Field(key: "created_by_actor_id")]
    getter created_by_actor_id : String

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

    @[JSON::Field(key: "updated_by_actor_id")]
    getter updated_by_actor_id : String
  end

  # Paginated list of federation issuers.
  struct BetaFederationIssuerListResponse
    include JSON::Serializable

    getter data : Array(BetaFederationIssuer)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

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

  # Paginated list of federation rules.
  struct BetaFederationRuleListResponse
    include JSON::Serializable

    getter data : Array(BetaFederationRule)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

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

  # Paginated list of workspaces a federation rule is enabled for.
  struct BetaFederationRuleWorkspaceListResponse
    include JSON::Serializable

    getter data : Array(BetaFederationRuleWorkspace)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Confirmation returned when a federation rule is disabled for a workspace.
  struct BetaDeletedFederationRuleWorkspace
    include JSON::Serializable

    @[JSON::Field(key: "federation_rule_id")]
    getter federation_rule_id : String

    getter type : String = "federation_rule_workspace_deleted"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end
end
