require "../spec_helper"

describe Anthropic::Schema do
  describe ".string" do
    it "creates string property" do
      prop = Anthropic::Schema.string("A description")
      prop.type.should eq("string")
      prop.description.should eq("A description")
    end

    it "supports min/max length" do
      prop = Anthropic::Schema.string(min_length: 1, max_length: 100)
      prop.min_length.should eq(1)
      prop.max_length.should eq(100)
    end

    it "supports pattern" do
      prop = Anthropic::Schema.string(pattern: "^[a-z]+$")
      prop.pattern.should eq("^[a-z]+$")
    end

    it "supports default" do
      prop = Anthropic::Schema.string(default: "hello")
      prop.default.should eq(JSON::Any.new("hello"))
    end
  end

  describe ".number" do
    it "creates number property" do
      prop = Anthropic::Schema.number("A number")
      prop.type.should eq("number")
      prop.description.should eq("A number")
    end

    it "supports min/max" do
      prop = Anthropic::Schema.number(minimum: 0.0, maximum: 100.0)
      prop.minimum.should eq(0.0)
      prop.maximum.should eq(100.0)
    end
  end

  describe ".integer" do
    it "creates integer property" do
      prop = Anthropic::Schema.integer("An integer")
      prop.type.should eq("integer")
    end

    it "converts min/max to float" do
      prop = Anthropic::Schema.integer(minimum: 0, maximum: 100)
      prop.minimum.should eq(0.0)
      prop.maximum.should eq(100.0)
    end
  end

  describe ".boolean" do
    it "creates boolean property" do
      prop = Anthropic::Schema.boolean("A flag")
      prop.type.should eq("boolean")
    end

    it "supports default" do
      prop = Anthropic::Schema.boolean(default: true)
      prop.default.should eq(JSON::Any.new(true))
    end
  end

  describe ".enum" do
    it "creates enum property" do
      prop = Anthropic::Schema.enum("a", "b", "c")
      prop.type.should eq("string")
      prop.enum_values.should eq(["a", "b", "c"])
    end

    it "supports description" do
      prop = Anthropic::Schema.enum("low", "high", description: "Priority level")
      prop.description.should eq("Priority level")
    end
  end

  describe ".array" do
    it "creates array property" do
      items = Anthropic::Schema.string
      prop = Anthropic::Schema.array(items, description: "List of names")
      prop.type.should eq("array")
      prop.items.should_not be_nil
      prop.items.not_nil!.type.should eq("string")
    end

    it "supports min/max items" do
      items = Anthropic::Schema.string
      prop = Anthropic::Schema.array(items, min_items: 1, max_items: 10)
      prop.min_items.should eq(1)
      prop.max_items.should eq(10)
    end
  end

  describe ".object" do
    it "creates object property" do
      props = {
        "name" => Anthropic::Schema.string("Name"),
        "age"  => Anthropic::Schema.integer("Age"),
      }
      prop = Anthropic::Schema.object(props, required: ["name"])
      prop.type.should eq("object")
      prop.properties.should_not be_nil
      prop.properties.not_nil!.size.should eq(2)
      prop.required.should eq(["name"])
    end

    it "sets additionalProperties to false" do
      prop = Anthropic::Schema.object({} of String => Anthropic::Schema::Property)
      prop.additional_properties.should eq(false)
    end
  end
end

describe Anthropic::OutputSchema do
  describe "#to_output_format" do
    it "converts to OutputFormat" do
      schema = Anthropic.output_schema(
        name: "test_output",
        schema: {
          "result" => Anthropic::Schema.string("The result"),
        },
        required: ["result"]
      )

      output = schema.to_output_format
      output.type.should eq("json_schema")
      output.schema["type"].as_s.should eq("object")
      output.schema["properties"]["result"]["type"].as_s.should eq("string")
      output.schema["additionalProperties"].as_bool.should eq(false)
    end
  end
end

describe Anthropic::SchemaTransform do
  describe ".add_additional_properties_false" do
    it "adds additionalProperties to object types" do
      schema = JSON.parse(%({"type":"object","properties":{"name":{"type":"string"}}}))
      result = Anthropic::SchemaTransform.add_additional_properties_false(schema)

      result["additionalProperties"].as_bool.should eq(false)
    end

    it "recursively processes nested objects" do
      schema = JSON.parse(%({"type":"object","properties":{"nested":{"type":"object","properties":{"value":{"type":"string"}}}}}))
      result = Anthropic::SchemaTransform.add_additional_properties_false(schema)

      result["properties"]["nested"]["additionalProperties"].as_bool.should eq(false)
    end

    it "processes array items" do
      schema = JSON.parse(%({"type":"array","items":{"type":"object","properties":{"name":{"type":"string"}}}}))
      result = Anthropic::SchemaTransform.add_additional_properties_false(schema)

      result["items"]["additionalProperties"].as_bool.should eq(false)
    end
  end
end
