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

# Test input struct
struct TypedToolTestInput
  include JSON::Serializable

  getter a : Int32
  getter b : Int32
end
