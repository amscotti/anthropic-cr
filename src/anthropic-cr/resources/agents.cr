module Anthropic
  # Stateful Managed Agents API resource (beta)
  class BetaAgents
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # Serialize a model param (string, symbol, config object, or hash) for the API.
    private def serialize_model(model : BetaManagedAgentsModelParamLike) : JSON::Any
      case model
      when Symbol
        JSON::Any.new(Anthropic.model_name(model))
      when String
        JSON::Any.new(model)
      when JSON::Any
        model
      else
        JSON.parse(model.to_json)
      end
    end

    # Create a new stateful agent.
    #
    # `model` accepts a model string / shorthand symbol, or a
    # `BetaManagedAgentsModelConfig` (or hash) for effort/speed control:
    #
    # ```
    # client.beta.agents.create(model: :sonnet, name: "Helper")
    #
    # client.beta.agents.create(
    #   model: Anthropic::BetaManagedAgentsModelConfig.new(
    #     id: :sonnet,
    #     effort: "high",
    #     speed: "fast",
    #   ),
    #   name: "Helper",
    # )
    # ```
    def create(
      model : BetaManagedAgentsModelParamLike,
      name : String,
      description : String? = nil,
      mcp_servers : Array(JSON::Any | Hash(String, JSON::Any))? = nil,
      metadata : Hash(String, String)? = nil,
      multiagent : JSON::Any? = nil,
      skills : Array(JSON::Any)? = nil,
      system : String? = nil,
      tools : Array(JSON::Any)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaAgent
      params = {} of String => JSON::Any
      params["model"] = serialize_model(model)
      params["name"] = JSON::Any.new(name)
      params["description"] = JSON::Any.new(description) if description
      params["mcp_servers"] = JSON.parse(mcp_servers.to_json).as_a if mcp_servers
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["multiagent"] = multiagent if multiagent
      params["skills"] = JSON.parse(skills.to_json).as_a if skills
      params["system"] = JSON::Any.new(system) if system
      params["tools"] = JSON.parse(tools.to_json).as_a if tools

      response = @client.post("/v1/agents?beta=true", params, beta_headers(betas))
      BetaAgent.from_json(response.body)
    end

    # Retrieve an agent by ID
    def retrieve(
      agent_id : String,
      version : Int32? = nil,
      betas : Array(String) = [] of String,
    ) : BetaAgent
      query = {} of String => String
      query["version"] = version.to_s if version

      response = @client.get("/v1/agents/#{agent_id}?beta=true", query.empty? ? nil : query, beta_headers(betas))
      BetaAgent.from_json(response.body)
    end

    # Update an existing agent.
    #
    # `model` accepts the same shapes as `#create` (string, symbol, config
    # object, or hash). Omitting it leaves the stored model config unchanged.
    def update(
      agent_id : String,
      version : Int32,
      model : BetaManagedAgentsModelParamLike? = nil,
      name : String? = nil,
      description : String? = nil,
      mcp_servers : Array(JSON::Any | Hash(String, JSON::Any))? = nil,
      metadata : Hash(String, String)? = nil,
      multiagent : JSON::Any? = nil,
      skills : Array(JSON::Any)? = nil,
      system : String? = nil,
      tools : Array(JSON::Any)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaAgent
      params = {} of String => JSON::Any
      params["version"] = JSON::Any.new(version.to_i64)
      params["model"] = serialize_model(model) if model
      params["name"] = JSON::Any.new(name) if name
      params["description"] = JSON::Any.new(description) if description
      params["mcp_servers"] = JSON.parse(mcp_servers.to_json).as_a if mcp_servers
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["multiagent"] = multiagent if multiagent
      params["skills"] = JSON.parse(skills.to_json).as_a if skills
      params["system"] = JSON::Any.new(system) if system
      params["tools"] = JSON.parse(tools.to_json).as_a if tools

      response = @client.post("/v1/agents/#{agent_id}?beta=true", params, beta_headers(betas))
      BetaAgent.from_json(response.body)
    end

    # List agents
    def list(
      created_at_gte : String? = nil,
      created_at_lte : String? = nil,
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaAgentListResponse
      query = {"limit" => limit.to_s}
      query["created_at[gte]"] = created_at_gte if created_at_gte
      query["created_at[lte]"] = created_at_lte if created_at_lte
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/agents?beta=true", query, beta_headers(betas))
      BetaAgentListResponse.from_json(response.body)
    end

    # Archive an agent
    def archive(
      agent_id : String,
      betas : Array(String) = [] of String,
    ) : BetaAgent
      response = @client.post("/v1/agents/#{agent_id}/archive?beta=true", nil, beta_headers(betas))
      BetaAgent.from_json(response.body)
    end
  end
end
