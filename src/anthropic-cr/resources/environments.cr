module Anthropic
  # Environments API resource (beta)
  class BetaEnvironments
    def initialize(@client : Client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged_betas.join(",")}, workspace_id) || {} of String => String
    end

    def work : BetaEnvironmentWork
      BetaEnvironmentWork.new(@client)
    end

    # Create a new environment
    def create(
      name : String,
      config : BetaEnvironmentConfigParam? = nil,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      scope : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironment
      params = {} of String => JSON::Any
      params["name"] = JSON::Any.new(name)
      params["config"] = JSON.parse(config.to_json) if config
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["description"] = JSON::Any.new(description) if description
      params["scope"] = JSON::Any.new(scope) if scope

      response = @client.post("/v1/environments?beta=true", params, beta_headers(betas, workspace_id))
      BetaEnvironment.from_json(response.body)
    end

    # Retrieve an environment by ID
    def retrieve(
      environment_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironment
      response = @client.get("/v1/environments/#{environment_id}?beta=true", nil, beta_headers(betas, workspace_id))
      BetaEnvironment.from_json(response.body)
    end

    # Update an environment
    def update(
      environment_id : String,
      name : String? = nil,
      config : BetaEnvironmentConfigParam? = nil,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      scope : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironment
      params = {} of String => JSON::Any

      params["name"] = JSON::Any.new(name) if name
      params["config"] = JSON.parse(config.to_json) if config
      params["description"] = JSON::Any.new(description) if description
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["scope"] = JSON::Any.new(scope) if scope

      response = @client.post("/v1/environments/#{environment_id}?beta=true", params, beta_headers(betas, workspace_id))
      BetaEnvironment.from_json(response.body)
    end

    # List environments
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironmentListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/environments?beta=true", query, beta_headers(betas, workspace_id))
      BetaEnvironmentListResponse.from_json(response.body)
    end

    # Delete an environment
    def delete(
      environment_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironmentDeleteResponse
      response = @client.delete("/v1/environments/#{environment_id}?beta=true", beta_headers(betas, workspace_id))
      BetaEnvironmentDeleteResponse.from_json(response.body)
    end

    # Archive an environment
    def archive(
      environment_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaEnvironment
      response = @client.post("/v1/environments/#{environment_id}/archive?beta=true", nil, beta_headers(betas, workspace_id))
      BetaEnvironment.from_json(response.body)
    end
  end

  # Self-hosted environment work queue (beta).
  #
  # These endpoints are called automatically by the pre-built environment
  # worker for orchestrating sessions with self-hosted sandbox
  # environments. They are included here as a reference; you do not need
  # to invoke them directly.
  class BetaEnvironmentWork
    def initialize(@client : Client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged_betas.join(",")}, workspace_id) || {} of String => String
    end

    # Retrieve detailed information about a specific work item
    def retrieve(
      work_id : String,
      environment_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaSelfHostedWork
      response = @client.get(
        "/v1/environments/#{environment_id}/work/#{work_id}?beta=true",
        nil,
        beta_headers(betas, workspace_id)
      )
      BetaSelfHostedWork.from_json(response.body)
    end

    # Update work item metadata with merge semantics.
    #
    # Set a key to a string to upsert it, or to `nil` to delete it.
    def update(
      work_id : String,
      environment_id : String,
      metadata : Hash(String, String?),
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaSelfHostedWork
      body = {"metadata" => JSON.parse(metadata.to_json)}
      response = @client.post(
        "/v1/environments/#{environment_id}/work/#{work_id}?beta=true",
        body,
        beta_headers(betas, workspace_id)
      )
      BetaSelfHostedWork.from_json(response.body)
    end

    # List work items in an environment
    def list(
      environment_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaSelfHostedWorkListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get(
        "/v1/environments/#{environment_id}/work?beta=true",
        query,
        beta_headers(betas)
      )
      BetaSelfHostedWorkListResponse.from_json(response.body)
    end

    # Acknowledge receipt of a work item, transitioning it from `queued`
    # to `starting` and removing it from the queue
    def ack(
      work_id : String,
      environment_id : String,
      betas : Array(String) = [] of String,
    ) : BetaSelfHostedWork
      response = @client.post(
        "/v1/environments/#{environment_id}/work/#{work_id}/ack?beta=true",
        nil,
        beta_headers(betas)
      )
      BetaSelfHostedWork.from_json(response.body)
    end

    # Record a heartbeat for a work item to maintain the lease
    def heartbeat(
      work_id : String,
      environment_id : String,
      desired_ttl_seconds : Int32? = nil,
      expected_last_heartbeat : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaSelfHostedWorkHeartbeatResponse
      path = "/v1/environments/#{environment_id}/work/#{work_id}/heartbeat?beta=true"
      params = URI::Params.new
      params.add("desired_ttl_seconds", desired_ttl_seconds.to_s) if desired_ttl_seconds
      params.add("expected_last_heartbeat", expected_last_heartbeat) if expected_last_heartbeat
      path = "#{path}&#{params}" unless params.empty?

      response = @client.post(path, nil, beta_headers(betas))
      BetaSelfHostedWorkHeartbeatResponse.from_json(response.body)
    end

    # Long poll for work items in the queue. Returns `nil` when no work
    # arrives before the poll window closes.
    def poll(
      environment_id : String,
      block_ms : Int32? = nil,
      reclaim_older_than_ms : Int32? = nil,
      betas : Array(String) = [] of String,
      anthropic_worker_id : String? = nil,
    ) : BetaSelfHostedWork?
      path = "/v1/environments/#{environment_id}/work/poll?beta=true"
      params = URI::Params.new
      params.add("block_ms", block_ms.to_s) if block_ms
      params.add("reclaim_older_than_ms", reclaim_older_than_ms.to_s) if reclaim_older_than_ms
      path = "#{path}&#{params}" unless params.empty?

      headers = beta_headers(betas)
      headers[WORKER_ID_HEADER] = anthropic_worker_id if anthropic_worker_id

      response = @client.get(path, nil, headers)
      return nil if response.body.blank?
      BetaSelfHostedWork.from_json(response.body)
    end

    # Get statistics about the work queue for an environment
    def stats(
      environment_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaSelfHostedWorkQueueStats
      response = @client.get(
        "/v1/environments/#{environment_id}/work/stats?beta=true",
        nil,
        beta_headers(betas, workspace_id)
      )
      BetaSelfHostedWorkQueueStats.from_json(response.body)
    end

    # Stop a work item, initiating graceful or forced shutdown
    def stop(
      work_id : String,
      environment_id : String,
      force : Bool? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaSelfHostedWork
      body = {} of String => JSON::Any
      body["force"] = JSON::Any.new(force) unless force.nil?
      response = @client.post(
        "/v1/environments/#{environment_id}/work/#{work_id}/stop?beta=true",
        body,
        beta_headers(betas, workspace_id)
      )
      BetaSelfHostedWork.from_json(response.body)
    end
  end
end
