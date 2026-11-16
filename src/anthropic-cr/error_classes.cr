module Anthropic
  # Unsupported feature names reported in `ThreadUnsupportedRequestErrorDetails#unsupported`.
  module ThreadUnsupportedFeatureName
    CACHE_CONTROL      = "cache_control"
    CONTEXT_MANAGEMENT = "context_management"
    FALLBACKS          = "fallbacks"
    HIPAA              = "hipaa"
    INFERENCE_HOOKS    = "inference_hooks"
    THINKING           = "thinking"

    ALL = [
      CACHE_CONTROL,
      CONTEXT_MANAGEMENT,
      FALLBACKS,
      HIPAA,
      INFERENCE_HOOKS,
      THINKING,
    ]
  end

  # Field names reported in `WorkspacePolicyViolationErrorDetails#field`.
  module WorkspacePolicyField
    EXTERNAL_KEY_ID = "external_key_id"

    ALL = [EXTERNAL_KEY_ID]
  end

  # A work item's lease as held by the server in `BetaHeartbeatPreconditionFailedErrorDetails`.
  struct BetaWorkLeaseState
    include JSON::Serializable

    # RFC 3339 timestamp of the stored heartbeat, or `nil` if there has been none.
    @[JSON::Field(key: "last_heartbeat")]
    getter last_heartbeat : String?

    # Always `false`: a refused heartbeat does not extend the lease.
    @[JSON::Field(key: "lease_extended")]
    getter? lease_extended : Bool

    def lease_extended : Bool
      @lease_extended
    end

    # Current state of the work item (`"queued"`, `"starting"`, `"active"`, `"stopping"`, `"stopped"`).
    getter state : String

    # TTL of the lease in seconds.
    @[JSON::Field(key: "ttl_seconds")]
    getter ttl_seconds : Int64

    def initialize(
      @last_heartbeat : String?,
      @lease_extended : Bool,
      @state : String,
      @ttl_seconds : Int64,
    )
    end

    def lease_extended? : Bool
      @lease_extended
    end
  end

  # Parameterized error details structs

  struct OrganizationOnHoldErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "organization_on_hold"

    @[JSON::Field(key: "appeal_url", emit_null: false)]
    getter appeal_url : String?

    def initialize(@appeal_url : String? = nil, @error_code : String = "organization_on_hold")
    end
  end

  struct ThreadUnsupportedRequestErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "thread_unsupported_request"

    @[JSON::Field(emit_null: false)]
    getter unsupported : Array(String)?

    def initialize(@unsupported : Array(String)? = nil, @error_code : String = "thread_unsupported_request")
    end
  end

  struct WorkspacePolicyViolationErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "workspace_policy_violation"

    getter field : String

    def initialize(@field : String, @error_code : String = "workspace_policy_violation")
    end
  end

  struct BetaHeartbeatPreconditionFailedErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "heartbeat_precondition_failed"

    @[JSON::Field(key: "current_state")]
    getter current_state : BetaWorkLeaseState

    def initialize(@current_state : BetaWorkLeaseState, @error_code : String = "heartbeat_precondition_failed")
    end
  end

  struct BetaSlackChannelSetUpEnvironmentNotFoundErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "slack_channel_set_up_environment_not_found"

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    def initialize(@slack_channel_id : String, @error_code : String = "slack_channel_set_up_environment_not_found")
    end
  end

  struct BetaSlackChannelSetUpSettingsConflictErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "slack_channel_set_up_settings_conflict"

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    def initialize(@slack_channel_id : String, @error_code : String = "slack_channel_set_up_settings_conflict")
    end
  end

  struct BetaSlackChannelSetUpSettingsRefusedErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "slack_channel_set_up_settings_refused"

    @[JSON::Field(key: "slack_channel_id")]
    getter slack_channel_id : String

    def initialize(@slack_channel_id : String, @error_code : String = "slack_channel_set_up_settings_refused")
    end
  end

  struct BetaPluginNameTakenErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "plugin_name_taken"

    @[JSON::Field(key: "plugin_id", emit_null: false)]
    getter plugin_id : String?

    def initialize(@plugin_id : String? = nil, @error_code : String = "plugin_name_taken")
    end
  end

  struct BetaRegistrationPendingErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "registration_pending"

    @[JSON::Field(key: "plugin_id")]
    getter plugin_id : String

    @[JSON::Field(key: "plugin_version_id")]
    getter plugin_version_id : String

    def initialize(
      @plugin_id : String,
      @plugin_version_id : String,
      @error_code : String = "registration_pending",
    )
    end
  end

  struct BetaScanFailedErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "scan_failed"

    @[JSON::Field(key: "plugin_version_id")]
    getter plugin_version_id : String

    def initialize(@plugin_version_id : String, @error_code : String = "scan_failed")
    end
  end

  struct BetaScanPendingErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "scan_pending"

    @[JSON::Field(key: "plugin_version_id")]
    getter plugin_version_id : String

    def initialize(@plugin_version_id : String, @error_code : String = "scan_pending")
    end
  end

  struct BetaSkillNameTakenErrorDetails
    include JSON::Serializable

    @[JSON::Field(key: "error_code")]
    getter error_code : String = "skill_name_taken"

    @[JSON::Field(key: "skill_name")]
    getter skill_name : String

    def initialize(@skill_name : String, @error_code : String = "skill_name_taken")
    end
  end

  private macro define_simple_error_details(name, code)
    struct {{name}}
      include JSON::Serializable

      @[JSON::Field(key: "error_code")]
      getter error_code : String = {{code}}

      def initialize(@error_code : String = {{code}})
      end
    end
  end

  # Simple (marker) error details structs (70)
  define_simple_error_details(ClaudeCodeKeyCreatorNotMemberErrorDetails, "claude_code_key_creator_not_member")
  define_simple_error_details(ClaudeCodeVersionTooOldErrorDetails, "claude_code_version_too_old")
  define_simple_error_details(CMEKKeyDisabledErrorDetails, "cmek_key_disabled")
  define_simple_error_details(CMEKKeyNetworkBlockedErrorDetails, "cmek_key_network_blocked")
  define_simple_error_details(OrganizationTypeNotSupportedErrorDetails, "organization_type_not_supported")
  define_simple_error_details(RequestBodyEncodingInvalidErrorDetails, "request_body_encoding_invalid")
  define_simple_error_details(RequestBodyEncodingUnsupportedErrorDetails, "request_body_encoding_unsupported")
  define_simple_error_details(AvailableToolsLimitExceededErrorDetails, "available_tools_limit_exceeded")
  define_simple_error_details(CompactionBlockAmbiguousErrorDetails, "compaction_block_ambiguous")
  define_simple_error_details(CompactionBlockMisplacedErrorDetails, "compaction_block_misplaced")
  define_simple_error_details(CompactionContentMismatchErrorDetails, "compaction_content_mismatch")
  define_simple_error_details(CompactionIncompleteTurnErrorDetails, "compaction_incomplete_turn")
  define_simple_error_details(CompactionNothingToSummarizeErrorDetails, "compaction_nothing_to_summarize")
  define_simple_error_details(CompactionSignatureInvalidErrorDetails, "compaction_signature_invalid")
  define_simple_error_details(CompactionTooManyToolReferencesErrorDetails, "compaction_too_many_tool_references")
  define_simple_error_details(CompactionToolChangesMismatchErrorDetails, "compaction_tool_changes_mismatch")
  define_simple_error_details(ThreadAlreadyContinuedErrorDetails, "thread_already_continued")
  define_simple_error_details(ThreadContinueInFlightErrorDetails, "thread_continue_in_flight")
  define_simple_error_details(ThreadFingerprintMismatchErrorDetails, "thread_fingerprint_mismatch")
  define_simple_error_details(ToolNameConflictErrorDetails, "tool_name_conflict")
  define_simple_error_details(ToolReferenceUnresolvedErrorDetails, "tool_reference_unresolved")
  define_simple_error_details(FileNotDownloadableErrorDetails, "file_not_downloadable")
  define_simple_error_details(StorageQuotaExceededErrorDetails, "storage_quota_exceeded")
  define_simple_error_details(UserProfileNotFoundErrorDetails, "user_profile_not_found")
  define_simple_error_details(OrgAPIKeyLimitExceededErrorDetails, "org_api_key_limit_exceeded")
  define_simple_error_details(WorkspaceAPIKeyLimitExceededErrorDetails, "workspace_api_key_limit_exceeded")
  define_simple_error_details(ExternalKeyInWorkspacePolicyErrorDetails, "external_key_in_workspace_policy")
  define_simple_error_details(ExternalKeyValidationFailedErrorDetails, "external_key_validation_failed")
  define_simple_error_details(ExternalKeyValidationTimedOutErrorDetails, "external_key_validation_timed_out")
  define_simple_error_details(AlreadyMemberErrorDetails, "already_member")
  define_simple_error_details(CannotInviteEmailsWithUnverifiedDomainsErrorDetails, "cannot_invite_emails_with_unverified_domains")
  define_simple_error_details(EmailDomainNotAllowedErrorDetails, "email_domain_not_allowed")
  define_simple_error_details(InviteAlreadyExistsErrorDetails, "invite_already_exists")
  define_simple_error_details(OrgMemberLimitExceededErrorDetails, "org_member_limit_exceeded")
  define_simple_error_details(RBACGroupGrantsOwnerAccessErrorDetails, "rbac_group_grants_owner_access")
  define_simple_error_details(RBACGroupOwnerAccessUnconfirmedErrorDetails, "rbac_group_owner_access_unconfirmed")
  define_simple_error_details(CannotRemoveLastMemberErrorDetails, "cannot_remove_last_member")
  define_simple_error_details(KeyProfileMismatchErrorDetails, "key_profile_mismatch")
  define_simple_error_details(WorkspaceMemberLimitExceededErrorDetails, "workspace_member_limit_exceeded")
  define_simple_error_details(BetaEnvironmentArchivedErrorDetails, "environment_archived")
  define_simple_error_details(BetaInvalidConfigTypeChangeErrorDetails, "invalid_config_type_change")
  define_simple_error_details(BetaInvalidMetadataErrorDetails, "invalid_metadata")
  define_simple_error_details(BetaOrganizationNotEnrolledInBetaErrorDetails, "organization_not_enrolled_in_beta")
  define_simple_error_details(BetaUnsupportedCharsetErrorDetails, "unsupported_charset")
  define_simple_error_details(BetaCannotSignOutPrimaryOwnerErrorDetails, "cannot_sign_out_primary_owner")
  define_simple_error_details(BetaCannotSignOutSelfErrorDetails, "cannot_sign_out_self")
  define_simple_error_details(SandboxEgressRestrictedErrorDetails, "sandbox_egress_restricted")
  define_simple_error_details(BetaEnvironmentCreateDisabledErrorDetails, "environment_create_disabled")
  define_simple_error_details(BetaEnvironmentUpdateDisabledErrorDetails, "environment_update_disabled")
  define_simple_error_details(BetaCannotSignOutManagedMemberErrorDetails, "cannot_sign_out_managed_member")
  define_simple_error_details(BetaCannotSignOutMembershipAdminErrorDetails, "cannot_sign_out_membership_admin")
  define_simple_error_details(BetaCannotSignOutOwnerErrorDetails, "cannot_sign_out_owner")
  define_simple_error_details(BetaCannotSignOutPrivilegedMemberErrorDetails, "cannot_sign_out_privileged_member")
  define_simple_error_details(BetaSpendLimitsAdminAPIWritesNotEnabledErrorDetails, "spend_limits_admin_api_writes_not_enabled")
  define_simple_error_details(BetaAPIKeyScopeMissingErrorDetails, "api_key_scope_missing")
  define_simple_error_details(BetaClaudeTagWritesNotEnabledErrorDetails, "claude_tag_writes_not_enabled")
  define_simple_error_details(BetaComplianceConfigurationRestrictedErrorDetails, "compliance_configuration_restricted")
  define_simple_error_details(BetaOrganizationLevelScopedAPIKeyRequiredErrorDetails, "organization_level_scoped_api_key_required")
  define_simple_error_details(ThreadNotFoundErrorDetails, "thread_not_found")
  define_simple_error_details(FileExpiredErrorDetails, "file_expired")
  define_simple_error_details(BetaEnvironmentNotFoundErrorDetails, "environment_not_found")
  define_simple_error_details(SkillReadBlockedUndecryptableErrorDetails, "skill_read_blocked_undecryptable")
  define_simple_error_details(ExternalKeyChangedErrorDetails, "external_key_changed")
  define_simple_error_details(ConcurrentMembershipChangeErrorDetails, "concurrent_membership_change")
  define_simple_error_details(RequestBodyTooLargeAfterDecodingErrorDetails, "request_body_too_large_after_decoding")
  define_simple_error_details(EnforcedSpendLimitReachedErrorDetails, "enforced_spend_limit_reached")
  define_simple_error_details(RampLimitExceededErrorDetails, "ramp_limit_exceeded")
  define_simple_error_details(CMEKContextUnavailableErrorDetails, "cmek_context_unavailable")
  define_simple_error_details(CMEKKeyUnreachableErrorDetails, "cmek_key_unreachable")
  define_simple_error_details(CompactionUnavailableErrorDetails, "compaction_unavailable")

  # Discriminated union of all structured `error.details` payloads.
  alias ErrorDetails = ClaudeCodeKeyCreatorNotMemberErrorDetails |
                       ClaudeCodeVersionTooOldErrorDetails |
                       CMEKKeyDisabledErrorDetails |
                       CMEKKeyNetworkBlockedErrorDetails |
                       OrganizationOnHoldErrorDetails |
                       OrganizationTypeNotSupportedErrorDetails |
                       RequestBodyEncodingInvalidErrorDetails |
                       RequestBodyEncodingUnsupportedErrorDetails |
                       AvailableToolsLimitExceededErrorDetails |
                       CompactionBlockAmbiguousErrorDetails |
                       CompactionBlockMisplacedErrorDetails |
                       CompactionContentMismatchErrorDetails |
                       CompactionIncompleteTurnErrorDetails |
                       CompactionNothingToSummarizeErrorDetails |
                       CompactionSignatureInvalidErrorDetails |
                       CompactionTooManyToolReferencesErrorDetails |
                       CompactionToolChangesMismatchErrorDetails |
                       ThreadAlreadyContinuedErrorDetails |
                       ThreadContinueInFlightErrorDetails |
                       ThreadFingerprintMismatchErrorDetails |
                       ThreadUnsupportedRequestErrorDetails |
                       ToolNameConflictErrorDetails |
                       ToolReferenceUnresolvedErrorDetails |
                       FileNotDownloadableErrorDetails |
                       StorageQuotaExceededErrorDetails |
                       UserProfileNotFoundErrorDetails |
                       OrgAPIKeyLimitExceededErrorDetails |
                       WorkspaceAPIKeyLimitExceededErrorDetails |
                       ExternalKeyInWorkspacePolicyErrorDetails |
                       ExternalKeyValidationFailedErrorDetails |
                       ExternalKeyValidationTimedOutErrorDetails |
                       AlreadyMemberErrorDetails |
                       CannotInviteEmailsWithUnverifiedDomainsErrorDetails |
                       EmailDomainNotAllowedErrorDetails |
                       InviteAlreadyExistsErrorDetails |
                       OrgMemberLimitExceededErrorDetails |
                       RBACGroupGrantsOwnerAccessErrorDetails |
                       RBACGroupOwnerAccessUnconfirmedErrorDetails |
                       CannotRemoveLastMemberErrorDetails |
                       KeyProfileMismatchErrorDetails |
                       WorkspaceMemberLimitExceededErrorDetails |
                       WorkspacePolicyViolationErrorDetails |
                       BetaEnvironmentArchivedErrorDetails |
                       BetaInvalidConfigTypeChangeErrorDetails |
                       BetaInvalidMetadataErrorDetails |
                       BetaOrganizationNotEnrolledInBetaErrorDetails |
                       BetaUnsupportedCharsetErrorDetails |
                       BetaCannotSignOutPrimaryOwnerErrorDetails |
                       BetaCannotSignOutSelfErrorDetails |
                       BetaScanFailedErrorDetails |
                       BetaSlackChannelSetUpSettingsRefusedErrorDetails |
                       SandboxEgressRestrictedErrorDetails |
                       BetaEnvironmentCreateDisabledErrorDetails |
                       BetaEnvironmentUpdateDisabledErrorDetails |
                       BetaCannotSignOutManagedMemberErrorDetails |
                       BetaCannotSignOutMembershipAdminErrorDetails |
                       BetaCannotSignOutOwnerErrorDetails |
                       BetaCannotSignOutPrivilegedMemberErrorDetails |
                       BetaSpendLimitsAdminAPIWritesNotEnabledErrorDetails |
                       BetaAPIKeyScopeMissingErrorDetails |
                       BetaClaudeTagWritesNotEnabledErrorDetails |
                       BetaComplianceConfigurationRestrictedErrorDetails |
                       BetaOrganizationLevelScopedAPIKeyRequiredErrorDetails |
                       ThreadNotFoundErrorDetails |
                       FileExpiredErrorDetails |
                       BetaEnvironmentNotFoundErrorDetails |
                       BetaSlackChannelSetUpEnvironmentNotFoundErrorDetails |
                       SkillReadBlockedUndecryptableErrorDetails |
                       ExternalKeyChangedErrorDetails |
                       ConcurrentMembershipChangeErrorDetails |
                       BetaPluginNameTakenErrorDetails |
                       BetaScanPendingErrorDetails |
                       BetaSkillNameTakenErrorDetails |
                       BetaSlackChannelSetUpSettingsConflictErrorDetails |
                       BetaHeartbeatPreconditionFailedErrorDetails |
                       RequestBodyTooLargeAfterDecodingErrorDetails |
                       EnforcedSpendLimitReachedErrorDetails |
                       RampLimitExceededErrorDetails |
                       CMEKContextUnavailableErrorDetails |
                       CMEKKeyUnreachableErrorDetails |
                       BetaRegistrationPendingErrorDetails |
                       CompactionUnavailableErrorDetails

  private macro define_code_error(name, parent, code, details_type)
    class {{name}} < {{parent}}
      ERROR_CODE = {{code}}

      def error_code : String?
        @error_code || ERROR_CODE
      end

      def typed_details : {{details_type}}?
        @details.as?({{details_type}})
      end
    end
  end

  # 400 BadRequestError subclasses (51)
  define_code_error(ClaudeCodeKeyCreatorNotMemberError, BadRequestError, "claude_code_key_creator_not_member", ClaudeCodeKeyCreatorNotMemberErrorDetails)
  define_code_error(ClaudeCodeVersionTooOldError, BadRequestError, "claude_code_version_too_old", ClaudeCodeVersionTooOldErrorDetails)
  define_code_error(CMEKKeyDisabledError, BadRequestError, "cmek_key_disabled", CMEKKeyDisabledErrorDetails)
  define_code_error(CMEKKeyNetworkBlockedError, BadRequestError, "cmek_key_network_blocked", CMEKKeyNetworkBlockedErrorDetails)
  define_code_error(OrganizationOnHoldError, BadRequestError, "organization_on_hold", OrganizationOnHoldErrorDetails)
  define_code_error(OrganizationTypeNotSupportedError, BadRequestError, "organization_type_not_supported", OrganizationTypeNotSupportedErrorDetails)
  define_code_error(RequestBodyEncodingInvalidError, BadRequestError, "request_body_encoding_invalid", RequestBodyEncodingInvalidErrorDetails)
  define_code_error(RequestBodyEncodingUnsupportedError, BadRequestError, "request_body_encoding_unsupported", RequestBodyEncodingUnsupportedErrorDetails)
  define_code_error(AvailableToolsLimitExceededError, BadRequestError, "available_tools_limit_exceeded", AvailableToolsLimitExceededErrorDetails)
  define_code_error(CompactionBlockAmbiguousError, BadRequestError, "compaction_block_ambiguous", CompactionBlockAmbiguousErrorDetails)
  define_code_error(CompactionBlockMisplacedError, BadRequestError, "compaction_block_misplaced", CompactionBlockMisplacedErrorDetails)
  define_code_error(CompactionContentMismatchError, BadRequestError, "compaction_content_mismatch", CompactionContentMismatchErrorDetails)
  define_code_error(CompactionIncompleteTurnError, BadRequestError, "compaction_incomplete_turn", CompactionIncompleteTurnErrorDetails)
  define_code_error(CompactionNothingToSummarizeError, BadRequestError, "compaction_nothing_to_summarize", CompactionNothingToSummarizeErrorDetails)
  define_code_error(CompactionSignatureInvalidError, BadRequestError, "compaction_signature_invalid", CompactionSignatureInvalidErrorDetails)
  define_code_error(CompactionTooManyToolReferencesError, BadRequestError, "compaction_too_many_tool_references", CompactionTooManyToolReferencesErrorDetails)
  define_code_error(CompactionToolChangesMismatchError, BadRequestError, "compaction_tool_changes_mismatch", CompactionToolChangesMismatchErrorDetails)
  define_code_error(ThreadAlreadyContinuedError, BadRequestError, "thread_already_continued", ThreadAlreadyContinuedErrorDetails)
  define_code_error(ThreadContinueInFlightError, BadRequestError, "thread_continue_in_flight", ThreadContinueInFlightErrorDetails)
  define_code_error(ThreadFingerprintMismatchError, BadRequestError, "thread_fingerprint_mismatch", ThreadFingerprintMismatchErrorDetails)
  define_code_error(ThreadUnsupportedRequestError, BadRequestError, "thread_unsupported_request", ThreadUnsupportedRequestErrorDetails)
  define_code_error(ToolNameConflictError, BadRequestError, "tool_name_conflict", ToolNameConflictErrorDetails)
  define_code_error(ToolReferenceUnresolvedError, BadRequestError, "tool_reference_unresolved", ToolReferenceUnresolvedErrorDetails)
  define_code_error(FileNotDownloadableError, BadRequestError, "file_not_downloadable", FileNotDownloadableErrorDetails)
  define_code_error(StorageQuotaExceededError, BadRequestError, "storage_quota_exceeded", StorageQuotaExceededErrorDetails)
  define_code_error(UserProfileNotFoundError, BadRequestError, "user_profile_not_found", UserProfileNotFoundErrorDetails)
  define_code_error(OrgAPIKeyLimitExceededError, BadRequestError, "org_api_key_limit_exceeded", OrgAPIKeyLimitExceededErrorDetails)
  define_code_error(WorkspaceAPIKeyLimitExceededError, BadRequestError, "workspace_api_key_limit_exceeded", WorkspaceAPIKeyLimitExceededErrorDetails)
  define_code_error(ExternalKeyInWorkspacePolicyError, BadRequestError, "external_key_in_workspace_policy", ExternalKeyInWorkspacePolicyErrorDetails)
  define_code_error(ExternalKeyValidationFailedError, BadRequestError, "external_key_validation_failed", ExternalKeyValidationFailedErrorDetails)
  define_code_error(ExternalKeyValidationTimedOutError, BadRequestError, "external_key_validation_timed_out", ExternalKeyValidationTimedOutErrorDetails)
  define_code_error(AlreadyMemberError, BadRequestError, "already_member", AlreadyMemberErrorDetails)
  define_code_error(CannotInviteEmailsWithUnverifiedDomainsError, BadRequestError, "cannot_invite_emails_with_unverified_domains", CannotInviteEmailsWithUnverifiedDomainsErrorDetails)
  define_code_error(EmailDomainNotAllowedError, BadRequestError, "email_domain_not_allowed", EmailDomainNotAllowedErrorDetails)
  define_code_error(InviteAlreadyExistsError, BadRequestError, "invite_already_exists", InviteAlreadyExistsErrorDetails)
  define_code_error(OrgMemberLimitExceededError, BadRequestError, "org_member_limit_exceeded", OrgMemberLimitExceededErrorDetails)
  define_code_error(RBACGroupGrantsOwnerAccessError, BadRequestError, "rbac_group_grants_owner_access", RBACGroupGrantsOwnerAccessErrorDetails)
  define_code_error(RBACGroupOwnerAccessUnconfirmedError, BadRequestError, "rbac_group_owner_access_unconfirmed", RBACGroupOwnerAccessUnconfirmedErrorDetails)
  define_code_error(CannotRemoveLastMemberError, BadRequestError, "cannot_remove_last_member", CannotRemoveLastMemberErrorDetails)
  define_code_error(KeyProfileMismatchError, BadRequestError, "key_profile_mismatch", KeyProfileMismatchErrorDetails)
  define_code_error(WorkspaceMemberLimitExceededError, BadRequestError, "workspace_member_limit_exceeded", WorkspaceMemberLimitExceededErrorDetails)
  define_code_error(WorkspacePolicyViolationError, BadRequestError, "workspace_policy_violation", WorkspacePolicyViolationErrorDetails)
  define_code_error(BetaEnvironmentArchivedError, BadRequestError, "environment_archived", BetaEnvironmentArchivedErrorDetails)
  define_code_error(BetaInvalidConfigTypeChangeError, BadRequestError, "invalid_config_type_change", BetaInvalidConfigTypeChangeErrorDetails)
  define_code_error(BetaInvalidMetadataError, BadRequestError, "invalid_metadata", BetaInvalidMetadataErrorDetails)
  define_code_error(BetaOrganizationNotEnrolledInBetaError, BadRequestError, "organization_not_enrolled_in_beta", BetaOrganizationNotEnrolledInBetaErrorDetails)
  define_code_error(BetaUnsupportedCharsetError, BadRequestError, "unsupported_charset", BetaUnsupportedCharsetErrorDetails)
  define_code_error(BetaCannotSignOutPrimaryOwnerError, BadRequestError, "cannot_sign_out_primary_owner", BetaCannotSignOutPrimaryOwnerErrorDetails)
  define_code_error(BetaCannotSignOutSelfError, BadRequestError, "cannot_sign_out_self", BetaCannotSignOutSelfErrorDetails)
  define_code_error(BetaScanFailedError, BadRequestError, "scan_failed", BetaScanFailedErrorDetails)
  define_code_error(BetaSlackChannelSetUpSettingsRefusedError, BadRequestError, "slack_channel_set_up_settings_refused", BetaSlackChannelSetUpSettingsRefusedErrorDetails)

  # 403 PermissionDeniedError subclasses (12)
  define_code_error(SandboxEgressRestrictedError, PermissionDeniedError, "sandbox_egress_restricted", SandboxEgressRestrictedErrorDetails)
  define_code_error(BetaEnvironmentCreateDisabledError, PermissionDeniedError, "environment_create_disabled", BetaEnvironmentCreateDisabledErrorDetails)
  define_code_error(BetaEnvironmentUpdateDisabledError, PermissionDeniedError, "environment_update_disabled", BetaEnvironmentUpdateDisabledErrorDetails)
  define_code_error(BetaCannotSignOutManagedMemberError, PermissionDeniedError, "cannot_sign_out_managed_member", BetaCannotSignOutManagedMemberErrorDetails)
  define_code_error(BetaCannotSignOutMembershipAdminError, PermissionDeniedError, "cannot_sign_out_membership_admin", BetaCannotSignOutMembershipAdminErrorDetails)
  define_code_error(BetaCannotSignOutOwnerError, PermissionDeniedError, "cannot_sign_out_owner", BetaCannotSignOutOwnerErrorDetails)
  define_code_error(BetaCannotSignOutPrivilegedMemberError, PermissionDeniedError, "cannot_sign_out_privileged_member", BetaCannotSignOutPrivilegedMemberErrorDetails)
  define_code_error(BetaSpendLimitsAdminAPIWritesNotEnabledError, PermissionDeniedError, "spend_limits_admin_api_writes_not_enabled", BetaSpendLimitsAdminAPIWritesNotEnabledErrorDetails)
  define_code_error(BetaAPIKeyScopeMissingError, PermissionDeniedError, "api_key_scope_missing", BetaAPIKeyScopeMissingErrorDetails)
  define_code_error(BetaClaudeTagWritesNotEnabledError, PermissionDeniedError, "claude_tag_writes_not_enabled", BetaClaudeTagWritesNotEnabledErrorDetails)
  define_code_error(BetaComplianceConfigurationRestrictedError, PermissionDeniedError, "compliance_configuration_restricted", BetaComplianceConfigurationRestrictedErrorDetails)
  define_code_error(BetaOrganizationLevelScopedAPIKeyRequiredError, PermissionDeniedError, "organization_level_scoped_api_key_required", BetaOrganizationLevelScopedAPIKeyRequiredErrorDetails)

  # 404 NotFoundError subclasses (4)
  define_code_error(ThreadNotFoundError, NotFoundError, "thread_not_found", ThreadNotFoundErrorDetails)
  define_code_error(FileExpiredError, NotFoundError, "file_expired", FileExpiredErrorDetails)
  define_code_error(BetaEnvironmentNotFoundError, NotFoundError, "environment_not_found", BetaEnvironmentNotFoundErrorDetails)
  define_code_error(BetaSlackChannelSetUpEnvironmentNotFoundError, NotFoundError, "slack_channel_set_up_environment_not_found", BetaSlackChannelSetUpEnvironmentNotFoundErrorDetails)

  # 409 ConflictError subclasses (7)
  define_code_error(SkillReadBlockedUndecryptableError, ConflictError, "skill_read_blocked_undecryptable", SkillReadBlockedUndecryptableErrorDetails)
  define_code_error(ExternalKeyChangedError, ConflictError, "external_key_changed", ExternalKeyChangedErrorDetails)
  define_code_error(ConcurrentMembershipChangeError, ConflictError, "concurrent_membership_change", ConcurrentMembershipChangeErrorDetails)
  define_code_error(BetaPluginNameTakenError, ConflictError, "plugin_name_taken", BetaPluginNameTakenErrorDetails)
  define_code_error(BetaScanPendingError, ConflictError, "scan_pending", BetaScanPendingErrorDetails)
  define_code_error(BetaSkillNameTakenError, ConflictError, "skill_name_taken", BetaSkillNameTakenErrorDetails)
  define_code_error(BetaSlackChannelSetUpSettingsConflictError, ConflictError, "slack_channel_set_up_settings_conflict", BetaSlackChannelSetUpSettingsConflictErrorDetails)

  # 412 PreconditionFailedError subclasses (1)
  define_code_error(BetaHeartbeatPreconditionFailedError, PreconditionFailedError, "heartbeat_precondition_failed", BetaHeartbeatPreconditionFailedErrorDetails)

  # 413 ContentTooLargeError subclasses (1)
  define_code_error(RequestBodyTooLargeAfterDecodingError, ContentTooLargeError, "request_body_too_large_after_decoding", RequestBodyTooLargeAfterDecodingErrorDetails)

  # 429 RateLimitError subclasses (2)
  define_code_error(EnforcedSpendLimitReachedError, RateLimitError, "enforced_spend_limit_reached", EnforcedSpendLimitReachedErrorDetails)
  define_code_error(RampLimitExceededError, RateLimitError, "ramp_limit_exceeded", RampLimitExceededErrorDetails)

  # 503 ServiceUnavailableError subclasses (3)
  define_code_error(CMEKContextUnavailableError, ServiceUnavailableError, "cmek_context_unavailable", CMEKContextUnavailableErrorDetails)
  define_code_error(CMEKKeyUnreachableError, ServiceUnavailableError, "cmek_key_unreachable", CMEKKeyUnreachableErrorDetails)
  define_code_error(BetaRegistrationPendingError, ServiceUnavailableError, "registration_pending", BetaRegistrationPendingErrorDetails)

  # 529 OverloadedError subclasses (1)
  define_code_error(CompactionUnavailableError, OverloadedError, "compaction_unavailable", CompactionUnavailableErrorDetails)

  private alias ErrorFactory = Proc(
    String,
    Int32?,
    String?,
    HTTP::Headers?,
    String?,
    Int32?,
    String?,
    String?,
    ErrorDetails | JSON::Any?,
    APIError,
  )

  private alias DetailsParser = Proc(String, ErrorDetails)

  private macro standard_error_factory(klass)
    ->(
      msg : String,
      st : Int32?,
      bd : String?,
      hdrs : HTTP::Headers?,
      err_type : String?,
      _retry_after : Int32?,
      api_msg : String?,
      err_code : String?,
      det : ErrorDetails | JSON::Any?,
    ) : APIError {
      {{klass}}.new(
        msg,
        status: st,
        body: bd,
        headers: hdrs,
        error_type: err_type,
        api_message: api_msg,
        error_code: err_code,
        details: det,
      )
    }
  end

  private macro rate_limit_error_factory(klass)
    ->(
      msg : String,
      st : Int32?,
      bd : String?,
      hdrs : HTTP::Headers?,
      err_type : String?,
      retry_after : Int32?,
      api_msg : String?,
      err_code : String?,
      det : ErrorDetails | JSON::Any?,
    ) : APIError {
      {{klass}}.new(
        msg,
        status: st,
        body: bd,
        headers: hdrs,
        error_type: err_type,
        retry_after: retry_after,
        api_message: api_msg,
        error_code: err_code,
        details: det,
      )
    }
  end

  # Public mapping from `{status_code, error_code}` to the target `APIError` subclass.
  ERROR_CLASSES = {
    {400, nil}                                            => BadRequestError,
    {400, "claude_code_key_creator_not_member"}           => ClaudeCodeKeyCreatorNotMemberError,
    {400, "claude_code_version_too_old"}                  => ClaudeCodeVersionTooOldError,
    {400, "cmek_key_disabled"}                            => CMEKKeyDisabledError,
    {400, "cmek_key_network_blocked"}                     => CMEKKeyNetworkBlockedError,
    {400, "organization_on_hold"}                         => OrganizationOnHoldError,
    {400, "organization_type_not_supported"}              => OrganizationTypeNotSupportedError,
    {400, "request_body_encoding_invalid"}                => RequestBodyEncodingInvalidError,
    {400, "request_body_encoding_unsupported"}            => RequestBodyEncodingUnsupportedError,
    {400, "available_tools_limit_exceeded"}               => AvailableToolsLimitExceededError,
    {400, "compaction_block_ambiguous"}                   => CompactionBlockAmbiguousError,
    {400, "compaction_block_misplaced"}                   => CompactionBlockMisplacedError,
    {400, "compaction_content_mismatch"}                  => CompactionContentMismatchError,
    {400, "compaction_incomplete_turn"}                   => CompactionIncompleteTurnError,
    {400, "compaction_nothing_to_summarize"}              => CompactionNothingToSummarizeError,
    {400, "compaction_signature_invalid"}                 => CompactionSignatureInvalidError,
    {400, "compaction_too_many_tool_references"}          => CompactionTooManyToolReferencesError,
    {400, "compaction_tool_changes_mismatch"}             => CompactionToolChangesMismatchError,
    {400, "thread_already_continued"}                     => ThreadAlreadyContinuedError,
    {400, "thread_continue_in_flight"}                    => ThreadContinueInFlightError,
    {400, "thread_fingerprint_mismatch"}                  => ThreadFingerprintMismatchError,
    {400, "thread_unsupported_request"}                   => ThreadUnsupportedRequestError,
    {400, "tool_name_conflict"}                           => ToolNameConflictError,
    {400, "tool_reference_unresolved"}                    => ToolReferenceUnresolvedError,
    {400, "file_not_downloadable"}                        => FileNotDownloadableError,
    {400, "storage_quota_exceeded"}                       => StorageQuotaExceededError,
    {400, "user_profile_not_found"}                       => UserProfileNotFoundError,
    {400, "org_api_key_limit_exceeded"}                   => OrgAPIKeyLimitExceededError,
    {400, "workspace_api_key_limit_exceeded"}             => WorkspaceAPIKeyLimitExceededError,
    {400, "external_key_in_workspace_policy"}             => ExternalKeyInWorkspacePolicyError,
    {400, "external_key_validation_failed"}               => ExternalKeyValidationFailedError,
    {400, "external_key_validation_timed_out"}            => ExternalKeyValidationTimedOutError,
    {400, "already_member"}                               => AlreadyMemberError,
    {400, "cannot_invite_emails_with_unverified_domains"} => CannotInviteEmailsWithUnverifiedDomainsError,
    {400, "email_domain_not_allowed"}                     => EmailDomainNotAllowedError,
    {400, "invite_already_exists"}                        => InviteAlreadyExistsError,
    {400, "org_member_limit_exceeded"}                    => OrgMemberLimitExceededError,
    {400, "rbac_group_grants_owner_access"}               => RBACGroupGrantsOwnerAccessError,
    {400, "rbac_group_owner_access_unconfirmed"}          => RBACGroupOwnerAccessUnconfirmedError,
    {400, "cannot_remove_last_member"}                    => CannotRemoveLastMemberError,
    {400, "key_profile_mismatch"}                         => KeyProfileMismatchError,
    {400, "workspace_member_limit_exceeded"}              => WorkspaceMemberLimitExceededError,
    {400, "workspace_policy_violation"}                   => WorkspacePolicyViolationError,
    {400, "environment_archived"}                         => BetaEnvironmentArchivedError,
    {400, "invalid_config_type_change"}                   => BetaInvalidConfigTypeChangeError,
    {400, "invalid_metadata"}                             => BetaInvalidMetadataError,
    {400, "organization_not_enrolled_in_beta"}            => BetaOrganizationNotEnrolledInBetaError,
    {400, "unsupported_charset"}                          => BetaUnsupportedCharsetError,
    {400, "cannot_sign_out_primary_owner"}                => BetaCannotSignOutPrimaryOwnerError,
    {400, "cannot_sign_out_self"}                         => BetaCannotSignOutSelfError,
    {400, "scan_failed"}                                  => BetaScanFailedError,
    {400, "slack_channel_set_up_settings_refused"}        => BetaSlackChannelSetUpSettingsRefusedError,
    {401, nil}                                            => AuthenticationError,
    {403, nil}                                            => PermissionDeniedError,
    {403, "sandbox_egress_restricted"}                    => SandboxEgressRestrictedError,
    {403, "environment_create_disabled"}                  => BetaEnvironmentCreateDisabledError,
    {403, "environment_update_disabled"}                  => BetaEnvironmentUpdateDisabledError,
    {403, "cannot_sign_out_managed_member"}               => BetaCannotSignOutManagedMemberError,
    {403, "cannot_sign_out_membership_admin"}             => BetaCannotSignOutMembershipAdminError,
    {403, "cannot_sign_out_owner"}                        => BetaCannotSignOutOwnerError,
    {403, "cannot_sign_out_privileged_member"}            => BetaCannotSignOutPrivilegedMemberError,
    {403, "spend_limits_admin_api_writes_not_enabled"}    => BetaSpendLimitsAdminAPIWritesNotEnabledError,
    {403, "api_key_scope_missing"}                        => BetaAPIKeyScopeMissingError,
    {403, "claude_tag_writes_not_enabled"}                => BetaClaudeTagWritesNotEnabledError,
    {403, "compliance_configuration_restricted"}          => BetaComplianceConfigurationRestrictedError,
    {403, "organization_level_scoped_api_key_required"}   => BetaOrganizationLevelScopedAPIKeyRequiredError,
    {404, nil}                                            => NotFoundError,
    {404, "thread_not_found"}                             => ThreadNotFoundError,
    {404, "file_expired"}                                 => FileExpiredError,
    {404, "environment_not_found"}                        => BetaEnvironmentNotFoundError,
    {404, "slack_channel_set_up_environment_not_found"}   => BetaSlackChannelSetUpEnvironmentNotFoundError,
    {408, nil}                                            => RequestTimeoutError,
    {409, nil}                                            => ConflictError,
    {409, "skill_read_blocked_undecryptable"}             => SkillReadBlockedUndecryptableError,
    {409, "external_key_changed"}                         => ExternalKeyChangedError,
    {409, "concurrent_membership_change"}                 => ConcurrentMembershipChangeError,
    {409, "plugin_name_taken"}                            => BetaPluginNameTakenError,
    {409, "scan_pending"}                                 => BetaScanPendingError,
    {409, "skill_name_taken"}                             => BetaSkillNameTakenError,
    {409, "slack_channel_set_up_settings_conflict"}       => BetaSlackChannelSetUpSettingsConflictError,
    {412, nil}                                            => PreconditionFailedError,
    {412, "heartbeat_precondition_failed"}                => BetaHeartbeatPreconditionFailedError,
    {413, nil}                                            => ContentTooLargeError,
    {413, "request_body_too_large_after_decoding"}        => RequestBodyTooLargeAfterDecodingError,
    {422, nil}                                            => UnprocessableEntityError,
    {429, nil}                                            => RateLimitError,
    {429, "enforced_spend_limit_reached"}                 => EnforcedSpendLimitReachedError,
    {429, "ramp_limit_exceeded"}                          => RampLimitExceededError,
    {431, nil}                                            => RequestHeaderFieldsTooLargeError,
    {499, nil}                                            => ClientClosedRequestError,
    {501, nil}                                            => HTTPNotImplementedError,
    {503, nil}                                            => ServiceUnavailableError,
    {503, "cmek_context_unavailable"}                     => CMEKContextUnavailableError,
    {503, "cmek_key_unreachable"}                         => CMEKKeyUnreachableError,
    {503, "registration_pending"}                         => BetaRegistrationPendingError,
    {504, nil}                                            => GatewayTimeoutError,
    {529, nil}                                            => OverloadedError,
    {529, "compaction_unavailable"}                       => CompactionUnavailableError,
  } of Tuple(Int32, String?) => APIError.class

  private ERROR_FACTORIES = {
    {400, nil}                                            => standard_error_factory(BadRequestError),
    {400, "claude_code_key_creator_not_member"}           => standard_error_factory(ClaudeCodeKeyCreatorNotMemberError),
    {400, "claude_code_version_too_old"}                  => standard_error_factory(ClaudeCodeVersionTooOldError),
    {400, "cmek_key_disabled"}                            => standard_error_factory(CMEKKeyDisabledError),
    {400, "cmek_key_network_blocked"}                     => standard_error_factory(CMEKKeyNetworkBlockedError),
    {400, "organization_on_hold"}                         => standard_error_factory(OrganizationOnHoldError),
    {400, "organization_type_not_supported"}              => standard_error_factory(OrganizationTypeNotSupportedError),
    {400, "request_body_encoding_invalid"}                => standard_error_factory(RequestBodyEncodingInvalidError),
    {400, "request_body_encoding_unsupported"}            => standard_error_factory(RequestBodyEncodingUnsupportedError),
    {400, "available_tools_limit_exceeded"}               => standard_error_factory(AvailableToolsLimitExceededError),
    {400, "compaction_block_ambiguous"}                   => standard_error_factory(CompactionBlockAmbiguousError),
    {400, "compaction_block_misplaced"}                   => standard_error_factory(CompactionBlockMisplacedError),
    {400, "compaction_content_mismatch"}                  => standard_error_factory(CompactionContentMismatchError),
    {400, "compaction_incomplete_turn"}                   => standard_error_factory(CompactionIncompleteTurnError),
    {400, "compaction_nothing_to_summarize"}              => standard_error_factory(CompactionNothingToSummarizeError),
    {400, "compaction_signature_invalid"}                 => standard_error_factory(CompactionSignatureInvalidError),
    {400, "compaction_too_many_tool_references"}          => standard_error_factory(CompactionTooManyToolReferencesError),
    {400, "compaction_tool_changes_mismatch"}             => standard_error_factory(CompactionToolChangesMismatchError),
    {400, "thread_already_continued"}                     => standard_error_factory(ThreadAlreadyContinuedError),
    {400, "thread_continue_in_flight"}                    => standard_error_factory(ThreadContinueInFlightError),
    {400, "thread_fingerprint_mismatch"}                  => standard_error_factory(ThreadFingerprintMismatchError),
    {400, "thread_unsupported_request"}                   => standard_error_factory(ThreadUnsupportedRequestError),
    {400, "tool_name_conflict"}                           => standard_error_factory(ToolNameConflictError),
    {400, "tool_reference_unresolved"}                    => standard_error_factory(ToolReferenceUnresolvedError),
    {400, "file_not_downloadable"}                        => standard_error_factory(FileNotDownloadableError),
    {400, "storage_quota_exceeded"}                       => standard_error_factory(StorageQuotaExceededError),
    {400, "user_profile_not_found"}                       => standard_error_factory(UserProfileNotFoundError),
    {400, "org_api_key_limit_exceeded"}                   => standard_error_factory(OrgAPIKeyLimitExceededError),
    {400, "workspace_api_key_limit_exceeded"}             => standard_error_factory(WorkspaceAPIKeyLimitExceededError),
    {400, "external_key_in_workspace_policy"}             => standard_error_factory(ExternalKeyInWorkspacePolicyError),
    {400, "external_key_validation_failed"}               => standard_error_factory(ExternalKeyValidationFailedError),
    {400, "external_key_validation_timed_out"}            => standard_error_factory(ExternalKeyValidationTimedOutError),
    {400, "already_member"}                               => standard_error_factory(AlreadyMemberError),
    {400, "cannot_invite_emails_with_unverified_domains"} => standard_error_factory(CannotInviteEmailsWithUnverifiedDomainsError),
    {400, "email_domain_not_allowed"}                     => standard_error_factory(EmailDomainNotAllowedError),
    {400, "invite_already_exists"}                        => standard_error_factory(InviteAlreadyExistsError),
    {400, "org_member_limit_exceeded"}                    => standard_error_factory(OrgMemberLimitExceededError),
    {400, "rbac_group_grants_owner_access"}               => standard_error_factory(RBACGroupGrantsOwnerAccessError),
    {400, "rbac_group_owner_access_unconfirmed"}          => standard_error_factory(RBACGroupOwnerAccessUnconfirmedError),
    {400, "cannot_remove_last_member"}                    => standard_error_factory(CannotRemoveLastMemberError),
    {400, "key_profile_mismatch"}                         => standard_error_factory(KeyProfileMismatchError),
    {400, "workspace_member_limit_exceeded"}              => standard_error_factory(WorkspaceMemberLimitExceededError),
    {400, "workspace_policy_violation"}                   => standard_error_factory(WorkspacePolicyViolationError),
    {400, "environment_archived"}                         => standard_error_factory(BetaEnvironmentArchivedError),
    {400, "invalid_config_type_change"}                   => standard_error_factory(BetaInvalidConfigTypeChangeError),
    {400, "invalid_metadata"}                             => standard_error_factory(BetaInvalidMetadataError),
    {400, "organization_not_enrolled_in_beta"}            => standard_error_factory(BetaOrganizationNotEnrolledInBetaError),
    {400, "unsupported_charset"}                          => standard_error_factory(BetaUnsupportedCharsetError),
    {400, "cannot_sign_out_primary_owner"}                => standard_error_factory(BetaCannotSignOutPrimaryOwnerError),
    {400, "cannot_sign_out_self"}                         => standard_error_factory(BetaCannotSignOutSelfError),
    {400, "scan_failed"}                                  => standard_error_factory(BetaScanFailedError),
    {400, "slack_channel_set_up_settings_refused"}        => standard_error_factory(BetaSlackChannelSetUpSettingsRefusedError),
    {401, nil}                                            => standard_error_factory(AuthenticationError),
    {403, nil}                                            => standard_error_factory(PermissionDeniedError),
    {403, "sandbox_egress_restricted"}                    => standard_error_factory(SandboxEgressRestrictedError),
    {403, "environment_create_disabled"}                  => standard_error_factory(BetaEnvironmentCreateDisabledError),
    {403, "environment_update_disabled"}                  => standard_error_factory(BetaEnvironmentUpdateDisabledError),
    {403, "cannot_sign_out_managed_member"}               => standard_error_factory(BetaCannotSignOutManagedMemberError),
    {403, "cannot_sign_out_membership_admin"}             => standard_error_factory(BetaCannotSignOutMembershipAdminError),
    {403, "cannot_sign_out_owner"}                        => standard_error_factory(BetaCannotSignOutOwnerError),
    {403, "cannot_sign_out_privileged_member"}            => standard_error_factory(BetaCannotSignOutPrivilegedMemberError),
    {403, "spend_limits_admin_api_writes_not_enabled"}    => standard_error_factory(BetaSpendLimitsAdminAPIWritesNotEnabledError),
    {403, "api_key_scope_missing"}                        => standard_error_factory(BetaAPIKeyScopeMissingError),
    {403, "claude_tag_writes_not_enabled"}                => standard_error_factory(BetaClaudeTagWritesNotEnabledError),
    {403, "compliance_configuration_restricted"}          => standard_error_factory(BetaComplianceConfigurationRestrictedError),
    {403, "organization_level_scoped_api_key_required"}   => standard_error_factory(BetaOrganizationLevelScopedAPIKeyRequiredError),
    {404, nil}                                            => standard_error_factory(NotFoundError),
    {404, "thread_not_found"}                             => standard_error_factory(ThreadNotFoundError),
    {404, "file_expired"}                                 => standard_error_factory(FileExpiredError),
    {404, "environment_not_found"}                        => standard_error_factory(BetaEnvironmentNotFoundError),
    {404, "slack_channel_set_up_environment_not_found"}   => standard_error_factory(BetaSlackChannelSetUpEnvironmentNotFoundError),
    {408, nil}                                            => standard_error_factory(RequestTimeoutError),
    {409, nil}                                            => standard_error_factory(ConflictError),
    {409, "skill_read_blocked_undecryptable"}             => standard_error_factory(SkillReadBlockedUndecryptableError),
    {409, "external_key_changed"}                         => standard_error_factory(ExternalKeyChangedError),
    {409, "concurrent_membership_change"}                 => standard_error_factory(ConcurrentMembershipChangeError),
    {409, "plugin_name_taken"}                            => standard_error_factory(BetaPluginNameTakenError),
    {409, "scan_pending"}                                 => standard_error_factory(BetaScanPendingError),
    {409, "skill_name_taken"}                             => standard_error_factory(BetaSkillNameTakenError),
    {409, "slack_channel_set_up_settings_conflict"}       => standard_error_factory(BetaSlackChannelSetUpSettingsConflictError),
    {412, nil}                                            => standard_error_factory(PreconditionFailedError),
    {412, "heartbeat_precondition_failed"}                => standard_error_factory(BetaHeartbeatPreconditionFailedError),
    {413, nil}                                            => standard_error_factory(ContentTooLargeError),
    {413, "request_body_too_large_after_decoding"}        => standard_error_factory(RequestBodyTooLargeAfterDecodingError),
    {422, nil}                                            => standard_error_factory(UnprocessableEntityError),
    {429, nil}                                            => rate_limit_error_factory(RateLimitError),
    {429, "enforced_spend_limit_reached"}                 => rate_limit_error_factory(EnforcedSpendLimitReachedError),
    {429, "ramp_limit_exceeded"}                          => rate_limit_error_factory(RampLimitExceededError),
    {431, nil}                                            => standard_error_factory(RequestHeaderFieldsTooLargeError),
    {499, nil}                                            => standard_error_factory(ClientClosedRequestError),
    {501, nil}                                            => standard_error_factory(HTTPNotImplementedError),
    {503, nil}                                            => standard_error_factory(ServiceUnavailableError),
    {503, "cmek_context_unavailable"}                     => standard_error_factory(CMEKContextUnavailableError),
    {503, "cmek_key_unreachable"}                         => standard_error_factory(CMEKKeyUnreachableError),
    {503, "registration_pending"}                         => standard_error_factory(BetaRegistrationPendingError),
    {504, nil}                                            => standard_error_factory(GatewayTimeoutError),
    {529, nil}                                            => standard_error_factory(OverloadedError),
    {529, "compaction_unavailable"}                       => standard_error_factory(CompactionUnavailableError),
  } of Tuple(Int32, String?) => ErrorFactory

  private macro details_parser(klass)
    ->(json : String) : ErrorDetails { {{klass}}.from_json(json).as(ErrorDetails) }
  end

  private ERROR_DETAILS_PARSERS = {
    "claude_code_key_creator_not_member"           => details_parser(ClaudeCodeKeyCreatorNotMemberErrorDetails),
    "claude_code_version_too_old"                  => details_parser(ClaudeCodeVersionTooOldErrorDetails),
    "cmek_key_disabled"                            => details_parser(CMEKKeyDisabledErrorDetails),
    "cmek_key_network_blocked"                     => details_parser(CMEKKeyNetworkBlockedErrorDetails),
    "organization_on_hold"                         => details_parser(OrganizationOnHoldErrorDetails),
    "organization_type_not_supported"              => details_parser(OrganizationTypeNotSupportedErrorDetails),
    "request_body_encoding_invalid"                => details_parser(RequestBodyEncodingInvalidErrorDetails),
    "request_body_encoding_unsupported"            => details_parser(RequestBodyEncodingUnsupportedErrorDetails),
    "available_tools_limit_exceeded"               => details_parser(AvailableToolsLimitExceededErrorDetails),
    "compaction_block_ambiguous"                   => details_parser(CompactionBlockAmbiguousErrorDetails),
    "compaction_block_misplaced"                   => details_parser(CompactionBlockMisplacedErrorDetails),
    "compaction_content_mismatch"                  => details_parser(CompactionContentMismatchErrorDetails),
    "compaction_incomplete_turn"                   => details_parser(CompactionIncompleteTurnErrorDetails),
    "compaction_nothing_to_summarize"              => details_parser(CompactionNothingToSummarizeErrorDetails),
    "compaction_signature_invalid"                 => details_parser(CompactionSignatureInvalidErrorDetails),
    "compaction_too_many_tool_references"          => details_parser(CompactionTooManyToolReferencesErrorDetails),
    "compaction_tool_changes_mismatch"             => details_parser(CompactionToolChangesMismatchErrorDetails),
    "thread_already_continued"                     => details_parser(ThreadAlreadyContinuedErrorDetails),
    "thread_continue_in_flight"                    => details_parser(ThreadContinueInFlightErrorDetails),
    "thread_fingerprint_mismatch"                  => details_parser(ThreadFingerprintMismatchErrorDetails),
    "thread_unsupported_request"                   => details_parser(ThreadUnsupportedRequestErrorDetails),
    "tool_name_conflict"                           => details_parser(ToolNameConflictErrorDetails),
    "tool_reference_unresolved"                    => details_parser(ToolReferenceUnresolvedErrorDetails),
    "file_not_downloadable"                        => details_parser(FileNotDownloadableErrorDetails),
    "storage_quota_exceeded"                       => details_parser(StorageQuotaExceededErrorDetails),
    "user_profile_not_found"                       => details_parser(UserProfileNotFoundErrorDetails),
    "org_api_key_limit_exceeded"                   => details_parser(OrgAPIKeyLimitExceededErrorDetails),
    "workspace_api_key_limit_exceeded"             => details_parser(WorkspaceAPIKeyLimitExceededErrorDetails),
    "external_key_in_workspace_policy"             => details_parser(ExternalKeyInWorkspacePolicyErrorDetails),
    "external_key_validation_failed"               => details_parser(ExternalKeyValidationFailedErrorDetails),
    "external_key_validation_timed_out"            => details_parser(ExternalKeyValidationTimedOutErrorDetails),
    "already_member"                               => details_parser(AlreadyMemberErrorDetails),
    "cannot_invite_emails_with_unverified_domains" => details_parser(CannotInviteEmailsWithUnverifiedDomainsErrorDetails),
    "email_domain_not_allowed"                     => details_parser(EmailDomainNotAllowedErrorDetails),
    "invite_already_exists"                        => details_parser(InviteAlreadyExistsErrorDetails),
    "org_member_limit_exceeded"                    => details_parser(OrgMemberLimitExceededErrorDetails),
    "rbac_group_grants_owner_access"               => details_parser(RBACGroupGrantsOwnerAccessErrorDetails),
    "rbac_group_owner_access_unconfirmed"          => details_parser(RBACGroupOwnerAccessUnconfirmedErrorDetails),
    "cannot_remove_last_member"                    => details_parser(CannotRemoveLastMemberErrorDetails),
    "key_profile_mismatch"                         => details_parser(KeyProfileMismatchErrorDetails),
    "workspace_member_limit_exceeded"              => details_parser(WorkspaceMemberLimitExceededErrorDetails),
    "workspace_policy_violation"                   => details_parser(WorkspacePolicyViolationErrorDetails),
    "environment_archived"                         => details_parser(BetaEnvironmentArchivedErrorDetails),
    "invalid_config_type_change"                   => details_parser(BetaInvalidConfigTypeChangeErrorDetails),
    "invalid_metadata"                             => details_parser(BetaInvalidMetadataErrorDetails),
    "organization_not_enrolled_in_beta"            => details_parser(BetaOrganizationNotEnrolledInBetaErrorDetails),
    "unsupported_charset"                          => details_parser(BetaUnsupportedCharsetErrorDetails),
    "cannot_sign_out_primary_owner"                => details_parser(BetaCannotSignOutPrimaryOwnerErrorDetails),
    "cannot_sign_out_self"                         => details_parser(BetaCannotSignOutSelfErrorDetails),
    "scan_failed"                                  => details_parser(BetaScanFailedErrorDetails),
    "slack_channel_set_up_settings_refused"        => details_parser(BetaSlackChannelSetUpSettingsRefusedErrorDetails),
    "sandbox_egress_restricted"                    => details_parser(SandboxEgressRestrictedErrorDetails),
    "environment_create_disabled"                  => details_parser(BetaEnvironmentCreateDisabledErrorDetails),
    "environment_update_disabled"                  => details_parser(BetaEnvironmentUpdateDisabledErrorDetails),
    "cannot_sign_out_managed_member"               => details_parser(BetaCannotSignOutManagedMemberErrorDetails),
    "cannot_sign_out_membership_admin"             => details_parser(BetaCannotSignOutMembershipAdminErrorDetails),
    "cannot_sign_out_owner"                        => details_parser(BetaCannotSignOutOwnerErrorDetails),
    "cannot_sign_out_privileged_member"            => details_parser(BetaCannotSignOutPrivilegedMemberErrorDetails),
    "spend_limits_admin_api_writes_not_enabled"    => details_parser(BetaSpendLimitsAdminAPIWritesNotEnabledErrorDetails),
    "api_key_scope_missing"                        => details_parser(BetaAPIKeyScopeMissingErrorDetails),
    "claude_tag_writes_not_enabled"                => details_parser(BetaClaudeTagWritesNotEnabledErrorDetails),
    "compliance_configuration_restricted"          => details_parser(BetaComplianceConfigurationRestrictedErrorDetails),
    "organization_level_scoped_api_key_required"   => details_parser(BetaOrganizationLevelScopedAPIKeyRequiredErrorDetails),
    "thread_not_found"                             => details_parser(ThreadNotFoundErrorDetails),
    "file_expired"                                 => details_parser(FileExpiredErrorDetails),
    "environment_not_found"                        => details_parser(BetaEnvironmentNotFoundErrorDetails),
    "slack_channel_set_up_environment_not_found"   => details_parser(BetaSlackChannelSetUpEnvironmentNotFoundErrorDetails),
    "skill_read_blocked_undecryptable"             => details_parser(SkillReadBlockedUndecryptableErrorDetails),
    "external_key_changed"                         => details_parser(ExternalKeyChangedErrorDetails),
    "concurrent_membership_change"                 => details_parser(ConcurrentMembershipChangeErrorDetails),
    "plugin_name_taken"                            => details_parser(BetaPluginNameTakenErrorDetails),
    "scan_pending"                                 => details_parser(BetaScanPendingErrorDetails),
    "skill_name_taken"                             => details_parser(BetaSkillNameTakenErrorDetails),
    "slack_channel_set_up_settings_conflict"       => details_parser(BetaSlackChannelSetUpSettingsConflictErrorDetails),
    "heartbeat_precondition_failed"                => details_parser(BetaHeartbeatPreconditionFailedErrorDetails),
    "request_body_too_large_after_decoding"        => details_parser(RequestBodyTooLargeAfterDecodingErrorDetails),
    "enforced_spend_limit_reached"                 => details_parser(EnforcedSpendLimitReachedErrorDetails),
    "ramp_limit_exceeded"                          => details_parser(RampLimitExceededErrorDetails),
    "cmek_context_unavailable"                     => details_parser(CMEKContextUnavailableErrorDetails),
    "cmek_key_unreachable"                         => details_parser(CMEKKeyUnreachableErrorDetails),
    "registration_pending"                         => details_parser(BetaRegistrationPendingErrorDetails),
    "compaction_unavailable"                       => details_parser(CompactionUnavailableErrorDetails),
  } of String => DetailsParser

  private STREAM_TYPE_TO_STATUS = {
    "invalid_request_error"            => 400,
    "authentication_error"             => 401,
    "permission_error"                 => 403,
    "billing_error"                    => 403,
    "not_found_error"                  => 404,
    "conflict_error"                   => 409,
    "memory_path_conflict_error"       => 409,
    "memory_precondition_failed_error" => 412,
    "request_too_large"                => 413,
    "rate_limit_error"                 => 429,
    "timeout_error"                    => 504,
    "gateway_timeout_error"            => 504,
    "overloaded_error"                 => 529,
    "api_error"                        => 500,
  }

  # Construct the most specific `APIError` subclass for an HTTP error response.
  # Safely guards non-object `body["error"]` values and unknown `error_code` / `details`.
  def self.build_api_error(
    status : Int32,
    body : String,
    headers : HTTP::Headers? = nil,
    message : String? = nil,
  ) : APIError
    api_message, error_type, error_code, details = extract_error_fields(body)
    resolved_message = message || api_message || body
    retry_after = headers.try(&.[]?("retry-after")).try(&.to_i?)

    factory = ERROR_FACTORIES[{status, error_code}]? || ERROR_FACTORIES[{status, nil}]?
    if factory
      return factory.call(
        resolved_message,
        status,
        body,
        headers,
        error_type,
        retry_after,
        api_message,
        error_code,
        details,
      )
    end

    if status >= 500
      InternalServerError.new(
        resolved_message,
        status: status,
        body: body,
        headers: headers,
        error_type: error_type,
        api_message: api_message,
        error_code: error_code,
        details: details,
      )
    else
      APIError.new(
        resolved_message,
        status: status,
        body: body,
        headers: headers,
        error_type: error_type,
        api_message: api_message,
        error_code: error_code,
        details: details,
      )
    end
  end

  # Construct an `APIError` from an SSE `error` event without fabricating an HTTP status.
  def self.build_stream_api_error(
    error_type : String?,
    api_message : String?,
    details_any : JSON::Any? = nil,
  ) : APIError
    error_code = details_any.try(&.as_h?).try(&.[]?("error_code")).try(&.as_s?)
    parsed_details = parse_error_details(error_code, details_any)
    implied_status = error_type ? STREAM_TYPE_TO_STATUS[error_type]? : nil
    msg = api_message || ""

    if implied_status
      factory = ERROR_FACTORIES[{implied_status, error_code}]? || ERROR_FACTORIES[{implied_status, nil}]?
      if factory
        return factory.call(
          msg,
          nil,
          nil,
          nil,
          error_type,
          nil,
          api_message,
          error_code,
          parsed_details,
        )
      end

      if implied_status >= 500
        return InternalServerError.new(
          msg,
          error_type: error_type,
          api_message: api_message,
          error_code: error_code,
          details: parsed_details,
        )
      end
    end

    APIError.new(
      msg,
      error_type: error_type,
      api_message: api_message,
      error_code: error_code,
      details: parsed_details,
    )
  end

  private def self.extract_error_fields(
    body : String,
  ) : {String?, String?, String?, ErrorDetails | JSON::Any?}
    return {nil, nil, nil, nil} if body.empty?

    parsed = begin
      JSON.parse(body)
    rescue JSON::ParseException
      return {nil, nil, nil, nil}
    end

    root_obj = parsed.as_h?
    return {nil, nil, nil, nil} unless root_obj

    error_obj = root_obj["error"]?.try(&.as_h?)
    return {nil, nil, nil, nil} unless error_obj

    api_message = error_obj["message"]?.try(&.as_s?)
    error_type = error_obj["type"]?.try(&.as_s?)
    details_any = error_obj["details"]?
    error_code = details_any.try(&.as_h?).try(&.[]?("error_code")).try(&.as_s?)
    details = parse_error_details(error_code, details_any)

    {api_message, error_type, error_code, details}
  end

  private def self.parse_error_details(
    error_code : String?,
    details_any : JSON::Any?,
  ) : ErrorDetails | JSON::Any?
    return nil if details_any.nil? || details_any.raw.nil?

    if error_code && (parser = ERROR_DETAILS_PARSERS[error_code]?)
      begin
        return parser.call(details_any.to_json)
      rescue JSON::ParseException
        return details_any
      end
    end

    details_any
  end
end
