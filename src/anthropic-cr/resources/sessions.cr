module Anthropic
  # Sessions API resource (beta)
  class BetaSessions
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    def events : BetaSessionEvents
      BetaSessionEvents.new(@client)
    end

    def resources : BetaSessionResources
      BetaSessionResources.new(@client)
    end

    def threads : BetaSessionThreads
      BetaSessionThreads.new(@client)
    end

    # Create a session
    def create(
      environment_id : String,
      agent : BetaManagedAgentsAgentParamLike,
      title : String? = nil,
      metadata : Hash(String, String)? = nil,
      resources : Enumerable(BetaManagedAgentsSessionResourceParam)? = nil,
      vault_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsSession
      params = {} of String => JSON::Any
      params["environment_id"] = JSON::Any.new(environment_id)
      params["agent"] = JSON.parse(agent.to_json)
      params["title"] = JSON::Any.new(title) if title
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["resources"] = JSON.parse(resources.to_a.to_json) if resources
      params["vault_ids"] = JSON.parse(vault_ids.to_json) if vault_ids

      response = @client.post("/v1/sessions?beta=true", params, beta_headers(betas))
      BetaManagedAgentsSession.from_json(response.body)
    end

    # Retrieve a session
    def retrieve(session_id : String, betas : Array(String) = [] of String) : BetaManagedAgentsSession
      response = @client.get("/v1/sessions/#{session_id}?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsSession.from_json(response.body)
    end

    # Update a session
    def update(
      session_id : String,
      agent : BetaManagedAgentsAgentParamLike? = nil,
      title : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsSession
      params = {} of String => JSON::Any

      params["agent"] = JSON.parse(agent.to_json) if agent
      params["title"] = JSON::Any.new(title) if title
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/sessions/#{session_id}?beta=true", params, beta_headers(betas))
      BetaManagedAgentsSession.from_json(response.body)
    end

    # List sessions
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaSessionListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/sessions?beta=true", query, beta_headers(betas))
      BetaSessionListResponse.from_json(response.body)
    end

    # Delete a session
    def delete(session_id : String, betas : Array(String) = [] of String) : BetaManagedAgentsDeletedSession
      response = @client.delete("/v1/sessions/#{session_id}?beta=true", beta_headers(betas))
      BetaManagedAgentsDeletedSession.from_json(response.body)
    end

    # Archive a session
    def archive(session_id : String, betas : Array(String) = [] of String) : BetaManagedAgentsSession
      response = @client.post("/v1/sessions/#{session_id}/archive?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsSession.from_json(response.body)
    end
  end

  # Session Events API resource (beta)
  class BetaSessionEvents
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # List session events
    def list(
      session_id : String,
      created_at_gt : String? = nil,
      created_at_gte : String? = nil,
      created_at_lt : String? = nil,
      created_at_lte : String? = nil,
      limit : Int32 = 20,
      order : String? = nil,
      page : String? = nil,
      types : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : JSON::Any
      query = {} of String => String | Array(String)
      query["created_at[gt]"] = created_at_gt if created_at_gt
      query["created_at[gte]"] = created_at_gte if created_at_gte
      query["created_at[lt]"] = created_at_lt if created_at_lt
      query["created_at[lte]"] = created_at_lte if created_at_lte
      query["limit"] = limit.to_s
      query["order"] = order if order
      query["page"] = page if page
      query["types"] = types if types

      response = @client.get("/v1/sessions/#{session_id}/events?beta=true", query, beta_headers(betas))
      JSON.parse(response.body)
    end

    # Stream session events.
    #
    # Pass `event_deltas: [Anthropic::Sessions::DeltaType::AGENT_MESSAGE]` to
    # opt into live `event_start` / `event_delta` preview deltas. The block
    # receives each SSE event as a `JSON::Any`. Use
    # `Anthropic::Sessions.accumulate_managed_agents_event` to fold preview
    # deltas into a buffered `agent.message` snapshot.
    def stream(
      session_id : String,
      event_deltas : Array(String)? = nil,
      betas : Array(String) = [] of String,
      & : JSON::Any -> _
    )
      path = "/v1/sessions/#{session_id}/events/stream?beta=true"
      if event_deltas && !event_deltas.empty?
        params = URI::Params.new
        event_deltas.each { |delta_type| params.add("event_deltas", delta_type) }
        path = "#{path}&#{params}"
      end

      @client.get_stream(path, beta_headers(betas)) do |response|
        SessionEventStream.new(response).each { |event| yield event }
      end
    end
  end

  # Session Resources API resource (beta)
  class BetaSessionResources
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # Retrieve a specific resource
    def add_file(
      session_id : String,
      file_id : String,
      mount_path : String? = nil,
      betas : Array(String) = [] of String,
    ) : JSON::Any
      resource = BetaManagedAgentsFileResourceParam.new(file_id: file_id, mount_path: mount_path)
      response = @client.post("/v1/sessions/#{session_id}/resources?beta=true", resource, beta_headers(betas))
      JSON.parse(response.body)
    end

    def retrieve(
      session_id : String,
      resource_id : String,
      betas : Array(String) = [] of String,
    ) : JSON::Any
      response = @client.get("/v1/sessions/#{session_id}/resources/#{resource_id}?beta=true", nil, beta_headers(betas))
      JSON.parse(response.body)
    end

    # List resources in a session
    def list(
      session_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : JSON::Any
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/sessions/#{session_id}/resources?beta=true", query, beta_headers(betas))
      JSON.parse(response.body)
    end
  end

  # Session Threads API resource (beta)
  class BetaSessionThreads
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    def events : BetaSessionThreadEvents
      BetaSessionThreadEvents.new(@client)
    end

    # Create a thread under a session
    def create(
      session_id : String,
      agent : BetaManagedAgentsAgentParamLike,
      parent_thread_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsSessionThread
      params = {} of String => JSON::Any
      params["agent"] = JSON.parse(agent.to_json)
      params["parent_thread_id"] = JSON::Any.new(parent_thread_id) if parent_thread_id

      response = @client.post("/v1/sessions/#{session_id}/threads?beta=true", params, beta_headers(betas))
      BetaManagedAgentsSessionThread.from_json(response.body)
    end

    # Retrieve a thread
    def retrieve(
      session_id : String,
      thread_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsSessionThread
      response = @client.get("/v1/sessions/#{session_id}/threads/#{thread_id}?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsSessionThread.from_json(response.body)
    end

    # List threads in a session
    def list(
      session_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaSessionThreadListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/sessions/#{session_id}/threads?beta=true", query, beta_headers(betas))
      BetaSessionThreadListResponse.from_json(response.body)
    end

    # Archive a thread
    def archive(
      session_id : String,
      thread_id : String,
      betas : Array(String) = [] of String,
    ) : BetaManagedAgentsSessionThread
      response = @client.post("/v1/sessions/#{session_id}/threads/#{thread_id}/archive?beta=true", nil, beta_headers(betas))
      BetaManagedAgentsSessionThread.from_json(response.body)
    end
  end

  # Session Thread Events API resource (beta)
  class BetaSessionThreadEvents
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # List thread events
    def list(
      session_id : String,
      thread_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : JSON::Any
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/sessions/#{session_id}/threads/#{thread_id}/events?beta=true", query, beta_headers(betas))
      JSON.parse(response.body)
    end

    # Stream thread events.
    #
    # The block receives each SSE event as a `JSON::Any` (thread event streams
    # carry managed-agents event shapes, not `/v1/messages` event shapes).
    def stream(
      session_id : String,
      thread_id : String,
      betas : Array(String) = [] of String,
      & : JSON::Any -> _
    )
      @client.get_stream("/v1/sessions/#{session_id}/threads/#{thread_id}/stream?beta=true", beta_headers(betas)) do |response|
        SessionEventStream.new(response).each { |event| yield event }
      end
    end
  end
end
