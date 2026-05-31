module Anthropic
  # Environments API resource (beta)
  class BetaEnvironments
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # Create a new environment
    def create(
      name : String,
      config : BetaEnvironmentConfigParam? = nil,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      scope : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaEnvironment
      params = {} of String => JSON::Any
      params["name"] = JSON::Any.new(name)
      params["config"] = JSON.parse(config.to_json) if config
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["description"] = JSON::Any.new(description) if description
      params["scope"] = JSON::Any.new(scope) if scope

      response = @client.post("/v1/environments?beta=true", params, beta_headers(betas))
      BetaEnvironment.from_json(response.body)
    end

    # Retrieve an environment by ID
    def retrieve(environment_id : String, betas : Array(String) = [] of String) : BetaEnvironment
      response = @client.get("/v1/environments/#{environment_id}?beta=true", nil, beta_headers(betas))
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
    ) : BetaEnvironment
      params = {} of String => JSON::Any

      params["name"] = JSON::Any.new(name) if name
      params["config"] = JSON.parse(config.to_json) if config
      params["description"] = JSON::Any.new(description) if description
      params["metadata"] = JSON.parse(metadata.to_json) if metadata
      params["scope"] = JSON::Any.new(scope) if scope

      response = @client.post("/v1/environments/#{environment_id}?beta=true", params, beta_headers(betas))
      BetaEnvironment.from_json(response.body)
    end

    # List environments
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaEnvironmentListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/environments?beta=true", query, beta_headers(betas))
      BetaEnvironmentListResponse.from_json(response.body)
    end

    # Delete an environment
    def delete(environment_id : String, betas : Array(String) = [] of String) : BetaEnvironmentDeleteResponse
      response = @client.delete("/v1/environments/#{environment_id}?beta=true", beta_headers(betas))
      BetaEnvironmentDeleteResponse.from_json(response.body)
    end

    # Archive an environment
    def archive(environment_id : String, betas : Array(String) = [] of String) : BetaEnvironment
      response = @client.post("/v1/environments/#{environment_id}/archive?beta=true", nil, beta_headers(betas))
      BetaEnvironment.from_json(response.body)
    end
  end
end
