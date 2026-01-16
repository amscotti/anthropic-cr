module Anthropic
  # Request body for batch creation
  private struct BatchCreateBody
    include JSON::Serializable
    getter requests : Array(BatchRequest)

    def initialize(@requests : Array(BatchRequest))
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
      response = @client.post("/v1/messages/batches", body)
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
    getter tools : Array(ToolDefinition)?

    @[JSON::Field(key: "tool_choice", emit_null: false)]
    getter tool_choice : ToolChoice?

    @[JSON::Field(key: "stop_sequences", emit_null: false)]
    getter stop_sequences : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter metadata : Hash(String, String)?

    @[JSON::Field(key: "service_tier", emit_null: false)]
    getter service_tier : String?

    def initialize(
      @model : String,
      @max_tokens : Int32,
      @messages : Array(MessageParam),
      @system : String | Array(TextContent)? = nil,
      @temperature : Float64? = nil,
      @top_p : Float64? = nil,
      @top_k : Int32? = nil,
      @tools : Array(ToolDefinition)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Hash(String, String)? = nil,
      @service_tier : String? = nil,
    )
    end

    # Helper to create params with Tool objects (converts to ToolDefinition)
    def self.with_tools(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam),
      tools : Array(Tool),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Hash(String, String)? = nil,
      service_tier : String? = nil,
    ) : self
      new(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tools.map(&.to_definition),
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier
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
