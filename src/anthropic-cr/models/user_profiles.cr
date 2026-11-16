module Anthropic
  # Access-type values for `UserProfile#access_type` and `BetaUserProfile#access_type`.
  module UserProfileAccessType
    APPLICATION = "application"
    PASSTHROUGH = "passthrough"
  end

  # Enforcement-status values for `UserProfile#enforcement_status`.
  module UserProfileEnforcementStatus
    UNRESTRICTED = "unrestricted"
    PENDING      = "pending"
    RESTRICTED   = "restricted"
    BANNED       = "banned"
  end

  # Next-step action values on `UserProfileEnforcementAction`.
  module UserProfileEnforcementActionNextStep
    VERIFY = "verify"
  end

  # Reason values on `UserProfileEnforcementAction`.
  module UserProfileEnforcementActionReason
    UNSUPPORTED_REGION     = "unsupported_region"
    FRAUD_OR_ABUSE         = "fraud_or_abuse"
    HIGH_HARM              = "high_harm"
    USAGE_POLICY_VIOLATION = "usage_policy_violation"
    ACCOUNT_COMPROMISE     = "account_compromise"
    UNSPECIFIED            = "unspecified"
  end

  # Program enrollment status values on `UserProfileCyberProgram` and `UserProfileEfsProgram`.
  module UserProfileProgramStatus
    ACTIVE   = "active"
    PENDING  = "pending"
    REJECTED = "rejected"
  end

  # Sort direction values for `UserProfiles#list` and `BetaUserProfiles#list`.
  module UserProfileListOrder
    ASC  = "asc"
    DESC = "desc"
  end

  # Sort field values for `UserProfiles#list` and `BetaUserProfiles#list`.
  module UserProfileListOrderBy
    CREATED_AT = "created_at"
    NAME       = "name"
  end

  # Account status values for `UserProfileExternalUserDetails#account_status`.
  module UserProfileExternalUserAccountStatus
    ACTIVE    = "active"
    SUSPENDED = "suspended"
    BLOCKED   = "blocked"
  end

  # Entity type values for `UserProfileExternalUserDetails#entity_type`.
  module UserProfileExternalUserEntityType
    INDIVIDUAL = "individual"
    BUSINESS   = "business"
    NON_PROFIT = "non_profit"
    GOVERNMENT = "government"
  end

  # Details about the entity a GA `UserProfile` represents, as the platform
  # states them. Anthropic does not verify them.
  struct UserProfileExternalUserDetails
    include JSON::Serializable

    @[JSON::Field(key: "account_status", emit_null: false)]
    getter account_status : String? = nil

    @[JSON::Field(key: "entity_type", emit_null: false)]
    getter entity_type : String? = nil

    @[JSON::Field(emit_null: false)]
    getter country : String? = nil

    @[JSON::Field(key: "email_hash", emit_null: false)]
    getter email_hash : String? = nil

    @[JSON::Field(key: "name_hash", emit_null: false)]
    getter name_hash : String? = nil

    @[JSON::Field(key: "onboarded_at", emit_null: false)]
    getter onboarded_at : String? = nil

    @[JSON::Field(key: "reference_id", emit_null: false)]
    getter reference_id : String? = nil

    def initialize(
      @account_status : String? = nil,
      @entity_type : String? = nil,
      @country : String? = nil,
      @email_hash : String? = nil,
      @name_hash : String? = nil,
      @onboarded_at : String? = nil,
      @reference_id : String? = nil,
    )
    end
  end

  # Active or historical restriction enforcement action on a `UserProfile`.
  struct UserProfileEnforcementActionRestriction
    include JSON::Serializable

    getter id : String

    @[JSON::Field(emit_null: false)]
    getter action : String? = nil

    @[JSON::Field(key: "expires_at", emit_null: false)]
    getter expires_at : String? = nil

    @[JSON::Field(key: "opened_at")]
    getter opened_at : String

    getter reason : String
    getter type : String = "restriction"
  end

  # Active or historical ban enforcement action on a `UserProfile`.
  struct UserProfileEnforcementActionBan
    include JSON::Serializable

    getter id : String

    @[JSON::Field(emit_null: false)]
    getter action : String? = nil

    @[JSON::Field(key: "expires_at", emit_null: false)]
    getter expires_at : String? = nil

    @[JSON::Field(key: "opened_at")]
    getter opened_at : String

    getter reason : String
    getter type : String = "ban"
  end

  # Forward-compatible fallback for unrecognized enforcement action types.
  struct GenericUserProfileEnforcementAction
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  # Discriminated union of enforcement actions on a `UserProfile`.
  alias UserProfileEnforcementAction = UserProfileEnforcementActionRestriction | UserProfileEnforcementActionBan | GenericUserProfileEnforcementAction

  # Discriminated-union converter for `UserProfileEnforcementAction`.
  module UserProfileEnforcementActionConverter
    def self.from_json(pull : JSON::PullParser) : UserProfileEnforcementAction
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "restriction"
        UserProfileEnforcementActionRestriction.from_json(raw)
      when "ban"
        UserProfileEnforcementActionBan.from_json(raw)
      else
        GenericUserProfileEnforcementAction.new(type: type, raw: json)
      end
    end

    def self.to_json(value : UserProfileEnforcementAction, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # Array converter for `Array(UserProfileEnforcementAction)`.
  module UserProfileEnforcementActionArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(UserProfileEnforcementAction)
      result = [] of UserProfileEnforcementAction
      pull.read_array do
        result << UserProfileEnforcementActionConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(UserProfileEnforcementAction), builder : JSON::Builder) : Nil
      builder.array do
        value.each &.to_json(builder)
      end
    end
  end

  # Nullable array converter for optional `enforcement_actions` on `BetaUserProfile`.
  module OptionalUserProfileEnforcementActionArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(UserProfileEnforcementAction)?
      if pull.kind.null?
        pull.read_null
        return nil
      end
      UserProfileEnforcementActionArrayConverter.from_json(pull)
    end

    def self.to_json(value : Array(UserProfileEnforcementAction)?, builder : JSON::Builder) : Nil
      if value.nil?
        builder.null
      else
        UserProfileEnforcementActionArrayConverter.to_json(value, builder)
      end
    end
  end

  # Cyber program requirements on `UserProfileCyberProgram`.
  struct UserProfileCyberRequirements
    include JSON::Serializable

    @[JSON::Field(key: "data_retention")]
    getter? data_retention : Bool

    @[JSON::Field(key: "human_review")]
    getter? human_review : Bool

    def initialize(@data_retention : Bool, @human_review : Bool)
    end
  end

  # Tier status entry within `UserProfileCyberProgram#tiers`.
  struct UserProfileCyberTier
    include JSON::Serializable

    getter status : String

    def initialize(@status : String)
    end
  end

  # Cyber program enrollment status and tier map for a `UserProfile`.
  struct UserProfileCyberProgram
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter requirements : UserProfileCyberRequirements? = nil

    getter status : String
    getter tiers : Hash(String, UserProfileCyberTier) = {} of String => UserProfileCyberTier
  end

  # Feature status entry within `UserProfileEfsProgram#features`.
  struct UserProfileEfsFeature
    include JSON::Serializable

    getter status : String

    def initialize(@status : String)
    end
  end

  # Enterprise feature set (EFS) program enrollment status and features for a `UserProfile`.
  struct UserProfileEfsProgram
    include JSON::Serializable

    getter features : Hash(String, UserProfileEfsFeature) = {} of String => UserProfileEfsFeature
    getter status : String
  end

  # Program enrollments attached to a `UserProfile`.
  struct UserProfilePrograms
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter cyber : UserProfileCyberProgram? = nil

    @[JSON::Field(emit_null: false)]
    getter efs : UserProfileEfsProgram? = nil

    def initialize(
      @cyber : UserProfileCyberProgram? = nil,
      @efs : UserProfileEfsProgram? = nil,
    )
    end
  end

  # GA User Profile resource (`client.user_profiles`).
  struct UserProfile
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "access_type")]
    getter access_type : String = UserProfileAccessType::APPLICATION

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    getter type : String = "user_profile"
    getter metadata : Hash(String, String) = {} of String => String

    @[JSON::Field(emit_null: false)]
    getter name : String? = nil

    @[JSON::Field(key: "external_user_details")]
    getter external_user_details : UserProfileExternalUserDetails = UserProfileExternalUserDetails.new

    @[JSON::Field(key: "enforcement_status")]
    getter enforcement_status : String = UserProfileEnforcementStatus::UNRESTRICTED

    @[JSON::Field(key: "enforcement_actions", converter: Anthropic::UserProfileEnforcementActionArrayConverter)]
    getter enforcement_actions : Array(UserProfileEnforcementAction) = [] of UserProfileEnforcementAction

    getter programs : UserProfilePrograms = UserProfilePrograms.new
  end

  # Deletion confirmation returned by `UserProfiles#delete`.
  struct DeletedUserProfile
    include JSON::Serializable

    getter id : String
    getter type : String = "user_profile_deleted"
  end

  # Action payload requesting an end-user enrollment URL (`{"type": "enroll_end_user"}`).
  struct UserProfileEnrollEndUserAction
    include JSON::Serializable

    getter type : String = "enroll_end_user"

    def initialize(@type : String = "enroll_end_user")
    end
  end

  # Action URL returned by `UserProfiles#action_urls.create`.
  struct UserProfileActionURL
    include JSON::Serializable

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    getter type : String = "user_profile_action_url"
    getter url : String
  end

  # Paginated list of GA user profiles.
  struct UserProfileListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(UserProfile)

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String? = nil
  end

  # --- Beta User Profiles models ---

  # Trust grant attached to a `BetaUserProfile`.
  #
  # `status` is one of `"active"`, `"pending"`, or `"rejected"`.
  struct BetaUserProfileTrustGrant
    include JSON::Serializable

    getter status : String

    def initialize(@status : String)
    end
  end

  # Details about the entity a profile represents, as the platform states
  # them. Anthropic does not verify them. Every field is optional on
  # requests; responses carry every field, `nil` until the platform
  # supplies a value.
  struct BetaUserProfileExternalUserDetails
    include JSON::Serializable

    # Account status: `"active"`, `"suspended"`, or `"blocked"`.
    @[JSON::Field(key: "account_status", emit_null: false)]
    getter account_status : String? = nil

    # Entity type: `"individual"`, `"business"`, `"non_profit"`, or `"government"`.
    @[JSON::Field(key: "entity_type", emit_null: false)]
    getter entity_type : String? = nil

    # ISO 3166-1 alpha-2 country code, when supplied.
    @[JSON::Field(emit_null: false)]
    getter country : String? = nil

    # Hash of the end user's email, when supplied.
    @[JSON::Field(key: "email_hash", emit_null: false)]
    getter email_hash : String? = nil

    # Hash of the end user's name, when supplied.
    @[JSON::Field(key: "name_hash", emit_null: false)]
    getter name_hash : String? = nil

    # RFC 3339 timestamp recording when the end user onboarded.
    @[JSON::Field(key: "onboarded_at", emit_null: false)]
    getter onboarded_at : String? = nil

    # Caller-supplied reference identifier for the end user.
    @[JSON::Field(key: "reference_id", emit_null: false)]
    getter reference_id : String? = nil

    def initialize(
      @account_status : String? = nil,
      @entity_type : String? = nil,
      @country : String? = nil,
      @email_hash : String? = nil,
      @name_hash : String? = nil,
      @onboarded_at : String? = nil,
      @reference_id : String? = nil,
    )
    end
  end

  # A user profile scopes per-user state (memory, trust grants, etc.) to a
  # specific end user of your application. Accessible via
  # `client.beta.user_profiles`.
  #
  # Requires the beta header `user-profiles-2026-08-18`. When the resource
  # methods are called, the header is applied automatically.
  struct BetaUserProfile
    include JSON::Serializable

    # Unique identifier prefixed `uprof_`.
    getter id : String

    # Object type. Always `"user_profile"`.
    getter type : String = "user_profile"

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Free-form metadata attached to the profile.
    getter metadata : Hash(String, String) = {} of String => String

    # Trust grants keyed by grant name. Keys omitted when no grant is active.
    @[JSON::Field(key: "trust_grants")]
    getter trust_grants : Hash(String, BetaUserProfileTrustGrant) = {} of String => BetaUserProfileTrustGrant

    # Optional platform-assigned external identifier (not enforced unique).
    @[JSON::Field(key: "external_id", emit_null: false)]
    getter external_id : String? = nil

    # How the platform uses the API on behalf of the entity this profile
    # represents: `"application"` or `"passthrough"`.
    @[JSON::Field(key: "access_type", emit_null: false)]
    getter access_type : String? = nil

    # Real-world name of the entity this profile represents.
    @[JSON::Field(emit_null: false)]
    getter name : String? = nil

    # RFC 3339 timestamp recording when the end user completed onboarding.
    @[JSON::Field(key: "external_user_onboarded_at", emit_null: false)]
    getter external_user_onboarded_at : String? = nil

    # Details about the end user, as the platform states them, when supplied.
    @[JSON::Field(key: "external_user_details", emit_null: false)]
    getter external_user_details : BetaUserProfileExternalUserDetails? = nil

    @[JSON::Field(key: "enforcement_status", emit_null: false)]
    getter enforcement_status : String? = nil

    @[JSON::Field(key: "enforcement_actions", converter: Anthropic::OptionalUserProfileEnforcementActionArrayConverter, emit_null: false)]
    getter enforcement_actions : Array(UserProfileEnforcementAction)? = nil

    @[JSON::Field(emit_null: false)]
    getter programs : UserProfilePrograms? = nil
  end

  # Deletion confirmation returned by `BetaUserProfiles#delete`.
  struct BetaDeletedUserProfile
    include JSON::Serializable

    getter id : String
    getter type : String = "user_profile_deleted"
  end

  # Enrollment URL response for a user profile.
  struct BetaUserProfileEnrollmentURL
    include JSON::Serializable

    getter type : String

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    getter url : String
  end

  # Action payload requesting an end-user enrollment URL (beta).
  struct BetaUserProfileEnrollEndUserAction
    include JSON::Serializable

    getter type : String = "enroll_end_user"

    def initialize(@type : String = "enroll_end_user")
    end
  end

  # Action URL returned by `BetaUserProfiles#action_urls.create`.
  struct BetaUserProfileActionURL
    include JSON::Serializable

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    getter type : String = "user_profile_action_url"
    getter url : String
  end

  # Paginated list of beta user profiles.
  struct BetaUserProfileListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaUserProfile)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String? = nil
  end
end
