module Anthropic
  # Stateful Vaults API resource for storing secrets securely (beta)
  class BetaVaults
    # Credentials sub-resource accessor
    getter credentials : BetaVaultsCredentials

    def initialize(@client : Client)
      @credentials = BetaVaultsCredentials.new(@client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # Create a new Vault
    def create(
      display_name : String,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaVault
      params = {} of String => JSON::Any
      params["display_name"] = JSON::Any.new(display_name)
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/vaults?beta=true", params, beta_headers(betas))
      BetaVault.from_json(response.body)
    end

    # Retrieve a Vault by ID
    def retrieve(
      vault_id : String,
      betas : Array(String) = [] of String,
    ) : BetaVault
      response = @client.get("/v1/vaults/#{vault_id}?beta=true", nil, beta_headers(betas))
      BetaVault.from_json(response.body)
    end

    # Update a Vault
    def update(
      vault_id : String,
      display_name : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaVault
      params = {} of String => JSON::Any
      params["display_name"] = JSON::Any.new(display_name) if display_name
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/vaults/#{vault_id}?beta=true", params, beta_headers(betas))
      BetaVault.from_json(response.body)
    end

    # List Vaults
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaVaultListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/vaults?beta=true", query, beta_headers(betas))
      BetaVaultListResponse.from_json(response.body)
    end

    # Delete a Vault
    def delete(
      vault_id : String,
      betas : Array(String) = [] of String,
    ) : BetaVaultDeleteResponse
      response = @client.delete("/v1/vaults/#{vault_id}?beta=true", beta_headers(betas))
      BetaVaultDeleteResponse.from_json(response.body)
    end

    # Archive a Vault
    def archive(
      vault_id : String,
      betas : Array(String) = [] of String,
    ) : BetaVault
      response = @client.post("/v1/vaults/#{vault_id}/archive?beta=true", nil, beta_headers(betas))
      BetaVault.from_json(response.body)
    end
  end

  # Sub-resource for credentials inside a Vault (beta)
  class BetaVaultsCredentials
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      {"anthropic-beta" => merged_betas.join(",")}
    end

    # Create a Credential inside a Vault
    def create(
      vault_id : String,
      auth : JSON::Any | Hash(String, JSON::Any),
      display_name : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaCredential
      params = {} of String => JSON::Any
      params["auth"] = JSON.parse(auth.to_json)
      params["display_name"] = JSON::Any.new(display_name) if display_name
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/vaults/#{vault_id}/credentials?beta=true", params, beta_headers(betas))
      BetaCredential.from_json(response.body)
    end

    # Retrieve a Credential by ID
    def retrieve(
      vault_id : String,
      credential_id : String,
      betas : Array(String) = [] of String,
    ) : BetaCredential
      response = @client.get("/v1/vaults/#{vault_id}/credentials/#{credential_id}?beta=true", nil, beta_headers(betas))
      BetaCredential.from_json(response.body)
    end

    # Update a Credential
    def update(
      vault_id : String,
      credential_id : String,
      auth : JSON::Any | Hash(String, JSON::Any)? = nil,
      display_name : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaCredential
      params = {} of String => JSON::Any
      params["auth"] = JSON.parse(auth.to_json) if auth
      params["display_name"] = JSON::Any.new(display_name) if display_name
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/vaults/#{vault_id}/credentials/#{credential_id}?beta=true", params, beta_headers(betas))
      BetaCredential.from_json(response.body)
    end

    # List Credentials inside a Vault
    def list(
      vault_id : String,
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaCredentialListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/vaults/#{vault_id}/credentials?beta=true", query, beta_headers(betas))
      BetaCredentialListResponse.from_json(response.body)
    end

    # Delete a Credential
    def delete(
      vault_id : String,
      credential_id : String,
      betas : Array(String) = [] of String,
    ) : BetaCredentialDeleteResponse
      response = @client.delete("/v1/vaults/#{vault_id}/credentials/#{credential_id}?beta=true", beta_headers(betas))
      BetaCredentialDeleteResponse.from_json(response.body)
    end

    # Archive a Credential
    def archive(
      vault_id : String,
      credential_id : String,
      betas : Array(String) = [] of String,
    ) : BetaCredential
      response = @client.post("/v1/vaults/#{vault_id}/credentials/#{credential_id}/archive?beta=true", nil, beta_headers(betas))
      BetaCredential.from_json(response.body)
    end

    # Validate an MCP OAuth Credential
    def mcp_oauth_validate(
      vault_id : String,
      credential_id : String,
      betas : Array(String) = [] of String,
    ) : BetaCredentialValidation
      response = @client.post("/v1/vaults/#{vault_id}/credentials/#{credential_id}/mcp_oauth_validate?beta=true", nil, beta_headers(betas))
      BetaCredentialValidation.from_json(response.body)
    end
  end
end
