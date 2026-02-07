module Anthropic
  # Breakdown of cached tokens by TTL
  struct CacheCreation
    include JSON::Serializable

    @[JSON::Field(key: "ephemeral_1h_input_tokens")]
    getter ephemeral_1h_input_tokens : Int32

    @[JSON::Field(key: "ephemeral_5m_input_tokens")]
    getter ephemeral_5m_input_tokens : Int32

    def initialize(
      @ephemeral_1h_input_tokens : Int32 = 0,
      @ephemeral_5m_input_tokens : Int32 = 0,
    )
    end
  end

  # Server tool usage statistics
  struct ServerToolUsage
    include JSON::Serializable

    @[JSON::Field(key: "web_search_requests")]
    getter web_search_requests : Int32

    @[JSON::Field(key: "web_fetch_requests")]
    getter web_fetch_requests : Int32?

    def initialize(@web_search_requests : Int32 = 0, @web_fetch_requests : Int32? = nil)
    end
  end

  # Token usage statistics for API requests
  #
  # Tracks input and output tokens, as well as prompt caching statistics
  # when applicable.
  struct Usage
    include JSON::Serializable

    # Number of input tokens consumed
    @[JSON::Field(key: "input_tokens")]
    getter input_tokens : Int32

    # Number of output tokens generated
    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int32

    # Number of tokens written to the cache when creating a new entry
    @[JSON::Field(key: "cache_creation_input_tokens")]
    getter cache_creation_input_tokens : Int32?

    # Number of tokens read from the cache
    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int32?

    # Service tier used for the request
    @[JSON::Field(key: "service_tier")]
    getter service_tier : String?

    # Server tool usage statistics
    @[JSON::Field(key: "server_tool_use")]
    getter server_tool_use : ServerToolUsage?

    # Breakdown of cached tokens by TTL
    @[JSON::Field(key: "cache_creation")]
    getter cache_creation : CacheCreation?

    # Geographic region where inference was performed
    @[JSON::Field(key: "inference_geo")]
    getter inference_geo : String?
  end

  # Response from the token counting API
  #
  # ```
  # count = client.messages.count_tokens(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   messages: [{role: "user", content: "Hello, Claude!"}]
  # )
  # puts "This message would use #{count.input_tokens} input tokens"
  # ```
  struct TokenCountResponse
    include JSON::Serializable

    # Number of input tokens the request would consume
    @[JSON::Field(key: "input_tokens")]
    getter input_tokens : Int32

    # Number of tokens that would be written to cache (if using prompt caching)
    @[JSON::Field(key: "cache_creation_input_tokens")]
    getter cache_creation_input_tokens : Int32?

    # Number of tokens that would be read from cache (if using prompt caching)
    @[JSON::Field(key: "cache_read_input_tokens")]
    getter cache_read_input_tokens : Int32?

    def initialize(
      @input_tokens : Int32,
      @cache_creation_input_tokens : Int32? = nil,
      @cache_read_input_tokens : Int32? = nil,
    )
    end

    # Total billable tokens (considering cache pricing)
    def total_billable_tokens : Int32
      base = input_tokens
      base += (cache_creation_input_tokens || 0)
      base
    end
  end

  # Usage statistics for streaming delta events
  #
  # In streaming message_delta events, only output_tokens is provided
  # (input_tokens was already reported in message_start)
  struct DeltaUsage
    include JSON::Serializable

    # Number of output tokens generated
    @[JSON::Field(key: "output_tokens")]
    getter output_tokens : Int32
  end
end
