require "../../spec_helper"

describe Anthropic::TextContent do
  it "parses text content" do
    json = %({"type":"text","text":"Hello world"})
    content = Anthropic::TextContent.from_json(json)

    content.type.should eq("text")
    content.text.should eq("Hello world")
  end

  it "supports cache_control" do
    content = Anthropic::TextContent.new(
      text: "Cached text",
      cache_control: Anthropic::CacheControl.ephemeral
    )
    content.cache_control.should_not be_nil
    content.cache_control.not_nil!.type.should eq("ephemeral")
  end
end

describe Anthropic::ImageContent do
  describe ".base64" do
    it "creates base64 image" do
      content = Anthropic::ImageContent.base64("image/png", "iVBORw0KGgo...")
      content.type.should eq("image")
      content.source.should be_a(Anthropic::Base64ImageSource)
    end
  end

  describe ".url" do
    it "creates URL image" do
      content = Anthropic::ImageContent.url("https://example.com/image.png")
      content.type.should eq("image")
      content.source.should be_a(Anthropic::URLImageSource)
    end
  end
end

struct TestInput
  include JSON::Serializable
  getter value : String
end

describe Anthropic::ToolUseContent do
  it "parses tool use content" do
    json = %({"type":"tool_use","id":"toolu_123","name":"get_weather","input":{"location":"NYC"}})
    content = Anthropic::ToolUseContent.from_json(json)

    content.type.should eq("tool_use")
    content.id.should eq("toolu_123")
    content.name.should eq("get_weather")
    content.input["location"].as_s.should eq("NYC")
  end

  describe "#input_as" do
    it "parses input into typed struct" do
      json = %({"type":"tool_use","id":"toolu_123","name":"test","input":{"value":"hello"}})
      content = Anthropic::ToolUseContent.from_json(json)

      typed = content.input_as(TestInput)
      typed.value.should eq("hello")
    end
  end
end

describe Anthropic::ToolResultContent do
  it "creates tool result" do
    result = Anthropic::ToolResultContent.new(
      tool_use_id: "toolu_123",
      content: "The weather is sunny"
    )

    result.type.should eq("tool_result")
    result.tool_use_id.should eq("toolu_123")
    result.content.should eq("The weather is sunny")
  end

  it "supports error flag" do
    result = Anthropic::ToolResultContent.new(
      tool_use_id: "toolu_123",
      content: "Error: Not found",
      is_error: true
    )

    result.is_error.should eq(true)
  end
end

describe Anthropic::ThinkingContent do
  it "parses thinking content" do
    json = %({"type":"thinking","thinking":"Let me consider...","signature":"sig123"})
    content = Anthropic::ThinkingContent.from_json(json)

    content.type.should eq("thinking")
    content.thinking.should eq("Let me consider...")
    content.signature.should eq("sig123")
  end
end

describe Anthropic::DocumentContent do
  describe ".text" do
    it "creates plain text document" do
      doc = Anthropic::DocumentContent.text("Document content", title: "My Doc")
      doc.type.should eq("document")
      doc.title.should eq("My Doc")
      doc.source.should be_a(Anthropic::PlainTextSource)
    end
  end

  describe ".pdf" do
    it "creates PDF document from base64" do
      doc = Anthropic::DocumentContent.pdf("base64data", title: "My PDF")
      doc.type.should eq("document")
      doc.source.should be_a(Anthropic::Base64PDFSource)
    end
  end

  describe ".file" do
    it "creates document from file ID" do
      doc = Anthropic::DocumentContent.file("file_123", title: "Uploaded Doc")
      doc.type.should eq("document")
      doc.source.should be_a(Anthropic::FileSource)
      doc.source.as(Anthropic::FileSource).file_id.should eq("file_123")
    end
  end
end

describe Anthropic::CacheControl do
  describe ".ephemeral" do
    it "creates 5-minute cache" do
      cache = Anthropic::CacheControl.ephemeral
      cache.type.should eq("ephemeral")
      cache.ttl.should be_nil
    end
  end

  describe ".one_hour" do
    it "creates 1-hour cache" do
      cache = Anthropic::CacheControl.one_hour
      cache.type.should eq("ephemeral")
      cache.ttl.should eq(3600)
    end
  end

  describe ".with_ttl" do
    it "creates custom TTL cache" do
      cache = Anthropic::CacheControl.with_ttl(1800)
      cache.ttl.should eq(1800)
    end
  end
end

describe Anthropic::ThinkingConfig do
  describe ".enabled" do
    it "creates enabled config with budget" do
      config = Anthropic::ThinkingConfig.enabled(budget_tokens: 5000)
      config.type.should eq("enabled")
      config.budget_tokens.should eq(5000)
    end
  end

  describe ".disabled" do
    it "creates disabled config" do
      config = Anthropic::ThinkingConfig.disabled
      config.type.should eq("disabled")
      config.budget_tokens.should be_nil
    end
  end
end

describe Anthropic::ContentBlockConverter do
  it "parses text content" do
    json = %({"type":"text","text":"Hello"})
    pull = JSON::PullParser.new(json)
    content = Anthropic::ContentBlockConverter.from_json(pull)

    content.should be_a(Anthropic::TextContent)
  end

  it "parses tool_use content" do
    json = %({"type":"tool_use","id":"t1","name":"test","input":{}})
    pull = JSON::PullParser.new(json)
    content = Anthropic::ContentBlockConverter.from_json(pull)

    content.should be_a(Anthropic::ToolUseContent)
  end

  it "parses thinking content" do
    json = %({"type":"thinking","thinking":"hmm","signature":"sig"})
    pull = JSON::PullParser.new(json)
    content = Anthropic::ContentBlockConverter.from_json(pull)

    content.should be_a(Anthropic::ThinkingContent)
  end

  it "handles unknown type gracefully" do
    json = %({"type":"unknown_future_type","data":"value"})
    pull = JSON::PullParser.new(json)
    content = Anthropic::ContentBlockConverter.from_json(pull)

    # Falls back to TextContent with raw JSON
    content.should be_a(Anthropic::TextContent)
  end
end
