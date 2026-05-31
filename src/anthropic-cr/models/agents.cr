require "json"

module Anthropic
  # Stateful Managed Agent returned by the Agents API (beta)
  struct BetaAgent
    include JSON::Serializable

    # Unique agent identifier
    getter id : String

    # Human-readable name for the agent
    getter name : String

    # Type of resource (always "agent")
    getter type : String = "agent"

    # Current version number of the agent configuration
    getter version : Int32

    # Description of what the agent does
    getter description : String?

    # Arbitrary key-value metadata attached to the agent
    getter metadata : Hash(String, String)?

    # Model configuration (e.g. model ID and parameters)
    getter model : JSON::Any

    # Coordinator topology configurations for multiagent settings
    getter multiagent : JSON::Any?

    # MCP servers this agent connects to
    @[JSON::Field(key: "mcp_servers")]
    getter mcp_servers : Array(JSON::Any)?

    # Skills available to the agent
    getter skills : Array(JSON::Any)?

    # System prompt for the agent
    @[JSON::Field(key: "system")]
    getter system_ : String?

    # Tool configurations available to the agent
    getter tools : Array(JSON::Any)?

    # Timestamp when the agent was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Timestamp when the agent was last updated
    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Timestamp when the agent was archived, or nil if active
    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  # Response for listing agents
  struct BetaAgentListResponse
    include JSON::Serializable

    # Array of retrieved agents
    getter data : Array(BetaAgent)

    # Whether there are more pages available
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?
  end
end
