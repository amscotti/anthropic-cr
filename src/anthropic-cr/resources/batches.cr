module Anthropic
  # Request body for batch creation
  private struct BatchCreateBody
    include JSON::Serializable
    getter requests : Array(BatchRequest)

    def initialize(@requests : Array(BatchRequest))
    end
  end

  private struct BetaBatchCreateBody
    include JSON::Serializable
    getter requests : Array(BetaBatchRequest)

    def initialize(@requests : Array(BetaBatchRequest))
    end
  end

  # Batches API resource for message batch operations
  class Batches
    def initialize(@client : Client)
    end

    # Create a new batch
    def create(
      requests : Array(BatchRequest),
    ) : BatchResponse
      body = BatchCreateBody.new(requests)
      response = @client.post("/v1/messages/batches", body, build_beta_headers(requests))
      BatchResponse.from_json(response.body)
    end

    # Retrieve batch status
    def retrieve(batch_id : String) : BatchResponse
      response = @client.get("/v1/messages/batches/#{batch_id}")
      BatchResponse.from_json(response.body)
    end

    # List all batches with pagination
    def list(
      limit : Int32 = 20,
      before_id : String? = nil,
      after_id : String? = nil,
    ) : BatchListResponse
      params = {"limit" => limit.to_s}
      params["before_id"] = before_id if before_id
      params["after_id"] = after_id if after_id

      response = @client.get("/v1/messages/batches", params)
      BatchListResponse.from_json(response.body)
    end

    # Stream batch results (JSONL format)
    def results(batch_id : String, &)
      @client.get_stream("/v1/messages/batches/#{batch_id}/results") do |response|
        response.body_io.each_line do |line|
          next if line.empty?
          yield BatchResult.from_json(line)
        end
      end
    end

    # Cancel a batch
    def cancel(batch_id : String) : BatchResponse
      response = @client.post("/v1/messages/batches/#{batch_id}/cancel", NamedTuple.new)
      BatchResponse.from_json(response.body)
    end

    # Delete a batch
    def delete(batch_id : String) : DeletedResponse
      response = @client.delete("/v1/messages/batches/#{batch_id}")
      DeletedResponse.from_json(response.body)
    end

    private def build_beta_headers(requests : Array(BatchRequest)) : Hash(String, String)?
      betas = [] of String

      requests.each do |request|
        params = request.params

        if (params.cache_control.try(&.ttl) || 0) > 0
          betas << EXTENDED_CACHE_TTL_BETA unless betas.includes?(EXTENDED_CACHE_TTL_BETA)
        end

        Anthropic.beta_headers_for_tools(params.tools).each do |beta|
          betas << beta unless betas.includes?(beta)
        end
      end

      return nil if betas.empty?

      {"anthropic-beta" => betas.join(",")}
    end
  end

  class BetaBatches
    BETA_HEADER = "message-batches-2024-09-24"

    def initialize(@client : Client)
    end

    def create(
      requests : Array(BatchRequest),
      betas : Array(String) = [] of String,
    ) : BatchResponse
      body = BatchCreateBody.new(requests)
      response = @client.post("/v1/messages/batches?beta=true", body, beta_headers(betas, requests))
      BatchResponse.from_json(response.body)
    end

    def create(
      requests : Array(BetaBatchRequest),
      betas : Array(String) = [] of String,
    ) : BatchResponse
      body = BetaBatchCreateBody.new(requests)
      response = @client.post("/v1/messages/batches?beta=true", body, beta_headers(betas, requests))
      BatchResponse.from_json(response.body)
    end

    def retrieve(batch_id : String, betas : Array(String) = [] of String) : BatchResponse
      response = @client.get("/v1/messages/batches/#{batch_id}?beta=true", nil, beta_headers(betas))
      BatchResponse.from_json(response.body)
    end

    def list(
      limit : Int32 = 20,
      before_id : String? = nil,
      after_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaBatchListResponse
      params = {"limit" => limit.to_s}
      params["before_id"] = before_id if before_id
      params["after_id"] = after_id if after_id

      response = @client.get("/v1/messages/batches?beta=true", params, beta_headers(betas))
      BetaBatchListResponse.from_json(response.body)
    end

    def results(batch_id : String, betas : Array(String) = [] of String, &)
      @client.get_stream("/v1/messages/batches/#{batch_id}/results?beta=true", beta_headers(betas)) do |response|
        response.body_io.each_line do |line|
          next if line.empty?
          yield BatchResult.from_json(line)
        end
      end
    end

    def cancel(batch_id : String, betas : Array(String) = [] of String) : BatchResponse
      response = @client.post("/v1/messages/batches/#{batch_id}/cancel?beta=true", NamedTuple.new, beta_headers(betas))
      BatchResponse.from_json(response.body)
    end

    def delete(batch_id : String, betas : Array(String) = [] of String) : DeletedResponse
      response = @client.delete("/v1/messages/batches/#{batch_id}?beta=true", beta_headers(betas))
      DeletedResponse.from_json(response.body)
    end

    private def beta_headers(betas : Array(String), requests : Array(BatchRequest)? = nil) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << BETA_HEADER unless merged_betas.includes?(BETA_HEADER)

      requests.try &.each do |request|
        params = request.params

        if (params.cache_control.try(&.ttl) || 0) > 0
          merged_betas << EXTENDED_CACHE_TTL_BETA unless merged_betas.includes?(EXTENDED_CACHE_TTL_BETA)
        end

        Anthropic.beta_headers_for_tools(params.tools).each do |beta|
          merged_betas << beta unless merged_betas.includes?(beta)
        end
      end

      {"anthropic-beta" => merged_betas.join(",")}
    end

    private def beta_headers(betas : Array(String), requests : Array(BetaBatchRequest)? = nil) : Hash(String, String)
      merged_betas = betas.dup
      merged_betas << BETA_HEADER unless merged_betas.includes?(BETA_HEADER)

      requests.try &.each do |request|
        params = request.params

        if (params.cache_control.try(&.ttl) || 0) > 0
          merged_betas << EXTENDED_CACHE_TTL_BETA unless merged_betas.includes?(EXTENDED_CACHE_TTL_BETA)
        end

        if params.output_config.try(&.format)
          merged_betas << STRUCTURED_OUTPUT_BETA unless merged_betas.includes?(STRUCTURED_OUTPUT_BETA)
        end

        Anthropic.beta_headers_for_tools(params.tools).each do |beta|
          merged_betas << beta unless merged_betas.includes?(beta)
        end
      end

      {"anthropic-beta" => merged_betas.join(",")}
    end
  end

  # Batch request structure
  struct BatchRequest
    include JSON::Serializable

    @[JSON::Field(key: "custom_id")]
    getter custom_id : String

    getter params : BatchRequestParams

    def initialize(@custom_id : String, @params : BatchRequestParams)
    end
  end

  struct BetaBatchRequest
    include JSON::Serializable

    @[JSON::Field(key: "custom_id")]
    getter custom_id : String

    getter params : BetaBatchRequestParams

    def initialize(@custom_id : String, @params : BetaBatchRequestParams)
    end
  end

  # Parameters for a batch request
  struct BatchRequestParams
    include JSON::Serializable

    getter model : String

    @[JSON::Field(key: "max_tokens")]
    getter max_tokens : Int32

    getter messages : Array(MessageParam)

    @[JSON::Field(emit_null: false)]
    getter system : String | Array(TextContent)?

    @[JSON::Field(emit_null: false)]
    getter temperature : Float64?

    @[JSON::Field(key: "top_p", emit_null: false)]
    getter top_p : Float64?

    @[JSON::Field(key: "top_k", emit_null: false)]
    getter top_k : Int32?

    @[JSON::Field(emit_null: false)]
    getter tools : Array(ToolDefinition | ServerTool)?

    @[JSON::Field(key: "tool_choice", emit_null: false)]
    getter tool_choice : ToolChoice?

    @[JSON::Field(key: "stop_sequences", emit_null: false)]
    getter stop_sequences : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter metadata : Metadata | Hash(String, String)?

    @[JSON::Field(key: "service_tier", emit_null: false)]
    getter service_tier : String?

    @[JSON::Field(emit_null: false)]
    getter thinking : ThinkingConfig?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    @[JSON::Field(emit_null: false)]
    getter container : String?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String?

    def initialize(
      @model : String,
      @max_tokens : Int32,
      @messages : Array(MessageParam),
      @system : String | Array(TextContent)? = nil,
      @temperature : Float64? = nil,
      @top_p : Float64? = nil,
      @top_k : Int32? = nil,
      @tools : Array(ToolDefinition | ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Metadata | Hash(String, String)? = nil,
      @service_tier : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @cache_control : CacheControl? = nil,
      @container : String? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
    )
    end

    # Helper to create params with Tool objects (converts to ToolDefinition)
    def self.with_tools(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam),
      tools : Array(Tool),
      server_tools : Array(ServerTool)? = nil,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata | Hash(String, String)? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      container : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
    ) : self
      tool_definitions = [] of ToolDefinition | ServerTool
      tools.each { |tool| tool_definitions << tool.to_definition }
      server_tools.try &.each { |tool| tool_definitions << tool }

      new(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        thinking: thinking,
        cache_control: cache_control,
        container: container,
        output_config: output_config,
        inference_geo: inference_geo
      )
    end
  end

  struct BetaBatchRequestParams
    include JSON::Serializable

    getter model : String

    @[JSON::Field(key: "max_tokens")]
    getter max_tokens : Int32

    getter messages : Array(MessageParam)

    @[JSON::Field(emit_null: false)]
    getter system : String | Array(TextContent)?

    @[JSON::Field(emit_null: false)]
    getter temperature : Float64?

    @[JSON::Field(key: "top_p", emit_null: false)]
    getter top_p : Float64?

    @[JSON::Field(key: "top_k", emit_null: false)]
    getter top_k : Int32?

    @[JSON::Field(emit_null: false)]
    getter tools : Array(ToolDefinition | ServerTool)?

    @[JSON::Field(key: "tool_choice", emit_null: false)]
    getter tool_choice : ToolChoice?

    @[JSON::Field(key: "stop_sequences", emit_null: false)]
    getter stop_sequences : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter metadata : Metadata?

    @[JSON::Field(key: "service_tier", emit_null: false)]
    getter service_tier : String?

    @[JSON::Field(emit_null: false)]
    getter speed : String?

    @[JSON::Field(emit_null: false)]
    getter thinking : ThinkingConfig?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String?

    @[JSON::Field(key: "context_management", emit_null: false)]
    getter context_management : ContextManagementConfig?

    @[JSON::Field(emit_null: false)]
    getter container : String | ContainerConfig?

    @[JSON::Field(key: "mcp_servers", emit_null: false)]
    getter mcp_servers : Array(MCPServerDefinition)?

    def initialize(
      @model : String,
      @max_tokens : Int32,
      @messages : Array(MessageParam),
      @system : String | Array(TextContent)? = nil,
      @temperature : Float64? = nil,
      @top_p : Float64? = nil,
      @top_k : Int32? = nil,
      @tools : Array(ToolDefinition | ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Metadata? = nil,
      @service_tier : String? = nil,
      @speed : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @cache_control : CacheControl? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
      @context_management : ContextManagementConfig? = nil,
      @container : String | ContainerConfig? = nil,
      @mcp_servers : Array(MCPServerDefinition)? = nil,
    )
    end

    def self.with_tools(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam),
      tools : Array(Tool),
      server_tools : Array(ServerTool)? = nil,
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
    ) : self
      tool_definitions = [] of ToolDefinition | ServerTool
      tools.each { |tool| tool_definitions << tool.to_definition }
      server_tools.try &.each { |tool| tool_definitions << tool }

      new(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers
      )
    end
  end

  # Batch response structure
  struct BatchResponse
    include JSON::Serializable

    getter id : String
    getter type : String # "message_batch"

    @[JSON::Field(key: "processing_status")]
    getter processing_status : String # "in_progress" | "canceling" | "ended"

    @[JSON::Field(key: "request_counts")]
    getter request_counts : BatchRequestCounts

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "ended_at")]
    getter ended_at : String?

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    @[JSON::Field(key: "cancel_initiated_at")]
    getter cancel_initiated_at : String?

    @[JSON::Field(key: "results_url")]
    getter results_url : String?

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  # Request counts for a batch
  struct BatchRequestCounts
    include JSON::Serializable

    getter processing : Int32
    getter succeeded : Int32
    getter errored : Int32
    getter canceled : Int32
    getter expired : Int32
  end

  # List response for batches
  struct BatchListResponse
    include JSON::Serializable

    getter data : Array(BatchResponse)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?

    # Auto-paginate through all batches
    #
    # Returns an array of all batches across all pages
    #
    # ```
    # all_batches = client.messages.batches.list.auto_paging_all(client)
    # all_batches.each do |batch|
    #   puts batch.id
    # end
    # ```
    def auto_paging_all(client : Client) : Array(BatchResponse)
      results = data.dup
      current_response = self

      while current_response.has_more? && (last = current_response.last_id)
        current_response = Batches.new(client).list(after_id: last)
        results.concat(current_response.data)
      end

      results
    end
  end

  struct BetaBatchListResponse
    include JSON::Serializable

    getter data : Array(BatchResponse)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?

    def auto_paging_all(client : Client, betas : Array(String) = [] of String) : Array(BatchResponse)
      results = data.dup
      current_response = self

      while current_response.has_more? && (last = current_response.last_id)
        current_response = BetaBatches.new(client).list(after_id: last, betas: betas)
        results.concat(current_response.data)
      end

      results
    end
  end

  # Individual batch result from JSONL stream
  struct BatchResult
    include JSON::Serializable

    @[JSON::Field(key: "custom_id")]
    getter custom_id : String

    getter result : BatchResultData
  end

  # Result data for a batch item
  struct BatchResultData
    include JSON::Serializable

    getter type : String # "succeeded" | "errored" | "expired" | "canceled"
    getter message : Message?
    getter error : BatchError?
  end

  # Error information for a failed batch item
  struct BatchError
    include JSON::Serializable

    getter type : String
    getter message : String
  end

  # Response for delete operation
  struct DeletedResponse
    include JSON::Serializable

    getter id : String
    getter type : String # "deleted"
  end
end
