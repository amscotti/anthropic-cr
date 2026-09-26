module Anthropic
  struct BetaWebhookEvent
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter type : String = "event"
    getter data : JSON::Any

    # The set of webhook event types the API may deliver. The `data` payload is
    # kept as `JSON::Any` so all variants parse without per-type structs.
    module EventType
      # Agent lifecycle events.
      AGENT_CREATED  = "agent.created"
      AGENT_UPDATED  = "agent.updated"
      AGENT_ARCHIVED = "agent.archived"
      AGENT_DELETED  = "agent.deleted"

      # Deployment lifecycle events.
      DEPLOYMENT_CREATED  = "deployment.created"
      DEPLOYMENT_UPDATED  = "deployment.updated"
      DEPLOYMENT_ARCHIVED = "deployment.archived"
      DEPLOYMENT_DELETED  = "deployment.deleted"
      DEPLOYMENT_PAUSED   = "deployment.paused"
      DEPLOYMENT_UNPAUSED = "deployment.unpaused"

      # Deployment run lifecycle events.
      DEPLOYMENT_RUN_STARTED   = "deployment_run.started"
      DEPLOYMENT_RUN_SUCCEEDED = "deployment_run.succeeded"
      DEPLOYMENT_RUN_FAILED    = "deployment_run.failed"

      # Environment lifecycle events.
      ENVIRONMENT_CREATED  = "environment.created"
      ENVIRONMENT_UPDATED  = "environment.updated"
      ENVIRONMENT_ARCHIVED = "environment.archived"
      ENVIRONMENT_DELETED  = "environment.deleted"

      # Memory store lifecycle events.
      MEMORY_STORE_CREATED  = "memory_store.created"
      MEMORY_STORE_ARCHIVED = "memory_store.archived"
      MEMORY_STORE_DELETED  = "memory_store.deleted"

      # Session lifecycle events.
      SESSION_ARCHIVED                 = "session.archived"
      SESSION_BUDGET_REACHED           = "session.budget_reached"
      SESSION_CREATED                  = "session.created"
      SESSION_DELETED                  = "session.deleted"
      SESSION_IDLED                    = "session.idled"
      SESSION_OUTCOME_EVALUATION_ENDED = "session.outcome_evaluation_ended"
      SESSION_PENDING                  = "session.pending"
      SESSION_REQUIRES_ACTION          = "session.requires_action"
      SESSION_RUNNING                  = "session.running"
      SESSION_STATUS_IDLED             = "session.status_idled"
      SESSION_STATUS_RESCHEDULED       = "session.status_rescheduled"
      SESSION_STATUS_RUN_STARTED       = "session.status_run_started"
      SESSION_STATUS_TERMINATED        = "session.status_terminated"
      SESSION_THREAD_CREATED           = "session.thread_created"
      SESSION_THREAD_IDLED             = "session.thread_idled"
      SESSION_THREAD_TERMINATED        = "session.thread_terminated"
      SESSION_UPDATED                  = "session.updated"

      # Vault lifecycle events.
      VAULT_ARCHIVED = "vault.archived"
      VAULT_CREATED  = "vault.created"
      VAULT_DELETED  = "vault.deleted"

      # Vault credential lifecycle events.
      VAULT_CREDENTIAL_ARCHIVED       = "vault_credential.archived"
      VAULT_CREDENTIAL_CREATED        = "vault_credential.created"
      VAULT_CREDENTIAL_DELETED        = "vault_credential.deleted"
      VAULT_CREDENTIAL_REFRESH_FAILED = "vault_credential.refresh_failed"
    end

    # Delivery type, e.g. `"session.created"`. The API sends the envelope
    # `type` as `"event"` with the delivery type nested in `data`; a
    # top-level delivery type is still honored for tolerance.
    def event_type : String?
      data["type"]?.try(&.as_s?) || (type == "event" ? nil : type)
    end

    def agent_event? : Bool
      event_type.try(&.starts_with?("agent.")) || false
    end

    def deployment_event? : Bool
      event_type.try(&.starts_with?("deployment.")) || false
    end

    def deployment_run_event? : Bool
      event_type.try(&.starts_with?("deployment_run.")) || false
    end

    def environment_event? : Bool
      event_type.try(&.starts_with?("environment.")) || false
    end

    def memory_store_event? : Bool
      event_type.try(&.starts_with?("memory_store.")) || false
    end

    def session_event? : Bool
      event_type.try(&.starts_with?("session.")) || false
    end

    def vault_event? : Bool
      event_type.try { |delivery| delivery.starts_with?("vault.") || delivery.starts_with?("vault_credential.") } || false
    end
  end

  alias UnwrapWebhookEvent = BetaWebhookEvent
end
