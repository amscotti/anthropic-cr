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
      SESSION_UPDATED = "session.updated"
    end

    def agent_event? : Bool
      type.starts_with?("agent.")
    end

    def deployment_event? : Bool
      type.starts_with?("deployment.")
    end

    def deployment_run_event? : Bool
      type.starts_with?("deployment_run.")
    end

    def environment_event? : Bool
      type.starts_with?("environment.")
    end

    def memory_store_event? : Bool
      type.starts_with?("memory_store.")
    end

    def session_event? : Bool
      type.starts_with?("session.")
    end
  end

  alias UnwrapWebhookEvent = BetaWebhookEvent
end
