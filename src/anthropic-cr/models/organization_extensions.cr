module Anthropic
  # Sentinel distinguishing omitted optional fields from explicit `null` in update requests.
  struct OrganizationUnset
  end

  ORGANIZATION_UNSET = OrganizationUnset.new

  # ---- Telemetry Destinations Models (Beta) ----

  module BetaTelemetryDestinationContentMode
    METADATA_ONLY = "metadata_only"
    CONTENT       = "content"
  end

  struct BetaTelemetryDestinationDeliveryHealth
    include JSON::Serializable

    @[JSON::Field(key: "last_error", emit_null: false)]
    getter last_error : String?

    @[JSON::Field(key: "last_error_at", emit_null: false)]
    getter last_error_at : String?

    @[JSON::Field(key: "last_success_at", emit_null: false)]
    getter last_success_at : String?
  end

  struct BetaTelemetryDestinationDisabledReasonCaller
    include JSON::Serializable

    getter type : String = "caller"
  end

  struct BetaTelemetryDestinationDisabledReasonSustainedFailure
    include JSON::Serializable

    getter type : String = "sustained_failure"
  end

  struct BetaTelemetryDestinationDisabledReasonInvalidAddress
    include JSON::Serializable

    getter type : String = "invalid_address"
  end

  struct BetaTelemetryDestinationDisabledReasonRedirect
    include JSON::Serializable

    getter type : String = "redirect"
  end

  struct BetaTelemetryDestinationDisabledReasonGeneric
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaTelemetryDestinationDisabledReason = BetaTelemetryDestinationDisabledReasonCaller |
                                                 BetaTelemetryDestinationDisabledReasonSustainedFailure |
                                                 BetaTelemetryDestinationDisabledReasonInvalidAddress |
                                                 BetaTelemetryDestinationDisabledReasonRedirect |
                                                 BetaTelemetryDestinationDisabledReasonGeneric

  module BetaTelemetryDestinationDisabledReasonConverter
    def self.from_json(pull : JSON::PullParser) : BetaTelemetryDestinationDisabledReason
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "caller"
        BetaTelemetryDestinationDisabledReasonCaller.from_json(raw)
      when "sustained_failure"
        BetaTelemetryDestinationDisabledReasonSustainedFailure.from_json(raw)
      when "invalid_address"
        BetaTelemetryDestinationDisabledReasonInvalidAddress.from_json(raw)
      when "redirect"
        BetaTelemetryDestinationDisabledReasonRedirect.from_json(raw)
      else
        BetaTelemetryDestinationDisabledReasonGeneric.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaTelemetryDestinationDisabledReason, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaTelemetryDestinationStateEnabled
    include JSON::Serializable

    getter type : String = "enabled"

    def initialize(@type : String = "enabled")
    end
  end

  alias BetaTelemetryDestinationStateEnabledParams = BetaTelemetryDestinationStateEnabled

  struct BetaTelemetryDestinationStateDisabled
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaTelemetryDestinationDisabledReasonConverter)]
    getter reason : BetaTelemetryDestinationDisabledReason

    getter type : String = "disabled"
  end

  struct BetaTelemetryDestinationStateDisabledParams
    include JSON::Serializable

    getter type : String = "disabled"

    def initialize(@type : String = "disabled")
    end
  end

  struct BetaTelemetryDestinationStateGeneric
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaTelemetryDestinationState = BetaTelemetryDestinationStateEnabled |
                                        BetaTelemetryDestinationStateDisabled |
                                        BetaTelemetryDestinationStateGeneric

  alias BetaTelemetryDestinationStateParam = BetaTelemetryDestinationStateEnabledParams |
                                             BetaTelemetryDestinationStateDisabledParams

  module BetaTelemetryDestinationStateConverter
    def self.from_json(pull : JSON::PullParser) : BetaTelemetryDestinationState
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "enabled"
        BetaTelemetryDestinationStateEnabled.from_json(raw)
      when "disabled"
        BetaTelemetryDestinationStateDisabled.from_json(raw)
      else
        BetaTelemetryDestinationStateGeneric.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaTelemetryDestinationState, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaTelemetryDestinationTraces
    include JSON::Serializable

    @[JSON::Field(key: "content_mode")]
    getter content_mode : String

    getter? enabled : Bool

    @[JSON::Field(key: "endpoint_url", emit_null: false)]
    getter endpoint_url : String?

    @[JSON::Field(key: "max_content_bytes", emit_null: false)]
    getter max_content_bytes : Int64?
  end

  # Trace configuration parameters for telemetry destination create/update.
  struct BetaTelemetryDestinationTracesParams
    getter content_mode : String | OrganizationUnset | Nil
    getter enabled : Bool?
    getter endpoint_url : String | OrganizationUnset | Nil
    getter max_content_bytes : Int64 | OrganizationUnset | Nil

    def initialize(
      @content_mode : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @enabled : Bool? = nil,
      @endpoint_url : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @max_content_bytes : Int64 | OrganizationUnset | Nil = ORGANIZATION_UNSET,
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        unless (cm = @content_mode).is_a?(OrganizationUnset)
          builder.field("content_mode", cm)
        end
        unless (enabled = @enabled).nil?
          builder.field("enabled", enabled)
        end
        unless (endpoint_url = @endpoint_url).is_a?(OrganizationUnset)
          builder.field("endpoint_url", endpoint_url)
        end
        unless (max_content_bytes = @max_content_bytes).is_a?(OrganizationUnset)
          builder.field("max_content_bytes", max_content_bytes)
        end
      end
    end
  end

  struct BetaTelemetryDestinationWorkspacesAll
    include JSON::Serializable

    getter type : String = "all"

    def initialize(@type : String = "all")
    end
  end

  alias BetaTelemetryDestinationWorkspacesAllParams = BetaTelemetryDestinationWorkspacesAll

  struct BetaTelemetryDestinationWorkspacesInclude
    include JSON::Serializable

    getter type : String = "include"

    @[JSON::Field(key: "workspace_ids", emit_null: false)]
    getter workspace_ids : Array(String)? = nil

    def initialize(@workspace_ids : Array(String)? = nil, @type : String = "include")
    end
  end

  alias BetaTelemetryDestinationWorkspacesIncludeParams = BetaTelemetryDestinationWorkspacesInclude

  struct BetaTelemetryDestinationWorkspacesExclude
    include JSON::Serializable

    getter type : String = "exclude"

    @[JSON::Field(key: "workspace_ids", emit_null: false)]
    getter workspace_ids : Array(String)? = nil

    def initialize(@workspace_ids : Array(String)? = nil, @type : String = "exclude")
    end
  end

  alias BetaTelemetryDestinationWorkspacesExcludeParams = BetaTelemetryDestinationWorkspacesExclude

  struct BetaTelemetryDestinationWorkspacesGeneric
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaTelemetryDestinationWorkspaces = BetaTelemetryDestinationWorkspacesAll |
                                             BetaTelemetryDestinationWorkspacesInclude |
                                             BetaTelemetryDestinationWorkspacesExclude |
                                             BetaTelemetryDestinationWorkspacesGeneric

  alias BetaTelemetryDestinationWorkspacesParam = BetaTelemetryDestinationWorkspacesAll |
                                                  BetaTelemetryDestinationWorkspacesInclude |
                                                  BetaTelemetryDestinationWorkspacesExclude

  module BetaTelemetryDestinationWorkspacesConverter
    def self.from_json(pull : JSON::PullParser) : BetaTelemetryDestinationWorkspaces
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "all"
        BetaTelemetryDestinationWorkspacesAll.from_json(raw)
      when "include"
        BetaTelemetryDestinationWorkspacesInclude.from_json(raw)
      when "exclude"
        BetaTelemetryDestinationWorkspacesExclude.from_json(raw)
      else
        BetaTelemetryDestinationWorkspacesGeneric.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaTelemetryDestinationWorkspaces, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaTelemetryDestination
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "delivery_health")]
    getter delivery_health : BetaTelemetryDestinationDeliveryHealth

    @[JSON::Field(key: "display_name", emit_null: false)]
    getter display_name : String?

    @[JSON::Field(key: "endpoint_url")]
    getter endpoint_url : String

    @[JSON::Field(key: "header_names")]
    getter header_names : Array(String)

    @[JSON::Field(converter: Anthropic::BetaTelemetryDestinationStateConverter)]
    getter state : BetaTelemetryDestinationState

    getter traces : BetaTelemetryDestinationTraces
    getter type : String = "telemetry_destination"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(converter: Anthropic::BetaTelemetryDestinationWorkspacesConverter)]
    getter workspaces : BetaTelemetryDestinationWorkspaces
  end

  struct BetaDeletedTelemetryDestination
    include JSON::Serializable

    getter id : String
    getter type : String = "telemetry_destination_deleted"
  end

  struct BetaTelemetryDestinationTestSuccess
    include JSON::Serializable

    getter type : String = "success"
  end

  struct BetaTelemetryDestinationTestFailure
    include JSON::Serializable

    getter error : String
    getter type : String = "failure"
  end

  struct BetaTelemetryDestinationTestGenericResult
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaTelemetryDestinationTestResult = BetaTelemetryDestinationTestSuccess |
                                             BetaTelemetryDestinationTestFailure |
                                             BetaTelemetryDestinationTestGenericResult

  module BetaTelemetryDestinationTestResultConverter
    def self.from_json(pull : JSON::PullParser) : BetaTelemetryDestinationTestResult
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "success"
        BetaTelemetryDestinationTestSuccess.from_json(raw)
      when "failure"
        BetaTelemetryDestinationTestFailure.from_json(raw)
      else
        BetaTelemetryDestinationTestGenericResult.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaTelemetryDestinationTestResult, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaTelemetryDestinationTestResponse
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaTelemetryDestinationTestResultConverter)]
    getter result : BetaTelemetryDestinationTestResult

    getter type : String = "telemetry_destination_test"
  end

  struct BetaTelemetryDestinationWorkspace
    include JSON::Serializable

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "telemetry_destination_id")]
    getter telemetry_destination_id : String

    getter type : String = "telemetry_destination_workspace"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  struct BetaDeletedTelemetryDestinationWorkspace
    include JSON::Serializable

    @[JSON::Field(key: "telemetry_destination_id")]
    getter telemetry_destination_id : String

    getter type : String = "telemetry_destination_workspace_deleted"

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String
  end

  # ---- Organization Webhook Endpoints Models (Beta) ----

  module BetaOrganizationWebhookEndpointEnabledEvent
    USER_PROFILE_ENFORCEMENT_ACTION_OPENED   = "user_profile.enforcement_action_opened"
    USER_PROFILE_ENFORCEMENT_ACTION_RESOLVED = "user_profile.enforcement_action_resolved"
    USER_PROFILE_PROGRAM_STATUS_UPDATED      = "user_profile.program_status_updated"
  end

  module BetaOrganizationWebhookEndpointState
    DISABLED = "disabled"
    ENABLED  = "enabled"
  end

  module BetaOrganizationWebhookEndpointOrder
    ASC  = "asc"
    DESC = "desc"
  end

  struct BetaOrganizationWebhookEndpoint
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter description : String

    @[JSON::Field(key: "disabled_reason")]
    getter disabled_reason : String

    @[JSON::Field(key: "enabled_events")]
    getter enabled_events : Array(String)

    getter name : String
    getter state : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    getter url : String
  end

  struct BetaNewOrganizationWebhookEndpoint
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter description : String

    @[JSON::Field(key: "disabled_reason")]
    getter disabled_reason : String

    @[JSON::Field(key: "enabled_events")]
    getter enabled_events : Array(String)

    getter name : String

    @[JSON::Field(key: "signing_secret")]
    getter signing_secret : String

    getter state : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    getter url : String
  end

  struct BetaOrganizationWebhookEndpointSigningSecret
    include JSON::Serializable

    @[JSON::Field(key: "signing_secret")]
    getter signing_secret : String
  end

  struct BetaDeletedOrganizationWebhookEndpoint
    include JSON::Serializable

    getter id : String
    getter type : String = "webhook_endpoint_deleted"
  end

  struct BetaOrganizationWebhookEndpointListResponse
    include JSON::Serializable

    getter data : Array(BetaOrganizationWebhookEndpoint)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  # ---- Claude Tag (Claude in Slack) Admin Models (Beta) ----

  struct BetaClaudeTagGuestPolicyAllow
    include JSON::Serializable

    getter type : String = "allow"

    def initialize(@type : String = "allow")
    end
  end

  struct BetaClaudeTagGuestPolicyRestrict
    include JSON::Serializable

    getter type : String = "restrict"

    def initialize(@type : String = "restrict")
    end
  end

  struct BetaClaudeTagGuestPolicyChannelOnly
    include JSON::Serializable

    getter type : String = "channel_only"

    def initialize(@type : String = "channel_only")
    end
  end

  struct BetaClaudeTagGuestPolicyGeneric
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaClaudeTagGuestPolicy = BetaClaudeTagGuestPolicyAllow |
                                   BetaClaudeTagGuestPolicyRestrict |
                                   BetaClaudeTagGuestPolicyChannelOnly |
                                   BetaClaudeTagGuestPolicyGeneric

  module NullableBetaClaudeTagGuestPolicyConverter
    def self.from_json(pull : JSON::PullParser) : BetaClaudeTagGuestPolicy?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "allow"
        BetaClaudeTagGuestPolicyAllow.from_json(raw)
      when "restrict"
        BetaClaudeTagGuestPolicyRestrict.from_json(raw)
      when "channel_only"
        BetaClaudeTagGuestPolicyChannelOnly.from_json(raw)
      else
        BetaClaudeTagGuestPolicyGeneric.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaClaudeTagGuestPolicy?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  struct BetaClaudeTagReplyModeAutomatic
    include JSON::Serializable

    getter type : String = "automatic"

    def initialize(@type : String = "automatic")
    end
  end

  struct BetaClaudeTagReplyModeMentionOnly
    include JSON::Serializable

    getter type : String = "mention_only"

    def initialize(@type : String = "mention_only")
    end
  end

  struct BetaClaudeTagReplyModeAlwaysAwake
    include JSON::Serializable

    getter type : String = "always_awake"

    def initialize(@type : String = "always_awake")
    end
  end

  struct BetaClaudeTagReplyModeThread
    include JSON::Serializable

    getter type : String = "thread"

    def initialize(@type : String = "thread")
    end
  end

  struct BetaClaudeTagReplyModeGeneric
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaClaudeTagReplyMode = BetaClaudeTagReplyModeAutomatic |
                                 BetaClaudeTagReplyModeMentionOnly |
                                 BetaClaudeTagReplyModeAlwaysAwake |
                                 BetaClaudeTagReplyModeThread |
                                 BetaClaudeTagReplyModeGeneric

  module NullableBetaClaudeTagReplyModeConverter
    def self.from_json(pull : JSON::PullParser) : BetaClaudeTagReplyMode?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "automatic"
        BetaClaudeTagReplyModeAutomatic.from_json(raw)
      when "mention_only"
        BetaClaudeTagReplyModeMentionOnly.from_json(raw)
      when "always_awake"
        BetaClaudeTagReplyModeAlwaysAwake.from_json(raw)
      when "thread"
        BetaClaudeTagReplyModeThread.from_json(raw)
      else
        BetaClaudeTagReplyModeGeneric.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaClaudeTagReplyMode?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  struct BetaClaudeTagSlackChannelIdentifiers
    include JSON::Serializable

    @[JSON::Field(key: "channel_id")]
    getter channel_id : String

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    def initialize(@channel_id : String, @workspace_id : String)
    end
  end

  struct BetaClaudeTagSlackWorkspaceIdentifiers
    include JSON::Serializable

    @[JSON::Field(key: "workspace_id")]
    getter workspace_id : String

    def initialize(@workspace_id : String)
    end
  end

  struct BetaClaudeTagSlackChannelSettingSource
    include JSON::Serializable

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    getter type : String = "slack_channel"
  end

  struct BetaClaudeTagSlackWorkspaceSettingSource
    include JSON::Serializable

    @[JSON::Field(key: "slack_workspace_id")]
    getter slack_workspace_id : String

    getter type : String = "slack_workspace"
  end

  struct BetaClaudeTagSlackParentChannelSettingSource
    include JSON::Serializable

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    getter type : String = "slack_parent_channel"
  end

  struct BetaClaudeTagSlackDefaultSettingSource
    include JSON::Serializable

    getter type : String = "slack_default"
  end

  struct BetaClaudeTagDefaultSettingSource
    include JSON::Serializable

    getter type : String = "default"
  end

  struct BetaClaudeTagSlackGridChannelSettingSource
    include JSON::Serializable

    getter slack : BetaClaudeTagSlackChannelIdentifiers
    getter type : String = "slack_grid_channel"
  end

  struct BetaClaudeTagGenericSettingSource
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaClaudeTagSettingSource = BetaClaudeTagSlackChannelSettingSource |
                                     BetaClaudeTagSlackWorkspaceSettingSource |
                                     BetaClaudeTagSlackParentChannelSettingSource |
                                     BetaClaudeTagSlackDefaultSettingSource |
                                     BetaClaudeTagDefaultSettingSource |
                                     BetaClaudeTagSlackGridChannelSettingSource |
                                     BetaClaudeTagGenericSettingSource

  module BetaClaudeTagSettingSourceConverter
    def self.from_json(pull : JSON::PullParser) : BetaClaudeTagSettingSource
      json = JSON::Any.new(pull)
      parse_json(json)
    end

    def self.parse_json(json : JSON::Any) : BetaClaudeTagSettingSource
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "slack_channel"
        BetaClaudeTagSlackChannelSettingSource.from_json(raw)
      when "slack_workspace"
        BetaClaudeTagSlackWorkspaceSettingSource.from_json(raw)
      when "slack_parent_channel"
        BetaClaudeTagSlackParentChannelSettingSource.from_json(raw)
      when "slack_default"
        BetaClaudeTagSlackDefaultSettingSource.from_json(raw)
      when "default"
        BetaClaudeTagDefaultSettingSource.from_json(raw)
      when "slack_grid_channel"
        BetaClaudeTagSlackGridChannelSettingSource.from_json(raw)
      else
        BetaClaudeTagGenericSettingSource.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaClaudeTagSettingSource, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  module NullableBetaClaudeTagSettingSourceConverter
    def self.from_json(pull : JSON::PullParser) : BetaClaudeTagSettingSource?
      if pull.kind.null?
        pull.read_null
        return nil
      end
      BetaClaudeTagSettingSourceConverter.from_json(pull)
    end

    def self.to_json(value : BetaClaudeTagSettingSource?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  module BetaClaudeTagSettingSourceArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaClaudeTagSettingSource)
      result = [] of BetaClaudeTagSettingSource
      pull.read_array do
        result << BetaClaudeTagSettingSourceConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BetaClaudeTagSettingSource), builder : JSON::Builder)
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end

  struct BetaClaudeTagSettingSources
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::NullableBetaClaudeTagSettingSourceConverter, emit_null: false)]
    getter enabled : BetaClaudeTagSettingSource?

    @[JSON::Field(key: "environment_id", converter: Anthropic::NullableBetaClaudeTagSettingSourceConverter, emit_null: false)]
    getter environment_id : BetaClaudeTagSettingSource?

    @[JSON::Field(key: "guest_policy", converter: Anthropic::NullableBetaClaudeTagSettingSourceConverter, emit_null: false)]
    getter guest_policy : BetaClaudeTagSettingSource?

    @[JSON::Field(converter: Anthropic::BetaClaudeTagSettingSourceArrayConverter)]
    getter instructions : Array(BetaClaudeTagSettingSource)

    @[JSON::Field(converter: Anthropic::NullableBetaClaudeTagSettingSourceConverter, emit_null: false)]
    getter model : BetaClaudeTagSettingSource?

    @[JSON::Field(key: "reply_mode", converter: Anthropic::NullableBetaClaudeTagSettingSourceConverter, emit_null: false)]
    getter reply_mode : BetaClaudeTagSettingSource?
  end

  struct BetaClaudeTagSettings
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "environment_id", emit_null: false)]
    getter environment_id : String?

    @[JSON::Field(key: "guest_policy", converter: Anthropic::NullableBetaClaudeTagGuestPolicyConverter, emit_null: false)]
    getter guest_policy : BetaClaudeTagGuestPolicy?

    @[JSON::Field(emit_null: false)]
    getter instructions : String?

    @[JSON::Field(emit_null: false)]
    getter model : String?

    @[JSON::Field(key: "reply_mode", converter: Anthropic::NullableBetaClaudeTagReplyModeConverter, emit_null: false)]
    getter reply_mode : BetaClaudeTagReplyMode?
  end

  # Settings payload for creating or updating Claude Tag Slack channels/workspaces.
  struct BetaClaudeTagSettingsParam
    getter enabled : Bool | OrganizationUnset | Nil
    getter environment_id : String | OrganizationUnset | Nil
    getter guest_policy : BetaClaudeTagGuestPolicy | OrganizationUnset | Nil
    getter instructions : String | OrganizationUnset | Nil
    getter model : String | OrganizationUnset | Nil
    getter reply_mode : BetaClaudeTagReplyMode | OrganizationUnset | Nil

    def initialize(
      @enabled : Bool | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @environment_id : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @guest_policy : BetaClaudeTagGuestPolicy | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @instructions : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @model : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      @reply_mode : BetaClaudeTagReplyMode | OrganizationUnset | Nil = ORGANIZATION_UNSET,
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        unless (enabled = @enabled).is_a?(OrganizationUnset)
          builder.field("enabled", enabled)
        end
        unless (environment_id = @environment_id).is_a?(OrganizationUnset)
          builder.field("environment_id", environment_id)
        end
        unless (guest_policy = @guest_policy).is_a?(OrganizationUnset)
          builder.field("guest_policy") { guest_policy.to_json(builder) }
        end
        unless (instructions = @instructions).is_a?(OrganizationUnset)
          builder.field("instructions", instructions)
        end
        unless (model = @model).is_a?(OrganizationUnset)
          builder.field("model", model)
        end
        unless (reply_mode = @reply_mode).is_a?(OrganizationUnset)
          builder.field("reply_mode") { reply_mode.to_json(builder) }
        end
      end
    end
  end

  alias BetaClaudeTagSettingsCreate = BetaClaudeTagSettingsParam
  alias BetaClaudeTagSettingsUpdate = BetaClaudeTagSettingsParam

  struct BetaClaudeTagBundle
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(emit_null: false)]
    getter description : String?

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    getter type : String = "bundle"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  struct BetaClaudeTagSlackChannelBundleTarget
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    getter type : String = "slack_channel"
  end

  struct BetaClaudeTagSlackWorkspaceBundleTarget
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "slack_workspace_id")]
    getter slack_workspace_id : String

    getter type : String = "slack_workspace"
  end

  struct BetaClaudeTagGenericBundleTarget
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaClaudeTagBundleTarget = BetaClaudeTagSlackChannelBundleTarget |
                                    BetaClaudeTagSlackWorkspaceBundleTarget |
                                    BetaClaudeTagGenericBundleTarget

  module BetaClaudeTagBundleTargetConverter
    def self.from_json(pull : JSON::PullParser) : BetaClaudeTagBundleTarget
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "slack_channel"
        BetaClaudeTagSlackChannelBundleTarget.from_json(raw)
      when "slack_workspace"
        BetaClaudeTagSlackWorkspaceBundleTarget.from_json(raw)
      else
        BetaClaudeTagGenericBundleTarget.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaClaudeTagBundleTarget, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  module BetaClaudeTagBundleTargetArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BetaClaudeTagBundleTarget)
      result = [] of BetaClaudeTagBundleTarget
      pull.read_array do
        result << BetaClaudeTagBundleTargetConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BetaClaudeTagBundleTarget), builder : JSON::Builder)
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end

  struct BetaClaudeTagBundleTargetListResponse
    include JSON::Serializable
    include PageCursorMethods

    @[JSON::Field(converter: Anthropic::BetaClaudeTagBundleTargetArrayConverter)]
    getter data : Array(BetaClaudeTagBundleTarget)

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?
  end

  struct BetaClaudeTagSlackChannelBundleTargetCreate
    include JSON::Serializable

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    getter type : String = "slack_channel"

    def initialize(@slack_channel_id : String, @type : String = "slack_channel")
    end
  end

  struct BetaClaudeTagSlackWorkspaceBundleTargetCreate
    include JSON::Serializable

    @[JSON::Field(key: "slack_workspace_id")]
    getter slack_workspace_id : String

    getter type : String = "slack_workspace"

    def initialize(@slack_workspace_id : String, @type : String = "slack_workspace")
    end
  end

  alias BetaClaudeTagBundleTargetCreate = BetaClaudeTagSlackChannelBundleTargetCreate |
                                          BetaClaudeTagSlackWorkspaceBundleTargetCreate

  struct BetaClaudeTagDeletedBundleTarget
    include JSON::Serializable

    getter id : String
    getter type : String = "bundle_target_deleted"
  end

  struct BetaClaudeTagSlackChannel
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter settings : BetaClaudeTagSettings
    getter slack : BetaClaudeTagSlackChannelIdentifiers
    getter sources : BetaClaudeTagSettingSources
    getter type : String = "slack_channel"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  struct BetaClaudeTagDeletedSlackChannel
    include JSON::Serializable

    getter id : String
    getter type : String = "slack_channel_deleted"
  end

  struct BetaClaudeTagSlackWorkspace
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter settings : BetaClaudeTagSettings
    getter slack : BetaClaudeTagSlackWorkspaceIdentifiers
    getter sources : BetaClaudeTagSettingSources
    getter type : String = "slack_workspace"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end
end
