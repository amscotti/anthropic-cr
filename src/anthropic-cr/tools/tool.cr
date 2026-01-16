module Anthropic
  # Abstract base class for tools
  #
  # Tools allow Claude to use external functions during conversations.
  # Subclass this to create custom tools, or use the `Anthropic.tool` helper
  # for inline tool definitions.
  abstract class Tool
    # The name of the tool (used by Claude to identify it)
    abstract def name : String

    # Human-readable description of what the tool does
    abstract def description : String

    # JSON Schema properties describing the tool's input parameters
    abstract def input_schema_properties : Hash(String, Schema::Property)

    # Execute the tool with the given input (optional, for auto-execution)
    def call(input : JSON::Any) : String
      raise NotImplementedError.new("Tool#call must be implemented for auto-execution")
    end

    # Convert to ToolDefinition for API requests (recommended)
    def to_definition : ToolDefinition
      ToolDefinition.new(
        name: name,
        description: description,
        input_schema: InputSchema.build(
          properties: input_schema_properties,
          required: required_properties
        )
      )
    end

    # Override to specify which input properties are required
    def required_properties : Array(String)
      [] of String
    end
  end

  # Simple tool defined inline with blocks
  class InlineTool < Tool
    @name : String
    @description : String
    @schema : Hash(String, Schema::Property)
    @required : Array(String)
    @handler : Proc(JSON::Any, String)?

    def initialize(
      @name : String,
      @description : String,
      @schema : Hash(String, Schema::Property),
      @required : Array(String) = [] of String,
      &handler : JSON::Any -> String
    )
      @handler = handler
    end

    def name : String
      @name
    end

    def description : String
      @description
    end

    def input_schema_properties : Hash(String, Schema::Property)
      @schema
    end

    def required_properties : Array(String)
      @required
    end

    def call(input : JSON::Any) : String
      if handler = @handler
        handler.call(input)
      else
        raise NotImplementedError.new("No handler defined for tool #{name}")
      end
    end
  end

  # Helper method for creating inline tools with Schema DSL
  #
  # ```
  # weather_tool = Anthropic.tool(
  #   name: "get_weather",
  #   description: "Get current weather for a location",
  #   schema: {
  #     "location" => Schema.string("City name, e.g. San Francisco, CA"),
  #     "unit"     => Schema.enum("celsius", "fahrenheit", description: "Temperature unit"),
  #   },
  #   required: ["location"]
  # ) do |input|
  #   location = input["location"].as_s
  #   unit = input["unit"]?.try(&.as_s) || "fahrenheit"
  #   "The weather in #{location} is sunny and 72°#{unit == "celsius" ? "C" : "F"}."
  # end
  # ```
  def self.tool(
    name : String,
    description : String,
    schema : Hash(String, Schema::Property),
    required : Array(String) = [] of String,
    &handler : JSON::Any -> String
  ) : Tool
    InlineTool.new(name, description, schema, required, &handler)
  end

  # Typed tool with struct input (Ruby BaseTool-like pattern)
  #
  # Uses json-schema library to generate JSON Schema from Crystal structs.
  # The handler receives a typed struct instead of JSON::Any.
  #
  # ```
  # struct GetWeatherInput
  #   include JSON::Serializable
  #
  #   @[JSON::Field(description: "City name, e.g. San Francisco, CA")]
  #   getter location : String
  #
  #   @[JSON::Field(description: "Temperature unit")]
  #   getter unit : TemperatureUnit?
  # end
  #
  # enum TemperatureUnit
  #   Celsius
  #   Fahrenheit
  # end
  #
  # weather_tool = Anthropic.tool(
  #   name: "get_weather",
  #   description: "Get current weather for a location",
  #   input: GetWeatherInput
  # ) do |input|
  #   # input is GetWeatherInput, not JSON::Any!
  #   unit_str = input.unit.try(&.to_s.downcase) || "fahrenheit"
  #   "The weather in #{input.location} is sunny and 72°#{unit_str == "celsius" ? "C" : "F"}."
  # end
  # ```
  class TypedTool(T) < Tool
    @name : String
    @description : String
    @handler : Proc(T, String)
    @cached_schema : JSON::Any?

    def initialize(@name : String, @description : String, &handler : T -> String)
      @handler = handler
    end

    def name : String
      @name
    end

    def description : String
      @description
    end

    # Not used for TypedTool - we override to_definition instead
    def input_schema_properties : Hash(String, Schema::Property)
      {} of String => Schema::Property
    end

    # Override to_definition to use raw JSON schema from T.json_schema
    # This avoids parsing issues with json-schema library output
    def to_definition : ToolDefinition
      schema = get_processed_schema
      # Build InputSchema-compatible struct manually
      props_hash = schema["properties"]?.try(&.as_h) || {} of String => JSON::Any
      required_arr = schema["required"]?.try(&.as_a.map(&.as_s)) || [] of String

      # Convert JSON::Any properties to Schema::Property using a simpler approach
      properties = {} of String => Schema::Property
      props_hash.each do |key, value|
        properties[key] = json_to_property(value)
      end

      ToolDefinition.new(
        name: name,
        description: description,
        input_schema: InputSchema.build(
          properties: properties,
          required: required_arr
        )
      )
    end

    def call(input : JSON::Any) : String
      typed_input = T.from_json(input.to_json)
      @handler.call(typed_input)
    end

    private def get_processed_schema : JSON::Any
      @cached_schema ||= begin
        schema = JSON.parse(T.json_schema.to_json)
        SchemaTransform.add_additional_properties_false(schema)
      end
    end

    # Convert JSON::Any to Schema::Property
    private def json_to_property(json : JSON::Any) : Schema::Property
      hash = json.as_h? || {} of String => JSON::Any

      # Handle type - could be string or array (for nullable)
      type_value = hash["type"]?
      type_str = case type_value
                 when JSON::Any
                   if arr = type_value.as_a?
                     # Pick first non-null type
                     arr.find { |type| type.as_s? != "null" }.try(&.as_s) || "string"
                   else
                     type_value.as_s? || "string"
                   end
                 else
                   "string"
                 end

      Schema::Property.new(
        type: type_str,
        description: hash["description"]?.try(&.as_s),
        enum_values: hash["enum"]?.try(&.as_a.compact_map(&.as_s?)),
        items: hash["items"]?.try { |i| json_to_property(i) },
        properties: hash["properties"]?.try(&.as_h.transform_values { |v| json_to_property(v) }),
        required: hash["required"]?.try(&.as_a.map(&.as_s)),
        default: hash["default"]?,
        additional_properties: hash["additionalProperties"]?.try(&.as_bool?)
      )
    end
  end

  # Macro to create typed tools with struct input
  #
  # This provides Ruby BaseTool-like functionality where:
  # - Input schema is derived from a Crystal struct
  # - Handler receives typed struct instead of JSON::Any
  # - Field descriptions come from @[JSON::Field(description: "...")]
  #
  # ```
  # struct SearchInput
  #   include JSON::Serializable
  #   getter query : String
  #   getter category : Category?
  # end
  #
  # tool = Anthropic.tool(
  #   name: "search",
  #   description: "Search products",
  #   input: SearchInput
  # ) do |input|
  #   "Found results for #{input.query}"
  # end
  # ```
  macro tool(name, description, input, &block)
    Anthropic::TypedTool({{input}}).new({{name}}, {{description}}) {{block}}
  end
end
