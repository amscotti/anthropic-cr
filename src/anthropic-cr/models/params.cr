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

    def initialize(
      @name : String,
      @description : String,
      @input_schema : InputSchema,
    )
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
    getter metadata : Hash(String, String)?

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
      @metadata : Hash(String, String)? = nil,
      @service_tier : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
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
    getter metadata : Hash(String, String)?

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
      @metadata : Hash(String, String)? = nil,
      @service_tier : String? = nil,
      @thinking : ThinkingConfig? = nil,
      @output_format : OutputFormat? = nil,
      @output_config : OutputConfig? = nil,
      @inference_geo : String? = nil,
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
