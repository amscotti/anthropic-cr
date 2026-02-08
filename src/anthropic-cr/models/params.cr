module Anthropic
  # JSON Schema for tool input parameters
  #
  # Wraps a properties hash in the required object structure for the API.
  #
  # ```
  # schema = InputSchema.new(
  #   properties: {
  #     "location" => Schema.string("City name"),
  #     "unit"     => Schema.enum("celsius", "fahrenheit"),
  #   },
  #   required: ["location"]
  # )
  # ```
  struct InputSchema
    include JSON::Serializable

    getter type : String = "object"
    getter properties : Hash(String, Schema::Property)

    @[JSON::Field(emit_null: false)]
    getter required : Array(String)?

    @[JSON::Field(key: "additionalProperties")]
    getter? additional_properties : Bool = false

    def initialize(
      @properties : Hash(String, Schema::Property),
      @required : Array(String)? = nil,
      @additional_properties : Bool = false,
    )
    end

    # Create from a Hash(String, Schema::Property) with required fields
    def self.build(
      properties : Hash(String, Schema::Property),
      required : Array(String) = [] of String,
    ) : self
      new(
        properties: properties,
        required: required.empty? ? nil : required
      )
    end
  end

  # Tool definition for API requests
  #
  # Represents a tool in the format expected by the Anthropic API.
  #
  # ```
  # definition = ToolDefinition.new(
  #   name: "get_weather",
  #   description: "Get weather for a location",
  #   input_schema: InputSchema.build(
  #     properties: {"location" => Schema.string("City name")},
  #     required: ["location"]
  #   )
  # )
  # ```
  struct ToolDefinition
    include JSON::Serializable

    getter name : String
    getter description : String

    @[JSON::Field(key: "input_schema")]
    getter input_schema : InputSchema

    @[JSON::Field(emit_null: false)]
    getter type : String?

    @[JSON::Field(emit_null: false)]
    getter strict : Bool?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    @[JSON::Field(key: "allowed_callers", emit_null: false)]
    getter allowed_callers : Array(String)?

    @[JSON::Field(key: "defer_loading", emit_null: false)]
    getter? defer_loading : Bool?

    @[JSON::Field(key: "input_examples", emit_null: false)]
    getter input_examples : Array(JSON::Any)?

    @[JSON::Field(key: "eager_input_streaming", emit_null: false)]
    getter eager_input_streaming : Bool?

    def initialize(
      @name : String,
      @description : String,
      @input_schema : InputSchema,
      @type : String? = nil,
      @strict : Bool? = nil,
      @cache_control : CacheControl? = nil,
      @allowed_callers : Array(String)? = nil,
      @defer_loading : Bool? = nil,
      @input_examples : Array(JSON::Any)? = nil,
      @eager_input_streaming : Bool? = nil,
    )
    end
  end

  # Metadata for message requests
  #
  # ```
  # metadata = Anthropic::Metadata.new(user_id: "user-123")
  # ```
  struct Metadata
    include JSON::Serializable

    @[JSON::Field(key: "user_id", emit_null: false)]
    getter user_id : String?

    def initialize(@user_id : String? = nil)
    end
  end

  # Request parameters for messages.create()
  #
  # Typed struct that serializes directly to JSON for API requests.
  # Replaces the verbose Hash(String, JSON::Any) pattern.
  #
  # ```
  # params = MessageCreateParams.new(
  #   model: "claude-sonnet-4-5-20250929",
  #   max_tokens: 1024,
  #   messages: [MessageParam.user("Hello!")],
  #   stream: false
  # )
  # body_json = params.to_json
  # ```
  struct MessageCreateParams
    include JSON::Serializable

    getter model : String

    @[JSON::Field(key: "max_tokens")]
    getter max_tokens : Int32

    getter messages : Array(MessageParam)

    @[JSON::Field(emit_null: false)]
    getter stream : Bool?

    @[JSON::Field(emit_null: false)]
    getter system : SystemPrompt?

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
    getter thinking : ThinkingConfig?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String?

    def initialize(
      @model : String,
      @max_tokens : Int32,
      @messages : Array(MessageParam),
      @stream : Bool? = nil,
      @system : SystemPrompt? = nil,
      @temperature : Float64? = nil,
      @top_p : Float64? = nil,
      @top_k : Int32? = nil,
      @tools : Array(ToolDefinition | ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Metadata? = nil,
      @service_tier : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
    )
    end
  end

  # Context management edit: compact conversation history
  struct CompactEdit
    include JSON::Serializable

    getter type : String = "compact_20260112"

    @[JSON::Field(emit_null: false)]
    getter instructions : String?

    @[JSON::Field(emit_null: false)]
    getter trigger : String?

    @[JSON::Field(key: "pause_after_compaction", emit_null: false)]
    getter pause_after_compaction : Bool?

    def initialize(
      @instructions : String? = nil,
      @trigger : String? = nil,
      @pause_after_compaction : Bool? = nil,
    )
    end
  end

  # Context management edit: clear tool use/result pairs
  struct ClearToolUsesEdit
    include JSON::Serializable

    getter type : String = "clear_tool_uses_20250919"

    @[JSON::Field(key: "exclude_tools", emit_null: false)]
    getter exclude_tools : Array(String)?

    def initialize(@exclude_tools : Array(String)? = nil)
    end
  end

  # Context management edit: clear thinking blocks
  struct ClearThinkingEdit
    include JSON::Serializable

    getter type : String = "clear_thinking_20251015"

    def initialize
    end
  end

  alias ContextManagementEdit = CompactEdit | ClearToolUsesEdit | ClearThinkingEdit

  # Context management configuration for beta messages
  #
  # ```
  # config = Anthropic::ContextManagementConfig.auto_compact
  # ```
  struct ContextManagementConfig
    include JSON::Serializable

    getter edits : Array(ContextManagementEdit)

    def initialize(@edits : Array(ContextManagementEdit))
    end

    # Create a config with auto-compaction using default threshold
    def self.auto_compact(
      instructions : String? = nil,
      trigger : String? = nil,
      pause_after_compaction : Bool? = nil,
    ) : self
      new(edits: [CompactEdit.new(
        instructions: instructions,
        trigger: trigger,
        pause_after_compaction: pause_after_compaction,
      )] of ContextManagementEdit)
    end
  end

  # Container skill configuration for skills-based tool use
  struct ContainerSkill
    include JSON::Serializable

    getter type : String = "anthropic"

    @[JSON::Field(key: "skill_id")]
    getter skill_id : String

    @[JSON::Field(emit_null: false)]
    getter version : String?

    def initialize(@skill_id : String, @type : String = "anthropic", @version : String? = nil)
    end
  end

  # Container configuration for skills
  struct ContainerConfig
    include JSON::Serializable

    getter skills : Array(ContainerSkill)

    def initialize(@skills : Array(ContainerSkill))
    end
  end

  # MCP tool configuration for mcp_servers parameter
  struct MCPToolConfiguration
    include JSON::Serializable

    @[JSON::Field(key: "allowed_tools", emit_null: false)]
    getter allowed_tools : Array(String)?

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    def initialize(@allowed_tools : Array(String)? = nil, @enabled : Bool? = nil)
    end
  end

  # MCP server definition for mcp_servers parameter
  struct MCPServerDefinition
    include JSON::Serializable

    getter type : String = "url"
    getter url : String
    getter name : String

    @[JSON::Field(key: "authorization_token", emit_null: false)]
    getter authorization_token : String?

    @[JSON::Field(key: "tool_configuration", emit_null: false)]
    getter tool_configuration : MCPToolConfiguration?

    def initialize(
      @url : String,
      @name : String,
      @authorization_token : String? = nil,
      @tool_configuration : MCPToolConfiguration? = nil,
    )
    end
  end

  # Beta message create params - extends MessageCreateParams with output_schema
  struct BetaMessageCreateParams
    include JSON::Serializable

    getter model : String

    @[JSON::Field(key: "max_tokens")]
    getter max_tokens : Int32

    getter messages : Array(MessageParam)

    @[JSON::Field(emit_null: false)]
    getter stream : Bool?

    @[JSON::Field(emit_null: false)]
    getter system : SystemPrompt?

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
    getter thinking : ThinkingConfig?

    @[JSON::Field(key: "output_format", emit_null: false)]
    getter output_format : OutputFormat?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String?

    @[JSON::Field(key: "context_management", emit_null: false)]
    getter context_management : ContextManagementConfig?

    @[JSON::Field(emit_null: false)]
    getter container : ContainerConfig?

    @[JSON::Field(key: "mcp_servers", emit_null: false)]
    getter mcp_servers : Array(MCPServerDefinition)?

    def initialize(
      @model : String,
      @max_tokens : Int32,
      @messages : Array(MessageParam),
      @stream : Bool? = nil,
      @system : SystemPrompt? = nil,
      @temperature : Float64? = nil,
      @top_p : Float64? = nil,
      @top_k : Int32? = nil,
      @tools : Array(ToolDefinition | ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @stop_sequences : Array(String)? = nil,
      @metadata : Metadata? = nil,
      @service_tier : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_format : OutputFormat? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
      @context_management : ContextManagementConfig? = nil,
      @container : ContainerConfig? = nil,
      @mcp_servers : Array(MCPServerDefinition)? = nil,
    )
    end
  end

  # Token count request parameters
  struct TokenCountParams
    include JSON::Serializable

    getter model : String
    getter messages : Array(MessageParam)

    @[JSON::Field(emit_null: false)]
    getter system : SystemPrompt?

    @[JSON::Field(emit_null: false)]
    getter tools : Array(ToolDefinition | ServerTool)?

    @[JSON::Field(key: "tool_choice", emit_null: false)]
    getter tool_choice : ToolChoice?

    @[JSON::Field(emit_null: false)]
    getter thinking : ThinkingConfig?

    @[JSON::Field(key: "output_config", emit_null: false)]
    getter output_config : OutputConfig?

    @[JSON::Field(key: "inference_geo", emit_null: false)]
    getter inference_geo : String?

    def initialize(
      @model : String,
      @messages : Array(MessageParam),
      @system : SystemPrompt? = nil,
      @tools : Array(ToolDefinition | ServerTool)? = nil,
      @tool_choice : ToolChoice? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
    )
    end
  end

  # Type alias for system prompt - can be string or array of text content
  alias SystemPrompt = String | Array(TextContent)

  # Output configuration for controlling effort and format
  #
  # ```
  # # Set effort level
  # output_config = Anthropic::OutputConfig.new(effort: "high")
  #
  # # Set effort + structured output format
  # output_config = Anthropic::OutputConfig.new(effort: "high", format: output_format)
  # ```
  struct OutputConfig
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter effort : String?

    @[JSON::Field(emit_null: false)]
    getter format : OutputFormat?

    def initialize(@effort : String? = nil, @format : OutputFormat? = nil)
    end
  end

  # Output format for structured outputs (beta)
  #
  # The API only accepts `type` and `schema` fields.
  # The schema itself should be a JSON Schema object.
  struct OutputFormat
    include JSON::Serializable

    getter type : String = "json_schema"
    getter schema : JSON::Any

    def initialize(@schema : JSON::Any)
    end

    # Create from a BaseOutputSchema
    def self.from_output_schema(output_schema : BaseOutputSchema) : self
      output_schema.to_output_format
    end
  end
end
