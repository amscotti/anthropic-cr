module Anthropic
  # Dreams API resource (beta / research preview).
  #
  # An asynchronous memory-consolidation job that reads a memory store plus
  # session transcripts and writes consolidated memories into a new output
  # memory store. Dream endpoints require both beta headers (auto-attached):
  # `managed-agents-2026-04-01` and `dreaming-2026-04-21`. Research-preview
  # access must be requested separately; without it the API returns 404.
  #
  # ```
  # dream = client.beta.dreams.create(
  #   inputs: [
  #     Anthropic::BetaDreamMemoryStoreInput.new("memstore_abc"),
  #     Anthropic::BetaDreamSessionsInput.new(["sess_1", "sess_2"]),
  #   ],
  #   model: "claude-opus-4-7",
  #   instructions: "Consolidate project facts",
  # )
  # dream = client.beta.dreams.retrieve(dream.id)
  # ```
  class BetaDreams
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged = betas.dup
      # Official docs require both; managed-agents alone does not unlock Dreams.
      merged << MANAGED_AGENTS_BETA unless merged.includes?(MANAGED_AGENTS_BETA)
      merged << DREAMING_BETA unless merged.includes?(DREAMING_BETA)
      {"anthropic-beta" => merged.join(",")}
    end

    # Create a Dream.
    #
    # `model` may be a bare model id string or a `BetaDreamModelConfig` /
    # hash with `id` (and optional `speed`).
    def create(
      inputs : Array(BetaDreamInput | Hash(String, JSON::Any)),
      model : String | BetaDreamModelConfig | Hash(String, JSON::Any),
      instructions : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaDream
      params = {} of String => JSON::Any
      params["inputs"] = JSON.parse(inputs.to_json)
      params["model"] = case model
                        when String
                          JSON::Any.new(model)
                        when BetaDreamModelConfig
                          JSON.parse(model.to_json)
                        else
                          JSON.parse(model.to_json)
                        end
      params["instructions"] = JSON::Any.new(instructions) if instructions

      response = @client.post("/v1/dreams?beta=true", params, beta_headers(betas))
      BetaDream.from_json(response.body)
    end

    # Retrieve a Dream by ID.
    def retrieve(
      dream_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDream
      response = @client.get("/v1/dreams/#{dream_id}?beta=true", nil, beta_headers(betas))
      BetaDream.from_json(response.body)
    end

    # List Dreams.
    #
    # `created_at_gt` / `created_at_lt` are exclusive RFC 3339 bounds.
    # `statuses` filters by lifecycle status (repeatable query param).
    def list(
      created_at_gt : String? = nil,
      created_at_lt : String? = nil,
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      statuses : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaDreamListResponse
      query = {} of String => String | Array(String)
      query["limit"] = limit.to_s
      query["created_at[gt]"] = created_at_gt if created_at_gt
      query["created_at[lt]"] = created_at_lt if created_at_lt
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page
      query["statuses"] = statuses if statuses && !statuses.empty?

      response = @client.get("/v1/dreams?beta=true", query, beta_headers(betas))
      BetaDreamListResponse.from_json(response.body)
    end

    # Archive a Dream.
    def archive(
      dream_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDream
      response = @client.post("/v1/dreams/#{dream_id}/archive?beta=true", nil, beta_headers(betas))
      BetaDream.from_json(response.body)
    end

    # Cancel a Dream that is still pending or running.
    def cancel(
      dream_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDream
      response = @client.post("/v1/dreams/#{dream_id}/cancel?beta=true", nil, beta_headers(betas))
      BetaDream.from_json(response.body)
    end
  end
end
