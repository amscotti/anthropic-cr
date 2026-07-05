module Anthropic
  # Managed Agents Deployments API resource (beta).
  #
  # A deployment pins an agent + environment + optional cron schedule so that
  # sessions can be created on a schedule or on demand via `run`.
  #
  # ```
  # deployment = client.beta.deployments.create(
  #   agent: "agent_123",
  #   environment_id: "env_123",
  #   name: "Nightly summary",
  #   initial_events: [{"type" => "user.message", "content" => [...]}]
  # )
  # ```
  class BetaDeployments
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged = betas.dup
      merged << MANAGED_AGENTS_BETA unless merged.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged.join(",")}
    end

    # Create a deployment.
    def create(
      agent : String | Hash(String, JSON::Any),
      environment_id : String,
      initial_events : Array(JSON::Any | Hash(String, JSON::Any)),
      name : String,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      resources : Array(JSON::Any | Hash(String, JSON::Any))? = nil,
      schedule : JSON::Any | Hash(String, JSON::Any)? = nil,
      vault_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      params = {} of String => JSON::Any
      params["agent"] = agent.is_a?(String) ? JSON::Any.new(agent) : JSON.parse(agent.to_json)
      params["environment_id"] = JSON::Any.new(environment_id)
      params["initial_events"] = JSON.parse(initial_events.to_json)
      params["name"] = JSON::Any.new(name)
      params["description"] = JSON::Any.new(description) if description
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["resources"] = JSON.parse(resources.to_json) if resources
      params["schedule"] = schedule.is_a?(JSON::Any) ? schedule : JSON.parse(schedule.to_json) if schedule
      params["vault_ids"] = JSON.parse(vault_ids.to_json) if vault_ids

      response = @client.post("/v1/deployments?beta=true", params, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # Retrieve a deployment by ID.
    def retrieve(
      deployment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      response = @client.get("/v1/deployments/#{deployment_id}?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # Update a deployment.
    def update(
      deployment_id : String,
      agent : String | Hash(String, JSON::Any)? = nil,
      description : String? = nil,
      environment_id : String? = nil,
      initial_events : Array(JSON::Any | Hash(String, JSON::Any))? = nil,
      metadata : Hash(String, String)? = nil,
      name : String? = nil,
      resources : Array(JSON::Any | Hash(String, JSON::Any))? = nil,
      schedule : JSON::Any | Hash(String, JSON::Any)? = nil,
      vault_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      params = {} of String => JSON::Any
      params["agent"] = agent.is_a?(String) ? JSON::Any.new(agent) : JSON.parse(agent.to_json) if agent
      params["description"] = JSON::Any.new(description) if description
      params["environment_id"] = JSON::Any.new(environment_id) if environment_id
      params["initial_events"] = JSON.parse(initial_events.to_json) if initial_events
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["name"] = JSON::Any.new(name) if name
      params["resources"] = JSON.parse(resources.to_json) if resources
      params["schedule"] = schedule.is_a?(JSON::Any) ? schedule : JSON.parse(schedule.to_json) if schedule
      params["vault_ids"] = JSON.parse(vault_ids.to_json) if vault_ids

      response = @client.post("/v1/deployments/#{deployment_id}?beta=true", params, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # List deployments.
    def list(
      agent_id : String? = nil,
      created_at_gte : String? = nil,
      created_at_lte : String? = nil,
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      status : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeploymentListResponse
      query = {"limit" => limit.to_s}
      query["agent_id"] = agent_id if agent_id
      query["created_at[gte]"] = created_at_gte if created_at_gte
      query["created_at[lte]"] = created_at_lte if created_at_lte
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page
      query["status"] = status if status

      response = @client.get("/v1/deployments?beta=true", query, beta_headers(betas))
      BetaManagedAgentsDeploymentListResponse.from_json(response.body)
    end

    # Archive a deployment.
    def archive(
      deployment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      response = @client.post("/v1/deployments/#{deployment_id}/archive?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # Pause a deployment.
    def pause(
      deployment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      response = @client.post("/v1/deployments/#{deployment_id}/pause?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # Unpause a deployment.
    def unpause(
      deployment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeployment
      response = @client.post("/v1/deployments/#{deployment_id}/unpause?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeployment.from_json(response.body)
    end

    # Trigger a deployment run (creates a session).
    def run(
      deployment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeploymentRun
      response = @client.post("/v1/deployments/#{deployment_id}/run?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeploymentRun.from_json(response.body)
    end
  end

  # Managed Agents Deployment Runs API resource (beta).
  #
  # Inspect individual runs of a deployment (triggered manually or by schedule).
  class BetaDeploymentRuns
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged = betas.dup
      merged << MANAGED_AGENTS_BETA unless merged.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged.join(",")}
    end

    # Retrieve a deployment run by ID.
    def retrieve(
      deployment_run_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeploymentRun
      response = @client.get("/v1/deployment_runs/#{deployment_run_id}?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsDeploymentRun.from_json(response.body)
    end

    # List deployment runs.
    def list(
      created_at_gt : String? = nil,
      created_at_gte : String? = nil,
      created_at_lt : String? = nil,
      created_at_lte : String? = nil,
      deployment_id : String? = nil,
      has_error : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      trigger_type : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsDeploymentRunListResponse
      query = {"limit" => limit.to_s}
      query["created_at[gt]"] = created_at_gt if created_at_gt
      query["created_at[gte]"] = created_at_gte if created_at_gte
      query["created_at[lt]"] = created_at_lt if created_at_lt
      query["created_at[lte]"] = created_at_lte if created_at_lte
      query["deployment_id"] = deployment_id if deployment_id
      query["has_error"] = has_error.to_s if has_error != nil
      query["page"] = page if page
      query["trigger_type"] = trigger_type if trigger_type

      response = @client.get("/v1/deployment_runs?beta=true", query, beta_headers(betas))
      BetaManagedAgentsDeploymentRunListResponse.from_json(response.body)
    end
  end
end
