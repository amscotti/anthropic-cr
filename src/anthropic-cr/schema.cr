module Anthropic
  # Schema DSL for type-safe tool input definitions
  #
  # Provides a cleaner way to define tool input schemas.
  #
  # ```
  # schema: {
  #   "location" => Schema.string("City name"),
  #   "unit"     => Schema.enum("celsius", "fahrenheit"),
  # }
  # ```
  module Schema
    # Property definition that converts to JSON Schema
    # Note: This is a class (not struct) because it can contain recursive references
    # (e.g., array items or nested object properties)
    class Property
      include JSON::Serializable

      getter type : String
      @[JSON::Field(emit_null: false)]
      getter description : String?
      @[JSON::Field(key: "enum", emit_null: false)]
      getter enum_values : Array(String)?
      @[JSON::Field(emit_null: false)]
      getter items : Property?
      @[JSON::Field(emit_null: false)]
      getter properties : Hash(String, Property)?
      @[JSON::Field(emit_null: false)]
      getter required : Array(String)?
      @[JSON::Field(emit_null: false)]
      getter default : JSON::Any?
      @[JSON::Field(emit_null: false)]
      getter minimum : Float64?
      @[JSON::Field(emit_null: false)]
      getter maximum : Float64?
      @[JSON::Field(key: "minLength", emit_null: false)]
      getter min_length : Int32?
      @[JSON::Field(key: "maxLength", emit_null: false)]
      getter max_length : Int32?
      @[JSON::Field(key: "minItems", emit_null: false)]
      getter min_items : Int32?
      @[JSON::Field(key: "maxItems", emit_null: false)]
      getter max_items : Int32?
      @[JSON::Field(emit_null: false)]
      getter pattern : String?

      @[JSON::Field(key: "additionalProperties", emit_null: false)]
      getter additional_properties : Bool?

      def initialize(
        @type : String,
        @description : String? = nil,
        @enum_values : Array(String)? = nil,
        @items : Property? = nil,
        @properties : Hash(String, Property)? = nil,
        @required : Array(String)? = nil,
        @default : JSON::Any? = nil,
        @minimum : Float64? = nil,
        @maximum : Float64? = nil,
        @min_length : Int32? = nil,
        @max_length : Int32? = nil,
        @min_items : Int32? = nil,
        @max_items : Int32? = nil,
        @pattern : String? = nil,
        @additional_properties : Bool? = nil,
      )
      end
    end

    # Define a string property
    #
    # ```
    # Schema.string("User's name")
    # Schema.string("Email", pattern: "^[a-z]+@[a-z]+\\.[a-z]+$")
    # ```
    def self.string(
      description : String? = nil,
      min_length : Int32? = nil,
      max_length : Int32? = nil,
      pattern : String? = nil,
      default : String? = nil,
    ) : Property
      Property.new(
        type: "string",
        description: description,
        min_length: min_length,
        max_length: max_length,
        pattern: pattern,
        default: default ? JSON::Any.new(default) : nil
      )
    end

    # Define a number property (floating point)
    #
    # ```
    # Schema.number("Temperature in degrees")
    # Schema.number("Price", minimum: 0.0, maximum: 1000.0)
    # ```
    def self.number(
      description : String? = nil,
      minimum : Float64? = nil,
      maximum : Float64? = nil,
      default : Float64? = nil,
    ) : Property
      Property.new(
        type: "number",
        description: description,
        minimum: minimum,
        maximum: maximum,
        default: default ? JSON::Any.new(default) : nil
      )
    end

    # Define an integer property
    #
    # ```
    # Schema.integer("Number of items")
    # Schema.integer("Age", minimum: 0, maximum: 150)
    # ```
    def self.integer(
      description : String? = nil,
      minimum : Int32? = nil,
      maximum : Int32? = nil,
      default : Int32? = nil,
    ) : Property
      Property.new(
        type: "integer",
        description: description,
        minimum: minimum.try(&.to_f64),
        maximum: maximum.try(&.to_f64),
        default: default ? JSON::Any.new(default.to_i64) : nil
      )
    end

    # Define a boolean property
    #
    # ```
    # Schema.boolean("Is active")
    # Schema.boolean("Enabled", default: true)
    # ```
    def self.boolean(
      description : String? = nil,
      default : Bool? = nil,
    ) : Property
      Property.new(
        type: "boolean",
        description: description,
        default: default.nil? ? nil : JSON::Any.new(default)
      )
    end

    # Define an enum property with allowed string values
    #
    # ```
    # Schema.enum("celsius", "fahrenheit", description: "Temperature unit")
    # Schema.enum("low", "medium", "high")
    # ```
    def self.enum(
      *values : String,
      description : String? = nil,
      default : String? = nil,
    ) : Property
      Property.new(
        type: "string",
        description: description,
        enum_values: values.to_a,
        default: default ? JSON::Any.new(default) : nil
      )
    end

    # Define an array property
    #
    # ```
    # Schema.array(Schema.string, description: "List of names")
    # Schema.array(Schema.integer, min_items: 1, max_items: 10)
    # ```
    def self.array(
      items : Property,
      description : String? = nil,
      min_items : Int32? = nil,
      max_items : Int32? = nil,
    ) : Property
      Property.new(
        type: "array",
        description: description,
        items: items,
        min_items: min_items,
        max_items: max_items
      )
    end

    # Define an object property with nested properties
    #
    # ```
    # Schema.object({
    #   "name" => Schema.string("Person's name"),
    #   "age"  => Schema.integer("Person's age"),
    # }, required: ["name"])
    # ```
    def self.object(
      properties : Hash(String, Property),
      description : String? = nil,
      required : Array(String) = [] of String,
    ) : Property
      Property.new(
        type: "object",
        description: description,
        properties: properties,
        required: required.empty? ? nil : required,
        additional_properties: false
      )
    end
  end

  # Base class for output schemas (both manual and typed)
  abstract class BaseOutputSchema
    abstract def to_output_format : OutputFormat
  end

  # Helper module for JSON schema transformations
  module SchemaTransform
    extend self

    # Recursively add additionalProperties: false to all object types
    # Required by Anthropic's structured outputs API
    def add_additional_properties_false(schema : JSON::Any) : JSON::Any
      return schema unless schema.as_h?

      hash = schema.as_h.dup

      # If this is an object type, add additionalProperties: false
      if hash["type"]?.try(&.as_s?) == "object"
        hash["additionalProperties"] = JSON::Any.new(false)
      end

      # Recursively process properties
      if props = hash["properties"]?.try(&.as_h?)
        new_props = {} of String => JSON::Any
        props.each do |key, value|
          new_props[key] = add_additional_properties_false(value)
        end
        hash["properties"] = JSON::Any.new(new_props)
      end

      # Recursively process array items
      if items = hash["items"]?
        hash["items"] = add_additional_properties_false(items)
      end

      # Recursively process $defs/definitions
      {"$defs", "definitions"}.each do |def_key|
        if defs = hash[def_key]?.try(&.as_h?)
          new_defs = {} of String => JSON::Any
          defs.each do |key, value|
            new_defs[key] = add_additional_properties_false(value)
          end
          hash[def_key] = JSON::Any.new(new_defs)
        end
      end

      JSON::Any.new(hash)
    end
  end

  # Output schema for structured outputs
  #
  # Defines the expected structure of Claude's response using JSON Schema.
  # When provided, Claude will output JSON matching the schema.
  #
  # ```
  # output_schema = OutputSchema.new(
  #   name: "analysis_result",
  #   schema: {
  #     "summary" => Schema.string("Brief summary"),
  #     "score"   => Schema.number("Confidence score", minimum: 0.0, maximum: 1.0),
  #     "tags"    => Schema.array(Schema.string, description: "Relevant tags"),
  #   },
  #   required: ["summary", "score"]
  # )
  # ```
  class OutputSchema < BaseOutputSchema
    getter name : String
    getter description : String?
    getter schema : Hash(String, Schema::Property)
    getter required : Array(String)

    def initialize(
      @name : String,
      @schema : Hash(String, Schema::Property),
      @description : String? = nil,
      @required : Array(String) = [] of String,
    )
    end

    # Convert to OutputFormat for API requests
    def to_output_format : OutputFormat
      # Build schema as InputSchema, then parse to JSON::Any
      schema_struct = InputSchema.new(
        properties: @schema,
        required: @required.empty? ? nil : @required
      )
      OutputFormat.new(JSON.parse(schema_struct.to_json))
    end
  end

  # Convenience method to create an output schema
  #
  # ```
  # output = Anthropic.output_schema(
  #   name: "weather_report",
  #   schema: {
  #     "temperature" => Schema.number("Current temperature"),
  #     "conditions"  => Schema.string("Weather conditions"),
  #   },
  #   required: ["temperature", "conditions"]
  # )
  # ```
  def self.output_schema(
    name : String,
    schema : Hash(String, Schema::Property),
    description : String? = nil,
    required : Array(String) = [] of String,
  ) : OutputSchema
    OutputSchema.new(name, schema, description, required)
  end

  # Typed output schema derived from a Crystal struct
  #
  # Uses json-schema library to generate JSON Schema from Crystal structs.
  # This enables Ruby BaseModel-like pattern for structured outputs.
  #
  # ```
  # struct FamousNumber
  #   include JSON::Serializable
  #   getter value : Float64
  #   getter reason : String?
  # end
  #
  # struct AnalysisResult
  #   include JSON::Serializable
  #   getter numbers : Array(FamousNumber)
  #   getter summary : String
  # end
  #
  # # Create output schema from struct
  # output_schema = Anthropic.output_schema(
  #   type: AnalysisResult,
  #   name: "analysis_result"
  # )
  #
  # # Use with beta API
  # message = client.beta.messages.create(
  #   betas: [Anthropic::STRUCTURED_OUTPUT_BETA],
  #   output_schema: output_schema,
  #   ...
  # )
  #
  # # Parse response directly to typed struct
  # text_block = message.content.find(&.is_a?(Anthropic::TextContent))
  # json_text = text_block.as(Anthropic::TextContent).text
  # result = AnalysisResult.from_json(json_text)
  # result.numbers.each { |n| puts n.value }
  # ```
  class TypedOutputSchema(T) < BaseOutputSchema
    getter name : String
    getter description : String?

    def initialize(@name : String, @description : String? = nil)
    end

    # Convert to OutputFormat for API requests
    def to_output_format : OutputFormat
      schema = JSON.parse(T.json_schema.to_json)
      processed = SchemaTransform.add_additional_properties_false(schema)
      OutputFormat.new(processed)
    end
  end

  # Macro to create a typed output schema from a struct
  #
  # ```
  # struct MyOutput
  #   include JSON::Serializable
  #   getter result : String
  #   getter confidence : Float64
  # end
  #
  # schema = Anthropic.output_schema(type: MyOutput, name: "my_output")
  # ```
  macro output_schema(type, name, description = nil)
    Anthropic::TypedOutputSchema({{type}}).new({{name}}, {{description}})
  end
end
