module Anthropic
  class Models
    def initialize(@client : Client)
    end

    # List all available models
    #
    # Returns a paginated list of all Claude models available to your account.
    #
    # ```
    # client = Anthropic::Client.new
    # response = client.models.list
    # response.data.each do |model|
    #   puts "#{model.display_name} (#{model.id})"
    # end
    # ```
    def list(
      after_id : String? = nil,
      before_id : String? = nil,
      limit : Int32 = 20,
      lifecycle : Array(String)? = nil,
      workspace_id : String? = nil,
    ) : ModelListResponse
      params = {} of String => String | Array(String)
      params["limit"] = limit.to_s
      params["after_id"] = after_id if after_id
      params["before_id"] = before_id if before_id
      params["lifecycle"] = lifecycle if lifecycle

      response = @client.get("/v1/models", params, Anthropic.merge_workspace_header(nil, workspace_id))
      ModelListResponse.from_json(response.body)
    end

    # Retrieve specific model information
    #
    # Returns detailed information about a specific Claude model.
    #
    # ```
    # client = Anthropic::Client.new
    # model = client.models.retrieve("claude-sonnet-4-6")
    # puts model.display_name
    # ```
    def retrieve(
      model_id : String,
      workspace_id : String? = nil,
    ) : ModelInfo
      encoded_id = Anthropic.encode_path_segment(model_id)
      response = @client.get("/v1/models/#{encoded_id}", nil, Anthropic.merge_workspace_header(nil, workspace_id))
      ModelInfo.from_json(response.body)
    end
  end

  class BetaModels
    def initialize(@client : Client)
    end

    def list(
      after_id : String? = nil,
      before_id : String? = nil,
      limit : Int32 = 20,
      lifecycle : Array(String)? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaModelListResponse
      params = {} of String => String | Array(String)
      params["limit"] = limit.to_s
      params["after_id"] = after_id if after_id
      params["before_id"] = before_id if before_id
      params["lifecycle"] = lifecycle if lifecycle

      response = @client.get("/v1/models", params, beta_headers(betas, workspace_id), beta: true)
      BetaModelListResponse.from_json(response.body)
    end

    def retrieve(
      model_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : ModelInfo
      encoded_id = Anthropic.encode_path_segment(model_id)
      response = @client.get("/v1/models/#{encoded_id}", nil, beta_headers(betas, workspace_id), beta: true)
      ModelInfo.from_json(response.body)
    end

    private def beta_headers(betas : Array(String), workspace_id : String? = nil) : Hash(String, String)?
      base = betas.empty? ? nil : {"anthropic-beta" => betas.join(",")}
      Anthropic.merge_workspace_header(base, workspace_id)
    end
  end

  # Response from listing models
  #
  # Contains a paginated array of ModelInfo objects along with pagination metadata.
  struct ModelListResponse
    include JSON::Serializable

    # Array of model information objects
    getter data : Array(ModelInfo)

    # Whether there are more models available
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    # ID of the first model in this page
    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    # ID of the last model in this page
    @[JSON::Field(key: "last_id")]
    getter last_id : String?

    # Iteration helper to iterate over models in the data array
    #
    # ```
    # response.each do |model|
    #   puts model.display_name
    # end
    # ```
    def each(&)
      data.each { |model| yield model }
    end

    # Auto-paginate through all models (if paginated)
    #
    # Returns an array of all models across all pages
    #
    # ```
    # all_models = client.models.list.auto_paging_all(client)
    # all_models.each do |model|
    #   puts model.display_name
    # end
    # ```
    def auto_paging_all(client : Client) : Array(ModelInfo)
      results = data.dup
      current_response = self

      while current_response.has_more? && (last = current_response.last_id)
        current_response = Models.new(client).list(after_id: last)
        results.concat(current_response.data)
      end

      results
    end
  end

  struct BetaModelListResponse
    include JSON::Serializable

    getter data : Array(ModelInfo)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?

    def each(&)
      data.each { |model| yield model }
    end

    def auto_paging_all(client : Client, betas : Array(String) = [] of String) : Array(ModelInfo)
      results = data.dup
      current_response = self

      while current_response.has_more? && (last = current_response.last_id)
        current_response = BetaModels.new(client).list(after_id: last, betas: betas)
        results.concat(current_response.data)
      end

      results
    end
  end
end
