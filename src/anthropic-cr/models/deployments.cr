module Anthropic
  # A Managed Agents deployment.
  #
  # A deployment pins an agent + environment + schedule so sessions can be
  # created on a cron or on demand. Returned by `client.beta.deployments.*`.
  struct BetaManagedAgentsDeployment
    include JSON::Serializable

    getter id : String

    # Agent reference (id string or `{id, version}` object).
    getter agent : JSON::Any

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(emit_null: false)]
    getter description : String?

    @[JSON::Field(key: "environment_id")]
    getter environment_id : String

    # Initial events sent to each session on creation.
    @[JSON::Field(key: "initial_events")]
    getter initial_events : Array(JSON::Any)

    @[JSON::Field(emit_null: false)]
    getter metadata : Hash(String, String)?

    getter name : String

    # Why the deployment is paused (only present when status == "paused").
    @[JSON::Field(key: "paused_reason", emit_null: false)]
    getter paused_reason : JSON::Any?

    # Resources (repositories, files, memory stores) mounted into sessions.
    @[JSON::Field(emit_null: false)]
    getter resources : Array(JSON::Any)?

    @[JSON::Field(emit_null: false)]
    getter schedule : JSON::Any?

    # "active" or "paused".
    getter status : String

    getter type : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "vault_ids")]
    getter vault_ids : Array(String)

    def active? : Bool
      status == "active"
    end

    def paused? : Bool
      status == "paused"
    end
  end

  # A single run of a Managed Agents deployment.
  struct BetaManagedAgentsDeploymentRun
    include JSON::Serializable

    getter id : String

    getter agent : JSON::Any

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "deployment_id")]
    getter deployment_id : String

    # Present only when the run failed (discriminated union of run-error types).
    @[JSON::Field(emit_null: false)]
    getter error : JSON::Any?

    # Populated on success; exactly one of `session_id`/`error` is non-null.
    @[JSON::Field(key: "session_id", emit_null: false)]
    getter session_id : String?

    @[JSON::Field(key: "trigger_context")]
    getter trigger_context : JSON::Any

    getter type : String

    def failed? : Bool
      !error.nil?
    end
  end

  # List response envelope for deployments.
  struct BetaManagedAgentsDeploymentListResponse
    include JSON::Serializable

    getter data : Array(BetaManagedAgentsDeployment)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id", emit_null: false)]
    getter first_id : String?

    @[JSON::Field(key: "last_id", emit_null: false)]
    getter last_id : String?
  end

  # List response envelope for deployment runs.
  struct BetaManagedAgentsDeploymentRunListResponse
    include JSON::Serializable

    getter data : Array(BetaManagedAgentsDeploymentRun)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id", emit_null: false)]
    getter first_id : String?

    @[JSON::Field(key: "last_id", emit_null: false)]
    getter last_id : String?
  end
end
