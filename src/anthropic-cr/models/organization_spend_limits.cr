module Anthropic
  # Spend limit reset period.
  module SpendLimitPeriod
    DAILY   = "daily"
    MONTHLY = "monthly"
    WEEKLY  = "weekly"
  end

  alias BetaSpendLimitPeriod = SpendLimitPeriod

  # Spend limit scope types accepted when filtering `spend_limits.list`.
  module SpendLimitScopeType
    ORGANIZATION         = "organization"
    ORGANIZATION_SERVICE = "organization_service"
    RBAC_GROUP           = "rbac_group"
    SEAT_TIER            = "seat_tier"
    USAGE_TIER           = "usage_tier"
    USER                 = "user"
    WORKSPACE            = "workspace"
  end

  # Spend limit scoped to a user.
  struct SpendLimitUserScope
    include JSON::Serializable

    getter type : String = "user"

    @[JSON::Field(key: "user_id")]
    getter user_id : String

    def initialize(@user_id : String, @type : String = "user")
    end
  end

  alias BetaSpendLimitUserScope = SpendLimitUserScope

  # Spend limit scoped to a seat tier.
  struct SpendLimitSeatTierScope
    include JSON::Serializable

    @[JSON::Field(key: "seat_tier")]
    getter seat_tier : String

    getter type : String = "seat_tier"
  end

  alias BetaSpendLimitSeatTierScope = SpendLimitSeatTierScope

  # Spend limit scoped to an RBAC group.
  struct SpendLimitRbacGroupScope
    include JSON::Serializable

    @[JSON::Field(key: "rbac_group_id")]
    getter rbac_group_id : String

    getter type : String = "rbac_group"
  end

  alias SpendLimitRBACGroupScope = SpendLimitRbacGroupScope
  alias BetaSpendLimitRbacGroupScope = SpendLimitRbacGroupScope
  alias BetaSpendLimitRBACGroupScope = SpendLimitRbacGroupScope

  # Spend limit scoped to an organization service.
  struct SpendLimitOrganizationServiceScope
    include JSON::Serializable

    getter service : String
    getter type : String = "organization_service"
  end

  alias BetaSpendLimitOrganizationServiceScope = SpendLimitOrganizationServiceScope

  # Spend limit scoped to the organization.
  struct SpendLimitOrganizationScope
    include JSON::Serializable

    getter type : String = "organization"

    def initialize(@type : String = "organization")
    end
  end

  alias BetaSpendLimitOrganizationScope = SpendLimitOrganizationScope

  # Spend limit scoped to a workspace.
  struct SpendLimitWorkspaceScope
    include JSON::Serializable

    getter type : String = "workspace"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    def initialize(@workspace_id : String, @type : String = "workspace")
    end
  end

  alias BetaSpendLimitWorkspaceScope = SpendLimitWorkspaceScope

  # Spend limit scoped to a usage tier.
  struct SpendLimitUsageTierScope
    include JSON::Serializable

    getter type : String = "usage_tier"
  end

  alias BetaSpendLimitUsageTierScope = SpendLimitUsageTierScope

  # Forward-compatible fallback for unrecognized spend-limit scope variants.
  struct SpendLimitGenericScope
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias SpendLimitScope = SpendLimitUserScope |
                          SpendLimitSeatTierScope |
                          SpendLimitRbacGroupScope |
                          SpendLimitOrganizationServiceScope |
                          SpendLimitOrganizationScope |
                          SpendLimitWorkspaceScope |
                          SpendLimitUsageTierScope |
                          SpendLimitGenericScope

  alias SpendLimitSetScope = SpendLimitUserScope |
                             SpendLimitOrganizationScope |
                             SpendLimitWorkspaceScope

  module SpendLimitScopeConverter
    def self.from_json(pull : JSON::PullParser) : SpendLimitScope
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "user"
        SpendLimitUserScope.from_json(raw)
      when "seat_tier"
        SpendLimitSeatTierScope.from_json(raw)
      when "rbac_group"
        SpendLimitRbacGroupScope.from_json(raw)
      when "organization_service"
        SpendLimitOrganizationServiceScope.from_json(raw)
      when "organization"
        SpendLimitOrganizationScope.from_json(raw)
      when "workspace"
        SpendLimitWorkspaceScope.from_json(raw)
      when "usage_tier"
        SpendLimitUsageTierScope.from_json(raw)
      else
        SpendLimitGenericScope.new(type: type, raw: json)
      end
    end

    def self.to_json(value : SpendLimitScope, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # User actor associated with a spend summary or increase request.
  struct SpendLimitUserActor
    include JSON::Serializable

    getter? deleted : Bool

    @[JSON::Field(key: "email_address", emit_null: false)]
    getter email_address : String?

    @[JSON::Field(emit_null: false)]
    getter name : String?

    getter type : String = "user_actor"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  alias BetaSpendLimitUserActor = SpendLimitUserActor

  # Scoped API key actor associated with a spend summary or increase request.
  struct SpendLimitScopedAPIKeyActor
    include JSON::Serializable

    @[JSON::Field(key: "scoped_api_key_id")]
    getter scoped_api_key_id : String

    getter type : String = "scoped_api_key_actor"
  end

  alias BetaSpendLimitScopedAPIKeyActor = SpendLimitScopedAPIKeyActor

  # Forward-compatible fallback for unrecognized spend-limit actor variants.
  struct SpendLimitGenericActor
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias SpendLimitActor = SpendLimitUserActor | SpendLimitScopedAPIKeyActor | SpendLimitGenericActor

  module SpendLimitActorConverter
    def self.from_json(pull : JSON::PullParser) : SpendLimitActor
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "user_actor"
        SpendLimitUserActor.from_json(raw)
      when "scoped_api_key_actor"
        SpendLimitScopedAPIKeyActor.from_json(raw)
      else
        SpendLimitGenericActor.new(type: type, raw: json)
      end
    end

    def self.to_json(value : SpendLimitActor, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  module NullableSpendLimitActorConverter
    def self.from_json(pull : JSON::PullParser) : SpendLimitActor?
      if pull.kind.null?
        pull.read_null
        return nil
      end
      SpendLimitActorConverter.from_json(pull)
    end

    def self.to_json(value : SpendLimitActor?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  # A configured spend limit in the organization.
  struct SpendLimit
    include JSON::Serializable

    getter id : String

    @[JSON::Field(emit_null: false)]
    getter amount : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter currency : String

    @[JSON::Field(key: "is_enabled")]
    getter? is_enabled : Bool

    getter period : String

    @[JSON::Field(converter: Anthropic::SpendLimitScopeConverter)]
    getter scope : SpendLimitScope

    # Object type. Always `"spend_limit"`.
    getter type : String = "spend_limit"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  alias BetaSpendLimit = SpendLimit

  # Paginated list of spend limits.
  struct SpendLimitListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(SpendLimit)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias BetaSpendLimitListResponse = SpendLimitListResponse

  # Confirmation returned when a spend limit is deleted.
  struct SpendLimitDeleteResponse
    include JSON::Serializable

    getter id : String

    # Object type. Always `"spend_limit_deleted"`.
    getter type : String = "spend_limit_deleted"
  end

  alias BetaSpendLimitDeleteResponse = SpendLimitDeleteResponse

  # Effective spend limit and current period-to-date spend for an actor.
  struct SpendSummary
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::SpendLimitActorConverter)]
    getter actor : SpendLimitActor

    @[JSON::Field(emit_null: false)]
    getter amount : String?

    getter currency : String

    getter period : String

    @[JSON::Field(key: "period_to_date_spend")]
    getter period_to_date_spend : String

    @[JSON::Field(converter: Anthropic::SpendLimitScopeConverter)]
    getter scope : SpendLimitScope

    @[JSON::Field(converter: Anthropic::SpendLimitScopeConverter)]
    getter source : SpendLimitScope

    @[JSON::Field(key: "spend_limit_id")]
    getter spend_limit_id : String
  end

  alias BetaSpendSummary = SpendSummary

  # Paginated list of effective spend summaries.
  struct SpendSummaryListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(SpendSummary)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias BetaSpendSummaryListResponse = SpendSummaryListResponse

  # Review status of a spend limit increase request.
  module SpendLimitIncreaseRequestStatus
    APPROVED = "approved"
    DENIED   = "denied"
    PENDING  = "pending"
  end

  # A spend limit increase request submitted by a member or API key.
  struct SpendLimitIncreaseRequest
    include JSON::Serializable

    getter id : String

    @[JSON::Field(converter: Anthropic::SpendLimitActorConverter)]
    getter actor : SpendLimitActor

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter period : String

    @[JSON::Field(key: "resolved_at", emit_null: false)]
    getter resolved_at : String?

    @[JSON::Field(key: "resolved_by", converter: Anthropic::NullableSpendLimitActorConverter, emit_null: false)]
    getter resolved_by : SpendLimitActor? = nil

    @[JSON::Field(key: "spend_summary", emit_null: false)]
    getter spend_summary : SpendSummary?

    getter status : String

    # Object type. Always `"spend_limit_increase_request"`.
    getter type : String = "spend_limit_increase_request"
  end

  alias BetaSpendLimitIncreaseRequest = SpendLimitIncreaseRequest

  # Paginated list of spend limit increase requests.
  struct SpendLimitIncreaseRequestListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(SpendLimitIncreaseRequest)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias BetaSpendLimitIncreaseRequestListResponse = SpendLimitIncreaseRequestListResponse

  # Response returned when approving a spend limit increase request.
  struct SpendLimitIncreaseRequestApproveResponse
    include JSON::Serializable

    getter id : String

    @[JSON::Field(converter: Anthropic::SpendLimitActorConverter)]
    getter actor : SpendLimitActor

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter period : String

    @[JSON::Field(key: "resolved_at", emit_null: false)]
    getter resolved_at : String?

    @[JSON::Field(key: "resolved_by", converter: Anthropic::NullableSpendLimitActorConverter, emit_null: false)]
    getter resolved_by : SpendLimitActor? = nil

    @[JSON::Field(key: "spend_limit", emit_null: false)]
    getter spend_limit : SpendLimit?

    @[JSON::Field(key: "spend_summary", emit_null: false)]
    getter spend_summary : SpendSummary?

    getter status : String

    # Object type. Always `"spend_limit_increase_request"`.
    getter type : String = "spend_limit_increase_request"
  end

  alias IncreaseRequestApproveResponse = SpendLimitIncreaseRequestApproveResponse
  alias BetaSpendLimitIncreaseRequestApproveResponse = SpendLimitIncreaseRequestApproveResponse
end
