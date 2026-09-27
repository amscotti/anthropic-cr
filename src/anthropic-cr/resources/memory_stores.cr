module Anthropic
  # Memory Stores API resource (beta)
  class BetaMemoryStores
    def initialize(@client : Client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      merged_betas << AGENT_MEMORY_BETA unless merged_betas.includes?(AGENT_MEMORY_BETA)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged_betas.join(",")}, workspace_id) || {} of String => String
    end

    def memories : BetaMemories
      BetaMemories.new(@client)
    end

    def memory_versions : BetaMemoryVersions
      BetaMemoryVersions.new(@client)
    end

    # Create a new memory store
    def create(
      name : String,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemoryStore
      params = {"name" => name}
      params["description"] = description if description
      params["metadata"] = metadata if metadata

      response = @client.post("/v1/memory_stores?beta=true", params, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryStore.from_json(response.body)
    end

    # Retrieve a memory store by ID
    def retrieve(memory_store_id : String, betas : Array(String) = [] of String, workspace_id : String? = nil) : BetaManagedAgentsMemoryStore
      response = @client.get("/v1/memory_stores/#{memory_store_id}?beta=true", nil, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryStore.from_json(response.body)
    end

    # Update a memory store
    def update(
      memory_store_id : String,
      name : String? = nil,
      description : String? = nil,
      metadata : Hash(String, String)? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemoryStore
      params = {} of String => JSON::Any

      params["name"] = JSON::Any.new(name) if name
      params["description"] = JSON::Any.new(description) if description
      params["metadata"] = JSON.parse(metadata.to_json) if metadata

      response = @client.post("/v1/memory_stores/#{memory_store_id}?beta=true", params, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryStore.from_json(response.body)
    end

    # List memory stores
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaMemoryStoreListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/memory_stores?beta=true", query, beta_headers(betas, workspace_id))
      BetaMemoryStoreListResponse.from_json(response.body)
    end

    # Delete a memory store
    def delete(memory_store_id : String, betas : Array(String) = [] of String, workspace_id : String? = nil) : BetaManagedAgentsDeletedMemoryStore
      response = @client.delete("/v1/memory_stores/#{memory_store_id}?beta=true", beta_headers(betas, workspace_id))
      BetaManagedAgentsDeletedMemoryStore.from_json(response.body)
    end

    # Archive a memory store
    def archive(memory_store_id : String, betas : Array(String) = [] of String, workspace_id : String? = nil) : BetaManagedAgentsMemoryStore
      response = @client.post("/v1/memory_stores/#{memory_store_id}/archive?beta=true", nil, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryStore.from_json(response.body)
    end
  end

  # Memories API resource (beta)
  class BetaMemories
    def initialize(@client : Client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      merged_betas << AGENT_MEMORY_BETA unless merged_betas.includes?(AGENT_MEMORY_BETA)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged_betas.join(",")}, workspace_id) || {} of String => String
    end

    # Create a memory in a store
    def create(
      memory_store_id : String,
      path : String,
      content : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemory
      params = {
        "path"    => path,
        "content" => content,
      }

      response = @client.post("/v1/memory_stores/#{memory_store_id}/memories?beta=true", params, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemory.from_json(response.body)
    end

    # Retrieve a memory
    def retrieve(
      memory_store_id : String,
      memory_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemory
      response = @client.get("/v1/memory_stores/#{memory_store_id}/memories/#{memory_id}?beta=true", nil, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemory.from_json(response.body)
    end

    # Update a memory
    def update(
      memory_store_id : String,
      memory_id : String,
      content : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemory
      params = {"content" => content}

      response = @client.post("/v1/memory_stores/#{memory_store_id}/memories/#{memory_id}?beta=true", params, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemory.from_json(response.body)
    end

    # List memories in a store
    def list(
      memory_store_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaMemoryListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/memory_stores/#{memory_store_id}/memories?beta=true", query, beta_headers(betas, workspace_id))
      BetaMemoryListResponse.from_json(response.body)
    end

    # Delete a memory
    def delete(
      memory_store_id : String,
      memory_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsDeletedMemory
      response = @client.delete("/v1/memory_stores/#{memory_store_id}/memories/#{memory_id}?beta=true", beta_headers(betas, workspace_id))
      BetaManagedAgentsDeletedMemory.from_json(response.body)
    end
  end

  # Memory Versions API resource (beta)
  class BetaMemoryVersions
    def initialize(@client : Client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << MANAGED_AGENTS_BETA unless merged_betas.includes?(MANAGED_AGENTS_BETA)
      merged_betas << AGENT_MEMORY_BETA unless merged_betas.includes?(AGENT_MEMORY_BETA)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged_betas.join(",")}, workspace_id) || {} of String => String
    end

    # Retrieve a memory version
    def retrieve(
      memory_store_id : String,
      version_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemoryVersion
      response = @client.get("/v1/memory_stores/#{memory_store_id}/versions/#{version_id}?beta=true", nil, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryVersion.from_json(response.body)
    end

    # List versions of memories
    def list(
      memory_store_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaMemoryVersionListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/memory_stores/#{memory_store_id}/versions?beta=true", query, beta_headers(betas, workspace_id))
      BetaMemoryVersionListResponse.from_json(response.body)
    end

    # Redact a version
    def redact(
      memory_store_id : String,
      version_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaManagedAgentsMemoryVersion
      response = @client.post("/v1/memory_stores/#{memory_store_id}/versions/#{version_id}/redact?beta=true", nil, beta_headers(betas, workspace_id))
      BetaManagedAgentsMemoryVersion.from_json(response.body)
    end
  end
end
