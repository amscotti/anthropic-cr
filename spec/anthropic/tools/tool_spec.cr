require "../../spec_helper"

describe Anthropic::InlineTool do
  it "creates with name and description" do
    tool = Anthropic::InlineTool.new(
      name: "test_tool",
      description: "A test tool",
      schema: {} of String => Anthropic::Schema::Property
    ) { |_input| "result" }

    tool.name.should eq("test_tool")
    tool.description.should eq("A test tool")
  end

  it "creates with schema properties" do
    tool = Anthropic::InlineTool.new(
      name: "greet",
      description: "Greet a person",
      schema: {
        "name" => Anthropic::Schema.string("Person's name"),
      },
      required: ["name"]
    ) { |input| "Hello, #{input["name"].as_s}!" }

    tool.input_schema_properties.size.should eq(1)
    tool.input_schema_properties["name"].type.should eq("string")
    tool.required_properties.should eq(["name"])
  end

  it "executes handler with input" do
    tool = Anthropic::InlineTool.new(
      name: "add",
      description: "Add two numbers",
      schema: {
        "a" => Anthropic::Schema.integer("First number"),
        "b" => Anthropic::Schema.integer("Second number"),
      }
    ) do |input|
      a = input["a"].as_i
      b = input["b"].as_i
      (a + b).to_s
    end

    input = JSON.parse(%({"a": 5, "b": 3}))
    tool.call(input).should eq("8")
  end

  describe "#to_definition" do
    it "converts to ToolDefinition" do
      tool = Anthropic::InlineTool.new(
        name: "get_time",
        description: "Get current time",
        schema: {
          "timezone" => Anthropic::Schema.string("Timezone name"),
        },
        required: ["timezone"]
      ) { |_input| "12:00 PM" }

      definition = tool.to_definition
      definition.name.should eq("get_time")
      definition.description.should eq("Get current time")
      definition.input_schema.properties["timezone"].type.should eq("string")
      definition.input_schema.required.should eq(["timezone"])
    end
  end
end

describe "Anthropic.tool" do
  it "creates an InlineTool" do
    tool = Anthropic.tool(
      name: "echo",
      description: "Echo input back",
      schema: {
        "message" => Anthropic::Schema.string("Message to echo"),
      },
      required: ["message"]
    ) do |input|
      input["message"].as_s
    end

    tool.should be_a(Anthropic::Tool)
    tool.name.should eq("echo")
    tool.description.should eq("Echo input back")
  end

  it "creates executable tool" do
    tool = Anthropic.tool(
      name: "reverse",
      description: "Reverse a string",
      schema: {
        "text" => Anthropic::Schema.string("Text to reverse"),
      }
    ) do |input|
      input["text"].as_s.reverse
    end

    input = JSON.parse(%({"text": "hello"}))
    tool.call(input).should eq("olleh")
  end
end

describe Anthropic::TypedTool do
  it "creates with typed input" do
    tool = Anthropic::TypedTool(TypedToolTestInput).new(
      "calculate",
      "Calculate sum"
    ) do |input|
      (input.a + input.b).to_s
    end

    tool.name.should eq("calculate")
    tool.description.should eq("Calculate sum")
  end

  it "executes with typed input" do
    tool = Anthropic::TypedTool(TypedToolTestInput).new(
      "calculate",
      "Calculate sum"
    ) do |input|
      (input.a + input.b).to_s
    end

    input = JSON.parse(%({"a": 10, "b": 20}))
    tool.call(input).should eq("30")
  end

  describe "#to_definition" do
    it "generates definition from struct schema" do
      tool = Anthropic::TypedTool(TypedToolTestInput).new(
        "calculate",
        "Calculate sum"
      ) do |input|
        (input.a + input.b).to_s
      end

      definition = tool.to_definition
      definition.name.should eq("calculate")
      definition.description.should eq("Calculate sum")
      # The properties should be derived from the struct
      definition.input_schema.properties.has_key?("a").should be_true
      definition.input_schema.properties.has_key?("b").should be_true
    end
  end
end

describe "Anthropic.tool macro with typed input" do
  it "creates TypedTool" do
    tool = Anthropic.tool(
      name: "typed_calc",
      description: "Typed calculation",
      input: TypedToolTestInput
    ) do |input|
      (input.a * input.b).to_s
    end

    tool.should be_a(Anthropic::TypedTool(TypedToolTestInput))
    tool.name.should eq("typed_calc")
  end

  it "executes with typed input" do
    tool = Anthropic.tool(
      name: "multiply",
      description: "Multiply numbers",
      input: TypedToolTestInput
    ) do |input|
      (input.a * input.b).to_s
    end

    input = JSON.parse(%({"a": 6, "b": 7}))
    tool.call(input).should eq("42")
  end
end

describe Anthropic::ToolDefinition do
  describe "strict field" do
    it "serializes strict: true" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")},
          required: ["x"]
        ),
        strict: true
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["strict"].as_bool.should be_true
    end

    it "omits strict when nil" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        )
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["strict"]?.should be_nil
    end
  end

  describe "type field" do
    it "omits type by default (matches Ruby SDK)" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        )
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["type"]?.should be_nil
    end

    it "serializes type when explicitly set" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        type: "custom"
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["type"].as_s.should eq("custom")
    end
  end

  describe "allowed_callers field" do
    it "serializes allowed_callers when set" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        allowed_callers: ["code_execution_20250825"]
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["allowed_callers"].as_a.map(&.as_s).should eq(["code_execution_20250825"])
    end

    it "omits allowed_callers when nil" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        )
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["allowed_callers"]?.should be_nil
    end
  end

  describe "defer_loading field" do
    it "serializes defer_loading when set" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        defer_loading: true
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["defer_loading"].as_bool.should be_true
    end
  end

  describe "input_examples field" do
    it "serializes input_examples when set" do
      examples = [JSON.parse(%({"x": "example_value"}))]
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        input_examples: examples
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["input_examples"].as_a.size.should eq(1)
      parsed["input_examples"][0]["x"].as_s.should eq("example_value")
    end
  end

  describe "eager_input_streaming field" do
    it "serializes eager_input_streaming when set" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        eager_input_streaming: true
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["eager_input_streaming"].as_bool.should be_true
    end
  end

  describe "cache_control field" do
    it "serializes cache_control when set" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        ),
        cache_control: Anthropic::CacheControl.ephemeral
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["cache_control"]["type"].as_s.should eq("ephemeral")
    end

    it "omits cache_control when nil" do
      definition = Anthropic::ToolDefinition.new(
        name: "test",
        description: "A test tool",
        input_schema: Anthropic::InputSchema.build(
          properties: {"x" => Anthropic::Schema.string("A value")}
        )
      )

      json = definition.to_json
      parsed = JSON.parse(json)
      parsed["cache_control"]?.should be_nil
    end
  end
end

describe Anthropic::InlineTool do
  describe "cache_control" do
    it "passes cache_control through to definition" do
      tool = Anthropic::InlineTool.new(
        name: "cached_tool",
        description: "A cached tool",
        schema: {"x" => Anthropic::Schema.string("A value")},
        cache_control: Anthropic::CacheControl.ephemeral
      ) { |_input| "result" }

      tool.cache_control.should_not be_nil
      definition = tool.to_definition
      definition.cache_control.should_not be_nil
      definition.cache_control.not_nil!.type.should eq("ephemeral")
    end
  end
end

# Test input struct
struct TypedToolTestInput
  include JSON::Serializable

  getter a : Int32
  getter b : Int32
end
