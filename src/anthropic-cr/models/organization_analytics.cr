module Anthropic
  # Sort order for analytics list endpoints.
  module AnalyticsOrder
    ASC  = "asc"
    DESC = "desc"
  end

  alias BetaAnalyticsOrder = AnalyticsOrder

  # Sort order for `usage` / `cost` report endpoints.
  module BetaAnalyticsUsageCostSortOrder
    ASC  = "asc"
    DESC = "desc"
  end

  # Token-cache creation counts with 64-bit capacity for org-wide analytics.
  struct AnalyticsCacheCreation
    include JSON::Serializable

    @[JSON::Field(key: "ephemeral_1h_input_tokens")]
    getter ephemeral_1h_input_tokens : Int64 = 0_i64

    @[JSON::Field(key: "ephemeral_5m_input_tokens")]
    getter ephemeral_5m_input_tokens : Int64 = 0_i64
  end

  # Server tool usage counts returned in analytics usage metrics.
  struct BetaAnalyticsServerToolUse
    include JSON::Serializable

    @[JSON::Field(key: "web_search_requests")]
    getter web_search_requests : Int64 = 0_i64
  end

  # Known analytics dimension / filter enums.
  module BetaAnalyticsTimeBucketWidth
    DAY    = "1d"
    HOUR   = "1h"
    MINUTE = "1m"
  end

  module BetaAnalyticsSpeed
    FAST     = "fast"
    STANDARD = "standard"
  end

  module BetaAnalyticsContextWindow
    FROM_0_TO_200K   = "0-200k"
    FROM_200K_TO_1M  = "200k-1M"
    FROM_200K_TO_1_M = "200k-1M"
  end

  module BetaAnalyticsClaudeTagCategory
    DM         = "dm"
    ENGAGED    = "engaged"
    MONITORING = "monitoring"
    PROACTIVE  = "proactive"
    SCHEDULED  = "scheduled"
  end

  module BetaAnalyticsActorType
    API_ACTOR             = "api_actor"
    FEDERATED_ACTOR       = "federated_actor"
    SERVICE_ACCOUNT_ACTOR = "service_account_actor"
    USER_ACTOR            = "user_actor"
  end

  module BetaAnalyticsServiceTier
    BATCH              = "batch"
    FLEX               = "flex"
    FLEX_DISCOUNT      = "flex_discount"
    PRIORITY           = "priority"
    PRIORITY_ON_DEMAND = "priority_on_demand"
    STANDARD           = "standard"
  end

  module BetaAnalyticsTokenType
    CACHE_CREATION_EPHEMERAL_1H_INPUT_TOKENS = "cache_creation.ephemeral_1h_input_tokens"
    CACHE_CREATION_EPHEMERAL_5M_INPUT_TOKENS = "cache_creation.ephemeral_5m_input_tokens"
    CACHE_READ_INPUT_TOKENS                  = "cache_read_input_tokens"
    OUTPUT_TOKENS                            = "output_tokens"
    UNCACHED_INPUT_TOKENS                    = "uncached_input_tokens"
  end

  module BetaAnalyticsCostType
    CODE_EXECUTION = "code_execution"
    TOKENS         = "tokens"
    WEB_SEARCH     = "web_search"
  end

  module BetaAnalyticsGroupedCostType
    CODE_EXECUTION = "code_execution"
    SESSION_USAGE  = "session_usage"
    TOKENS         = "tokens"
    WEB_SEARCH     = "web_search"
  end

  module BetaAnalyticsInferenceGeoFilter
    GLOBAL        = "global"
    NOT_AVAILABLE = "not_available"
    US            = "us"
  end

  module BetaAnalyticsUsageCostProductFilter
    CHAT                = "chat"
    CHAT_COWORK_UNIFIED = "chat_cowork_unified"
    CLAUDE_CODE         = "claude_code"
    CLAUDE_CONSOLE      = "claude_console"
    CLAUDE_DESIGN       = "claude_design"
    CLAUDE_IN_CHROME    = "claude_in_chrome"
    CLAUDE_TAG          = "claude_tag"
    COWORK              = "cowork"
    MANAGED_AGENTS_API  = "managed_agents_api"
    MESSAGE_BATCHES_API = "message_batches_api"
    MESSAGES_API        = "messages_api"
    OFFICE_AGENT        = "office_agent"
  end

  module BetaAnalyticsUsageGroupBy
    ACTOR               = "actor"
    ACTOR_TYPE          = "actor_type"
    AGENT_ID            = "agent_id"
    API_KEY_ID          = "api_key_id"
    CLAUDE_TAG_CATEGORY = "claude_tag_category"
    CLAUDE_TAG_USER_ID  = "claude_tag_user_id"
    CONTEXT_WINDOW      = "context_window"
    DEPLOYMENT_ID       = "deployment_id"
    ENVIRONMENT_ID      = "environment_id"
    INFERENCE_GEO       = "inference_geo"
    MODEL               = "model"
    ORGANIZATION_ID     = "organization_id"
    PRODUCT             = "product"
    RBAC_GROUP_ID       = "rbac_group_id"
    SERVICE_TIER        = "service_tier"
    SESSION_ID          = "session_id"
    SLACK_CHANNEL_ID    = "slack_channel_id"
    SPEED               = "speed"
    USER_PROFILE_ID     = "user_profile_id"
    WORKSPACE_ID        = "workspace_id"
  end

  module BetaAnalyticsCostGroupBy
    ACTOR               = "actor"
    ACTOR_TYPE          = "actor_type"
    AGENT_ID            = "agent_id"
    API_KEY_ID          = "api_key_id"
    CLAUDE_TAG_CATEGORY = "claude_tag_category"
    CLAUDE_TAG_USER_ID  = "claude_tag_user_id"
    CONTEXT_WINDOW      = "context_window"
    COST_TYPE           = "cost_type"
    DEPLOYMENT_ID       = "deployment_id"
    ENVIRONMENT_ID      = "environment_id"
    INFERENCE_GEO       = "inference_geo"
    MODEL               = "model"
    ORGANIZATION_ID     = "organization_id"
    PRODUCT             = "product"
    RBAC_GROUP_ID       = "rbac_group_id"
    SERVICE_TIER        = "service_tier"
    SESSION_ID          = "session_id"
    SLACK_CHANNEL_ID    = "slack_channel_id"
    SPEED               = "speed"
    TOKEN_TYPE          = "token_type"
    USER_PROFILE_ID     = "user_profile_id"
    WORKSPACE_ID        = "workspace_id"
  end

  module BetaAnalyticsUsageOrderBy
    OUTPUT_TOKENS         = "output_tokens"
    REQUESTS              = "requests"
    TIME                  = "time"
    TOTAL_TOKENS          = "total_tokens"
    UNCACHED_INPUT_TOKENS = "uncached_input_tokens"
  end

  module BetaAnalyticsCostOrderBy
    AMOUNT      = "amount"
    LIST_AMOUNT = "list_amount"
    TIME        = "time"
  end

  # ---- Enterprise Usage Analytics Models (GA + Beta) ----

  struct AnalyticsUser
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "email_address")]
    getter email_address : String

    getter type : String = "user"
  end

  alias BetaAnalyticsUser = AnalyticsUser

  struct AnalyticsLinesOfCode
    include JSON::Serializable

    @[JSON::Field(key: "added_count")]
    getter added_count : Int64

    @[JSON::Field(key: "removed_count")]
    getter removed_count : Int64
  end

  alias BetaAnalyticsLinesOfCode = AnalyticsLinesOfCode

  struct AnalyticsCoreCodeMetrics
    include JSON::Serializable

    @[JSON::Field(key: "artifacts_created_count")]
    getter artifacts_created_count : Int64

    @[JSON::Field(key: "commit_count")]
    getter commit_count : Int64

    @[JSON::Field(key: "distinct_session_count", emit_null: false)]
    getter distinct_session_count : Int64?

    @[JSON::Field(key: "lines_of_code")]
    getter lines_of_code : AnalyticsLinesOfCode

    @[JSON::Field(key: "pull_request_count")]
    getter pull_request_count : Int64
  end

  alias BetaAnalyticsCoreCodeMetrics = AnalyticsCoreCodeMetrics

  struct AnalyticsToolActionCounts
    include JSON::Serializable

    @[JSON::Field(key: "accepted_count")]
    getter accepted_count : Int64

    @[JSON::Field(key: "rejected_count")]
    getter rejected_count : Int64
  end

  alias BetaAnalyticsToolActionCounts = AnalyticsToolActionCounts

  struct AnalyticsToolActions
    include JSON::Serializable

    @[JSON::Field(key: "edit_tool")]
    getter edit_tool : AnalyticsToolActionCounts

    @[JSON::Field(key: "multi_edit_tool")]
    getter multi_edit_tool : AnalyticsToolActionCounts

    @[JSON::Field(key: "notebook_edit_tool")]
    getter notebook_edit_tool : AnalyticsToolActionCounts

    @[JSON::Field(key: "write_tool")]
    getter write_tool : AnalyticsToolActionCounts
  end

  alias BetaAnalyticsToolActions = AnalyticsToolActions

  struct AnalyticsClaudeCodeMetrics
    include JSON::Serializable

    @[JSON::Field(key: "core_metrics")]
    getter core_metrics : AnalyticsCoreCodeMetrics

    @[JSON::Field(key: "tool_actions")]
    getter tool_actions : AnalyticsToolActions
  end

  alias BetaAnalyticsClaudeCodeMetrics = AnalyticsClaudeCodeMetrics

  struct AnalyticsChatMetrics
    include JSON::Serializable

    @[JSON::Field(key: "connectors_used_count")]
    getter connectors_used_count : Int64

    @[JSON::Field(key: "distinct_artifacts_created_count")]
    getter distinct_artifacts_created_count : Int64

    @[JSON::Field(key: "distinct_connectors_used_count", emit_null: false)]
    getter distinct_connectors_used_count : Int64?

    @[JSON::Field(key: "distinct_conversation_count", emit_null: false)]
    getter distinct_conversation_count : Int64?

    @[JSON::Field(key: "distinct_files_uploaded_count", emit_null: false)]
    getter distinct_files_uploaded_count : Int64?

    @[JSON::Field(key: "distinct_projects_created_count")]
    getter distinct_projects_created_count : Int64

    @[JSON::Field(key: "distinct_projects_used_count", emit_null: false)]
    getter distinct_projects_used_count : Int64?

    @[JSON::Field(key: "distinct_shared_artifacts_viewed_count", emit_null: false)]
    getter distinct_shared_artifacts_viewed_count : Int64?

    @[JSON::Field(key: "distinct_skills_used_count", emit_null: false)]
    getter distinct_skills_used_count : Int64?

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64

    @[JSON::Field(key: "shared_conversations_viewed_count")]
    getter shared_conversations_viewed_count : Int64

    @[JSON::Field(key: "thinking_message_count")]
    getter thinking_message_count : Int64
  end

  alias BetaAnalyticsChatMetrics = AnalyticsChatMetrics
  alias AnalyticsChatCoworkUnifiedChatMetrics = AnalyticsChatMetrics
  alias BetaAnalyticsChatCoworkUnifiedChatMetrics = AnalyticsChatMetrics

  struct AnalyticsCoworkMetrics
    include JSON::Serializable

    @[JSON::Field(key: "action_count")]
    getter action_count : Int64

    @[JSON::Field(key: "artifacts_created_count")]
    getter artifacts_created_count : Int64

    @[JSON::Field(key: "connectors_used_count")]
    getter connectors_used_count : Int64

    @[JSON::Field(key: "dispatch_turn_count")]
    getter dispatch_turn_count : Int64

    @[JSON::Field(key: "distinct_connectors_used_count", emit_null: false)]
    getter distinct_connectors_used_count : Int64?

    @[JSON::Field(key: "distinct_plugins_used_count", emit_null: false)]
    getter distinct_plugins_used_count : Int64?

    @[JSON::Field(key: "distinct_session_count", emit_null: false)]
    getter distinct_session_count : Int64?

    @[JSON::Field(key: "distinct_skills_used_count", emit_null: false)]
    getter distinct_skills_used_count : Int64?

    @[JSON::Field(key: "edit_tool_count", emit_null: false)]
    getter edit_tool_count : Int64?

    @[JSON::Field(key: "file_edit_count", emit_null: false)]
    getter file_edit_count : Int64?

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64

    @[JSON::Field(key: "multi_edit_tool_count", emit_null: false)]
    getter multi_edit_tool_count : Int64?

    @[JSON::Field(key: "notebook_edit_tool_count", emit_null: false)]
    getter notebook_edit_tool_count : Int64?

    @[JSON::Field(key: "plugins_used_count", emit_null: false)]
    getter plugins_used_count : Int64?

    @[JSON::Field(key: "sessions_with_file_edits_count", emit_null: false)]
    getter sessions_with_file_edits_count : Int64?

    @[JSON::Field(key: "skills_used_count")]
    getter skills_used_count : Int64

    @[JSON::Field(key: "write_tool_count", emit_null: false)]
    getter write_tool_count : Int64?
  end

  alias BetaAnalyticsCoworkMetrics = AnalyticsCoworkMetrics
  alias AnalyticsChatCoworkUnifiedSessionsMetrics = AnalyticsCoworkMetrics
  alias BetaAnalyticsChatCoworkUnifiedSessionsMetrics = AnalyticsCoworkMetrics

  struct AnalyticsChatCoworkUnifiedMetrics
    include JSON::Serializable

    getter chat : AnalyticsChatCoworkUnifiedChatMetrics
    getter sessions : AnalyticsChatCoworkUnifiedSessionsMetrics
  end

  alias BetaAnalyticsChatCoworkUnifiedMetrics = AnalyticsChatCoworkUnifiedMetrics

  struct AnalyticsDesignMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_projects_created_count")]
    getter distinct_projects_created_count : Int64

    @[JSON::Field(key: "distinct_projects_used_count", emit_null: false)]
    getter distinct_projects_used_count : Int64?

    @[JSON::Field(key: "distinct_session_count", emit_null: false)]
    getter distinct_session_count : Int64?

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64
  end

  alias BetaAnalyticsDesignMetrics = AnalyticsDesignMetrics

  struct AnalyticsOfficeProductMetrics
    include JSON::Serializable

    @[JSON::Field(key: "connectors_used_count")]
    getter connectors_used_count : Int64

    @[JSON::Field(key: "distinct_connectors_used_count", emit_null: false)]
    getter distinct_connectors_used_count : Int64?

    @[JSON::Field(key: "distinct_session_count", emit_null: false)]
    getter distinct_session_count : Int64?

    @[JSON::Field(key: "distinct_skills_used_count", emit_null: false)]
    getter distinct_skills_used_count : Int64?

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64

    @[JSON::Field(key: "skills_used_count")]
    getter skills_used_count : Int64
  end

  alias BetaAnalyticsOfficeProductMetrics = AnalyticsOfficeProductMetrics

  struct AnalyticsOfficeMetrics
    include JSON::Serializable

    getter excel : AnalyticsOfficeProductMetrics
    getter outlook : AnalyticsOfficeProductMetrics
    getter powerpoint : AnalyticsOfficeProductMetrics
    getter word : AnalyticsOfficeProductMetrics
  end

  alias BetaAnalyticsOfficeMetrics = AnalyticsOfficeMetrics

  struct AnalyticsScienceMetrics
    include JSON::Serializable

    @[JSON::Field(key: "delegation_count")]
    getter delegation_count : Int64

    @[JSON::Field(key: "distinct_session_count", emit_null: false)]
    getter distinct_session_count : Int64?

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64

    @[JSON::Field(key: "remote_compute_job_count")]
    getter remote_compute_job_count : Int64

    @[JSON::Field(key: "skills_used_count")]
    getter skills_used_count : Int64
  end

  alias BetaAnalyticsScienceMetrics = AnalyticsScienceMetrics

  struct AnalyticsClaudeTagMetrics
    include JSON::Serializable

    @[JSON::Field(key: "active_day_count", emit_null: false)]
    getter active_day_count : Int64?

    @[JSON::Field(key: "active_message_count", emit_null: false)]
    getter active_message_count : Int64?
  end

  alias BetaAnalyticsClaudeTagMetrics = AnalyticsClaudeTagMetrics

  struct AnalyticsSingleDayActivitySummary
    include JSON::Serializable

    @[JSON::Field(key: "assigned_seat_count", emit_null: false)]
    getter assigned_seat_count : Int64?

    @[JSON::Field(key: "cowork_daily_active_user_count")]
    getter cowork_daily_active_user_count : Int64

    @[JSON::Field(key: "cowork_monthly_active_user_count")]
    getter cowork_monthly_active_user_count : Int64

    @[JSON::Field(key: "cowork_weekly_active_user_count")]
    getter cowork_weekly_active_user_count : Int64

    @[JSON::Field(key: "daily_active_user_count")]
    getter daily_active_user_count : Int64

    @[JSON::Field(key: "daily_adoption_rate", emit_null: false)]
    getter daily_adoption_rate : Float64?

    @[JSON::Field(key: "ending_at")]
    getter ending_at : String

    @[JSON::Field(key: "monthly_active_user_count")]
    getter monthly_active_user_count : Int64

    @[JSON::Field(key: "monthly_adoption_rate", emit_null: false)]
    getter monthly_adoption_rate : Float64?

    @[JSON::Field(key: "pending_invite_count", emit_null: false)]
    getter pending_invite_count : Int64?

    @[JSON::Field(key: "starting_at")]
    getter starting_at : String

    @[JSON::Field(key: "weekly_active_user_count")]
    getter weekly_active_user_count : Int64

    @[JSON::Field(key: "weekly_adoption_rate", emit_null: false)]
    getter weekly_adoption_rate : Float64?

    @[JSON::Field(key: "chat_cowork_unified_daily_active_user_count", emit_null: false)]
    getter chat_cowork_unified_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "chat_cowork_unified_monthly_active_user_count", emit_null: false)]
    getter chat_cowork_unified_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "chat_cowork_unified_weekly_active_user_count", emit_null: false)]
    getter chat_cowork_unified_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "chat_daily_active_user_count", emit_null: false)]
    getter chat_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "chat_monthly_active_user_count", emit_null: false)]
    getter chat_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "chat_weekly_active_user_count", emit_null: false)]
    getter chat_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_code_daily_active_user_count", emit_null: false)]
    getter claude_code_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_code_monthly_active_user_count", emit_null: false)]
    getter claude_code_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_code_weekly_active_user_count", emit_null: false)]
    getter claude_code_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_design_daily_active_user_count", emit_null: false)]
    getter claude_design_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_design_monthly_active_user_count", emit_null: false)]
    getter claude_design_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_design_weekly_active_user_count", emit_null: false)]
    getter claude_design_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_tag_daily_active_user_count", emit_null: false)]
    getter claude_tag_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_tag_monthly_active_user_count", emit_null: false)]
    getter claude_tag_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "claude_tag_weekly_active_user_count", emit_null: false)]
    getter claude_tag_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "office_agent_daily_active_user_count", emit_null: false)]
    getter office_agent_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "office_agent_monthly_active_user_count", emit_null: false)]
    getter office_agent_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "office_agent_weekly_active_user_count", emit_null: false)]
    getter office_agent_weekly_active_user_count : Int64? = nil

    @[JSON::Field(key: "science_daily_active_user_count", emit_null: false)]
    getter science_daily_active_user_count : Int64? = nil

    @[JSON::Field(key: "science_entitled_user_count", emit_null: false)]
    getter science_entitled_user_count : Int64? = nil

    @[JSON::Field(key: "science_monthly_active_user_count", emit_null: false)]
    getter science_monthly_active_user_count : Int64? = nil

    @[JSON::Field(key: "science_weekly_active_user_count", emit_null: false)]
    getter science_weekly_active_user_count : Int64? = nil
  end

  alias BetaAnalyticsSingleDayActivitySummary = AnalyticsSingleDayActivitySummary

  struct AnalyticsUserActivity
    include JSON::Serializable

    @[JSON::Field(key: "chat_metrics")]
    getter chat_metrics : AnalyticsChatMetrics

    @[JSON::Field(key: "claude_code_metrics")]
    getter claude_code_metrics : AnalyticsClaudeCodeMetrics

    @[JSON::Field(key: "cowork_metrics")]
    getter cowork_metrics : AnalyticsCoworkMetrics

    @[JSON::Field(key: "design_metrics")]
    getter design_metrics : AnalyticsDesignMetrics

    @[JSON::Field(key: "distinct_user_count", emit_null: false)]
    getter distinct_user_count : Int64?

    @[JSON::Field(key: "office_metrics")]
    getter office_metrics : AnalyticsOfficeMetrics

    @[JSON::Field(key: "science_metrics")]
    getter science_metrics : AnalyticsScienceMetrics

    @[JSON::Field(emit_null: false)]
    getter user : AnalyticsUser?

    @[JSON::Field(key: "web_search_count")]
    getter web_search_count : Int64

    @[JSON::Field(key: "chat_cowork_unified_metrics", emit_null: false)]
    getter chat_cowork_unified_metrics : AnalyticsChatCoworkUnifiedMetrics? = nil

    @[JSON::Field(key: "claude_tag_metrics", emit_null: false)]
    getter claude_tag_metrics : AnalyticsClaudeTagMetrics? = nil

    @[JSON::Field(key: "last_activity_date", emit_null: false)]
    getter last_activity_date : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil
  end

  alias BetaAnalyticsUserActivity = AnalyticsUserActivity

  struct AnalyticsProjectActivity
    include JSON::Serializable

    @[JSON::Field(key: "created_at", emit_null: false)]
    getter created_at : String?

    @[JSON::Field(key: "created_by", emit_null: false)]
    getter created_by : AnalyticsUser?

    @[JSON::Field(key: "distinct_conversation_count", emit_null: false)]
    getter distinct_conversation_count : Int64?

    @[JSON::Field(key: "distinct_user_count")]
    getter distinct_user_count : Int64

    @[JSON::Field(key: "message_count")]
    getter message_count : Int64

    @[JSON::Field(key: "project_id")]
    getter project_id : String

    @[JSON::Field(key: "project_name")]
    getter project_name : String

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String? = nil
  end

  alias BetaAnalyticsProjectActivity = AnalyticsProjectActivity

  struct AnalyticsConnectorChatMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_conversation_connector_used_count", emit_null: false)]
    getter distinct_conversation_connector_used_count : Int64?
  end

  alias BetaAnalyticsConnectorChatMetrics = AnalyticsConnectorChatMetrics
  alias AnalyticsConnectorChatCoworkUnifiedChatMetrics = AnalyticsConnectorChatMetrics

  struct AnalyticsConnectorSessionMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_session_connector_used_count", emit_null: false)]
    getter distinct_session_connector_used_count : Int64?
  end

  alias BetaAnalyticsConnectorClaudeCodeMetrics = AnalyticsConnectorSessionMetrics
  alias BetaAnalyticsConnectorCoworkMetrics = AnalyticsConnectorSessionMetrics
  alias BetaAnalyticsConnectorOfficeProductMetrics = AnalyticsConnectorSessionMetrics
  alias AnalyticsConnectorChatCoworkUnifiedSessionsMetrics = AnalyticsConnectorSessionMetrics

  struct AnalyticsConnectorOfficeMetrics
    include JSON::Serializable

    getter excel : AnalyticsConnectorSessionMetrics
    getter outlook : AnalyticsConnectorSessionMetrics
    getter powerpoint : AnalyticsConnectorSessionMetrics
    getter word : AnalyticsConnectorSessionMetrics
  end

  alias BetaAnalyticsConnectorOfficeMetrics = AnalyticsConnectorOfficeMetrics

  struct AnalyticsConnectorChatCoworkUnifiedMetrics
    include JSON::Serializable

    getter chat : AnalyticsConnectorChatMetrics
    getter sessions : AnalyticsConnectorSessionMetrics
  end

  alias BetaAnalyticsConnectorChatCoworkUnifiedMetrics = AnalyticsConnectorChatCoworkUnifiedMetrics

  struct AnalyticsConnectorActivity
    include JSON::Serializable

    @[JSON::Field(key: "chat_metrics")]
    getter chat_metrics : AnalyticsConnectorChatMetrics

    @[JSON::Field(key: "claude_code_metrics")]
    getter claude_code_metrics : AnalyticsConnectorSessionMetrics

    @[JSON::Field(key: "connector_display_name", emit_null: false)]
    getter connector_display_name : String?

    @[JSON::Field(key: "connector_name")]
    getter connector_name : String

    @[JSON::Field(key: "cowork_metrics")]
    getter cowork_metrics : AnalyticsConnectorSessionMetrics

    @[JSON::Field(key: "distinct_user_count")]
    getter distinct_user_count : Int64

    @[JSON::Field(key: "individual_auth_distinct_user_count", emit_null: false)]
    getter individual_auth_distinct_user_count : Int64?

    @[JSON::Field(key: "managed_auth_distinct_user_count", emit_null: false)]
    getter managed_auth_distinct_user_count : Int64?

    @[JSON::Field(key: "office_metrics")]
    getter office_metrics : AnalyticsConnectorOfficeMetrics

    @[JSON::Field(key: "read_call_count", emit_null: false)]
    getter read_call_count : Int64?

    @[JSON::Field(key: "unclassified_call_count", emit_null: false)]
    getter unclassified_call_count : Int64?

    @[JSON::Field(key: "write_call_count", emit_null: false)]
    getter write_call_count : Int64?

    @[JSON::Field(key: "chat_cowork_unified_metrics", emit_null: false)]
    getter chat_cowork_unified_metrics : AnalyticsConnectorChatCoworkUnifiedMetrics? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String? = nil
  end

  alias BetaAnalyticsConnectorActivity = AnalyticsConnectorActivity

  struct AnalyticsPluginSessionMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_session_plugin_used_count", emit_null: false)]
    getter distinct_session_plugin_used_count : Int64?
  end

  alias BetaAnalyticsPluginClaudeCodeMetrics = AnalyticsPluginSessionMetrics
  alias BetaAnalyticsPluginCoworkMetrics = AnalyticsPluginSessionMetrics
  alias AnalyticsPluginChatCoworkUnifiedMetrics = AnalyticsPluginSessionMetrics
  alias BetaAnalyticsPluginChatCoworkUnifiedMetrics = AnalyticsPluginSessionMetrics

  struct AnalyticsPluginActivity
    include JSON::Serializable

    @[JSON::Field(key: "claude_code_metrics")]
    getter claude_code_metrics : AnalyticsPluginSessionMetrics

    @[JSON::Field(key: "cowork_metrics")]
    getter cowork_metrics : AnalyticsPluginSessionMetrics

    @[JSON::Field(key: "distinct_user_count")]
    getter distinct_user_count : Int64

    @[JSON::Field(key: "install_count", emit_null: false)]
    getter install_count : Int64?

    @[JSON::Field(key: "invocation_count")]
    getter invocation_count : Int64

    @[JSON::Field(key: "plugin_id", emit_null: false)]
    getter plugin_id : String?

    @[JSON::Field(key: "plugin_name")]
    getter plugin_name : String

    @[JSON::Field(key: "chat_cowork_unified_metrics", emit_null: false)]
    getter chat_cowork_unified_metrics : AnalyticsPluginSessionMetrics? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String? = nil
  end

  alias BetaAnalyticsPluginActivity = AnalyticsPluginActivity

  struct AnalyticsSkillChatMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_conversation_skill_used_count", emit_null: false)]
    getter distinct_conversation_skill_used_count : Int64?
  end

  alias BetaAnalyticsSkillChatMetrics = AnalyticsSkillChatMetrics
  alias AnalyticsSkillChatCoworkUnifiedChatMetrics = AnalyticsSkillChatMetrics

  struct AnalyticsSkillSessionMetrics
    include JSON::Serializable

    @[JSON::Field(key: "distinct_session_skill_used_count", emit_null: false)]
    getter distinct_session_skill_used_count : Int64?
  end

  alias BetaAnalyticsSkillClaudeCodeMetrics = AnalyticsSkillSessionMetrics
  alias BetaAnalyticsSkillCoworkMetrics = AnalyticsSkillSessionMetrics
  alias BetaAnalyticsSkillOfficeProductMetrics = AnalyticsSkillSessionMetrics
  alias AnalyticsSkillChatCoworkUnifiedSessionsMetrics = AnalyticsSkillSessionMetrics

  struct AnalyticsSkillOfficeMetrics
    include JSON::Serializable

    getter excel : AnalyticsSkillSessionMetrics
    getter outlook : AnalyticsSkillSessionMetrics
    getter powerpoint : AnalyticsSkillSessionMetrics
    getter word : AnalyticsSkillSessionMetrics
  end

  alias BetaAnalyticsSkillOfficeMetrics = AnalyticsSkillOfficeMetrics

  struct AnalyticsSkillChatCoworkUnifiedMetrics
    include JSON::Serializable

    getter chat : AnalyticsSkillChatMetrics
    getter sessions : AnalyticsSkillSessionMetrics
  end

  alias BetaAnalyticsSkillChatCoworkUnifiedMetrics = AnalyticsSkillChatCoworkUnifiedMetrics

  struct AnalyticsSkillActivity
    include JSON::Serializable

    @[JSON::Field(key: "attributed_list_price", emit_null: false)]
    getter attributed_list_price : String?

    @[JSON::Field(key: "chat_metrics")]
    getter chat_metrics : AnalyticsSkillChatMetrics

    @[JSON::Field(key: "claude_code_metrics")]
    getter claude_code_metrics : AnalyticsSkillSessionMetrics

    @[JSON::Field(key: "cowork_metrics")]
    getter cowork_metrics : AnalyticsSkillSessionMetrics

    @[JSON::Field(emit_null: false)]
    getter currency : String?

    @[JSON::Field(key: "distinct_user_count")]
    getter distinct_user_count : Int64

    @[JSON::Field(key: "enable_count", emit_null: false)]
    getter enable_count : Int64?

    @[JSON::Field(key: "estimated_overage_spend", emit_null: false)]
    getter estimated_overage_spend : String?

    @[JSON::Field(key: "invocation_count", emit_null: false)]
    getter invocation_count : Int64?

    @[JSON::Field(key: "office_metrics")]
    getter office_metrics : AnalyticsSkillOfficeMetrics

    @[JSON::Field(key: "share_status", emit_null: false)]
    getter share_status : String?

    @[JSON::Field(key: "skill_display_name", emit_null: false)]
    getter skill_display_name : String?

    @[JSON::Field(key: "skill_name")]
    getter skill_name : String

    @[JSON::Field(key: "chat_cowork_unified_metrics", emit_null: false)]
    getter chat_cowork_unified_metrics : AnalyticsSkillChatCoworkUnifiedMetrics? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String? = nil
  end

  alias BetaAnalyticsSkillActivity = AnalyticsSkillActivity

  struct AnalyticsArtifactActivity
    include JSON::Serializable

    @[JSON::Field(key: "artifact_type")]
    getter artifact_type : String

    @[JSON::Field(key: "artifacts_created_count")]
    getter artifacts_created_count : Int64

    @[JSON::Field(key: "distinct_user_count")]
    getter distinct_user_count : Int64

    @[JSON::Field(key: "is_shared")]
    getter? is_shared : Bool

    @[JSON::Field(key: "published_artifacts_created_count")]
    getter published_artifacts_created_count : Int64

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "rbac_group_name", emit_null: false)]
    getter rbac_group_name : String? = nil

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String? = nil
  end

  alias BetaAnalyticsArtifactActivity = AnalyticsArtifactActivity

  # ---- API / Org Usage & Cost Report Models (Beta) ----

  struct BetaAnalyticsUserActor
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

  alias BetaAnalyticsReportUserActor = BetaAnalyticsUserActor

  struct BetaAnalyticsServiceAccountActor
    include JSON::Serializable

    @[JSON::Field(key: "service_account_id")]
    getter service_account_id : String

    getter type : String = "service_account_actor"
  end

  struct BetaAnalyticsAPIActor
    include JSON::Serializable

    @[JSON::Field(key: "api_key_id")]
    getter api_key_id : String

    getter type : String = "api_actor"
  end

  struct BetaAnalyticsFederatedActorAWSProvider
    include JSON::Serializable

    @[JSON::Field(key: "account_id")]
    getter account_id : String

    @[JSON::Field(key: "signed_principal")]
    getter signed_principal : String

    getter type : String = "aws"
  end

  struct BetaAnalyticsFederatedActorAzureProvider
    include JSON::Serializable

    @[JSON::Field(key: "subscription_id")]
    getter subscription_id : String

    getter type : String = "azure"
  end

  struct BetaAnalyticsFederatedActorGCPProvider
    include JSON::Serializable

    @[JSON::Field(key: "project_number")]
    getter project_number : String

    getter type : String = "gcp"
  end

  struct BetaAnalyticsFederatedActorOIDCProvider
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter issuer : String?

    getter type : String = "oidc"
  end

  struct BetaAnalyticsGenericFederatedActorProvider
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaAnalyticsFederatedActorProvider = BetaAnalyticsFederatedActorAWSProvider |
                                              BetaAnalyticsFederatedActorAzureProvider |
                                              BetaAnalyticsFederatedActorGCPProvider |
                                              BetaAnalyticsFederatedActorOIDCProvider |
                                              BetaAnalyticsGenericFederatedActorProvider

  module BetaAnalyticsFederatedActorProviderConverter
    def self.from_json(pull : JSON::PullParser) : BetaAnalyticsFederatedActorProvider
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "aws"
        BetaAnalyticsFederatedActorAWSProvider.from_json(raw)
      when "azure"
        BetaAnalyticsFederatedActorAzureProvider.from_json(raw)
      when "gcp"
        BetaAnalyticsFederatedActorGCPProvider.from_json(raw)
      when "oidc"
        BetaAnalyticsFederatedActorOIDCProvider.from_json(raw)
      else
        BetaAnalyticsGenericFederatedActorProvider.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaAnalyticsFederatedActorProvider, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  struct BetaAnalyticsFederatedActor
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::BetaAnalyticsFederatedActorProviderConverter)]
    getter provider : BetaAnalyticsFederatedActorProvider

    @[JSON::Field(emit_null: false)]
    getter subject : String?

    getter type : String = "federated_actor"
  end

  struct BetaAnalyticsGenericActor
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias BetaAnalyticsActor = BetaAnalyticsUserActor |
                             BetaAnalyticsServiceAccountActor |
                             BetaAnalyticsFederatedActor |
                             BetaAnalyticsAPIActor |
                             BetaAnalyticsGenericActor

  module BetaAnalyticsActorConverter
    def self.from_json(pull : JSON::PullParser) : BetaAnalyticsActor
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "user_actor"
        BetaAnalyticsUserActor.from_json(raw)
      when "service_account_actor"
        BetaAnalyticsServiceAccountActor.from_json(raw)
      when "federated_actor"
        BetaAnalyticsFederatedActor.from_json(raw)
      when "api_actor"
        BetaAnalyticsAPIActor.from_json(raw)
      else
        BetaAnalyticsGenericActor.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaAnalyticsActor, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  module NullableBetaAnalyticsActorConverter
    def self.from_json(pull : JSON::PullParser) : BetaAnalyticsActor?
      if pull.kind.null?
        pull.read_null
        return nil
      end
      BetaAnalyticsActorConverter.from_json(pull)
    end

    def self.to_json(value : BetaAnalyticsActor?, builder : JSON::Builder)
      if value.nil?
        builder.null
      else
        value.to_json(builder)
      end
    end
  end

  struct BetaAnalyticsUsageGroup
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::NullableBetaAnalyticsActorConverter, emit_null: false)]
    getter actor : BetaAnalyticsActor? = nil

    @[JSON::Field(key: "actor_type", emit_null: false)]
    getter actor_type : String? = nil

    @[JSON::Field(key: "agent_id", emit_null: false)]
    getter agent_id : String? = nil

    @[JSON::Field(key: "api_key_id", emit_null: false)]
    getter api_key_id : String? = nil

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "deployment_id", emit_null: false)]
    getter deployment_id : String? = nil

    @[JSON::Field(key: "environment_id", emit_null: false)]
    getter environment_id : String? = nil

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(key: "organization_id", emit_null: false)]
    getter organization_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "service_tier", emit_null: false)]
    getter service_tier : String? = nil

    @[JSON::Field(key: "session_id", emit_null: false)]
    getter session_id : String? = nil

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "user_profile_id", emit_null: false)]
    getter user_profile_id : String? = nil

    @[JSON::Field(key: "workspace_id", emit_null: false)]
    getter workspace_id : String? = nil
  end

  struct BetaAnalyticsUsageMetrics
    include JSON::Serializable

    @[JSON::Field(key: "cache_creation")]
    getter cache_creation : AnalyticsCacheCreation

    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int64

    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int64

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?

    @[JSON::Field(key: "server_tool_use")]
    getter server_tool_use : BetaAnalyticsServerToolUse

    @[JSON::Field(key: "total_tokens")]
    getter total_tokens : Int64

    @[JSON::Field(key: "uncached_input_tokens")]
    getter uncached_input_tokens : Int64
  end

  struct BetaAnalyticsUsageItem
    include JSON::Serializable

    @[JSON::Field(key: "ending_at")]
    getter ending_at : String

    getter group : BetaAnalyticsUsageGroup

    @[JSON::Field(key: "starting_at")]
    getter starting_at : String

    getter usage : BetaAnalyticsUsageMetrics
  end

  struct BetaAnalyticsCostGroup
    include JSON::Serializable

    @[JSON::Field(converter: Anthropic::NullableBetaAnalyticsActorConverter, emit_null: false)]
    getter actor : BetaAnalyticsActor? = nil

    @[JSON::Field(key: "actor_type", emit_null: false)]
    getter actor_type : String? = nil

    @[JSON::Field(key: "agent_id", emit_null: false)]
    getter agent_id : String? = nil

    @[JSON::Field(key: "api_key_id", emit_null: false)]
    getter api_key_id : String? = nil

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "cost_type", emit_null: false)]
    getter cost_type : String? = nil

    @[JSON::Field(key: "deployment_id", emit_null: false)]
    getter deployment_id : String? = nil

    @[JSON::Field(key: "environment_id", emit_null: false)]
    getter environment_id : String? = nil

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(key: "organization_id", emit_null: false)]
    getter organization_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(key: "service_tier", emit_null: false)]
    getter service_tier : String? = nil

    @[JSON::Field(key: "session_id", emit_null: false)]
    getter session_id : String? = nil

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "token_type", emit_null: false)]
    getter token_type : String? = nil

    @[JSON::Field(key: "user_profile_id", emit_null: false)]
    getter user_profile_id : String? = nil

    @[JSON::Field(key: "workspace_id", emit_null: false)]
    getter workspace_id : String? = nil
  end

  struct BetaAnalyticsCostMetrics
    include JSON::Serializable

    getter amount : String
    getter currency : String

    @[JSON::Field(key: "list_amount")]
    getter list_amount : String

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?
  end

  struct BetaAnalyticsCostItem
    include JSON::Serializable

    getter cost : BetaAnalyticsCostMetrics

    @[JSON::Field(key: "ending_at")]
    getter ending_at : String

    getter group : BetaAnalyticsCostGroup

    @[JSON::Field(key: "starting_at")]
    getter starting_at : String
  end

  # Legacy usage_report / cost_report / user_usage_report / user_cost_report models

  struct BetaAnalyticsUsageBucketedResult
    include JSON::Serializable

    @[JSON::Field(key: "cache_creation")]
    getter cache_creation : AnalyticsCacheCreation

    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int64

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int64

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?

    @[JSON::Field(key: "server_tool_use")]
    getter server_tool_use : BetaAnalyticsServerToolUse

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "uncached_input_tokens")]
    getter uncached_input_tokens : Int64
  end

  struct BetaAnalyticsUsageReportTimeBucket
    include JSON::Serializable

    @[JSON::Field(key: "ending_at")]
    getter ending_at : String

    getter results : Array(BetaAnalyticsUsageBucketedResult)

    @[JSON::Field(key: "starting_at")]
    getter starting_at : String
  end

  struct BetaAnalyticsCostBucketedResult
    include JSON::Serializable

    getter amount : String

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "cost_type", emit_null: false)]
    getter cost_type : String? = nil

    getter currency : String

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(key: "list_amount")]
    getter list_amount : String

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "token_type", emit_null: false)]
    getter token_type : String? = nil
  end

  struct BetaAnalyticsCostReportTimeBucket
    include JSON::Serializable

    @[JSON::Field(key: "ending_at")]
    getter ending_at : String

    getter results : Array(BetaAnalyticsCostBucketedResult)

    @[JSON::Field(key: "starting_at")]
    getter starting_at : String
  end

  struct BetaAnalyticsUsageUsersItem
    include JSON::Serializable

    getter actor : BetaAnalyticsUserActor

    @[JSON::Field(key: "cache_creation")]
    getter cache_creation : AnalyticsCacheCreation

    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int64

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "ending_at", emit_null: false)]
    getter ending_at : String?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int64

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?

    @[JSON::Field(key: "server_tool_use")]
    getter server_tool_use : BetaAnalyticsServerToolUse

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "starting_at", emit_null: false)]
    getter starting_at : String?

    @[JSON::Field(key: "total_tokens")]
    getter total_tokens : Int64

    @[JSON::Field(key: "uncached_input_tokens")]
    getter uncached_input_tokens : Int64
  end

  struct BetaAnalyticsCostUsersItem
    include JSON::Serializable

    getter actor : BetaAnalyticsUserActor
    getter amount : String

    @[JSON::Field(key: "claude_tag_category", emit_null: false)]
    getter claude_tag_category : String? = nil

    @[JSON::Field(key: "claude_tag_user_id", emit_null: false)]
    getter claude_tag_user_id : String? = nil

    @[JSON::Field(key: "context_window", emit_null: false)]
    getter context_window : String? = nil

    @[JSON::Field(key: "cost_type", emit_null: false)]
    getter cost_type : String? = nil

    getter currency : String

    @[JSON::Field(key: "ending_at", emit_null: false)]
    getter ending_at : String?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String? = nil

    @[JSON::Field(key: "list_amount")]
    getter list_amount : String

    @[JSON::Field(emit_null: false)]
    getter model : String? = nil

    @[JSON::Field(emit_null: false)]
    getter product : String? = nil

    @[JSON::Field(key: "rbac_group_id", emit_null: false)]
    getter rbac_group_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter requests : Int64?

    @[JSON::Field(key: "slack_channel_id", emit_null: false)]
    getter slack_channel_id : String? = nil

    @[JSON::Field(emit_null: false)]
    getter speed : String? = nil

    @[JSON::Field(key: "starting_at", emit_null: false)]
    getter starting_at : String?

    @[JSON::Field(key: "token_type", emit_null: false)]
    getter token_type : String? = nil
  end
end
