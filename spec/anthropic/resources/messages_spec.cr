require "../../spec_helper"

describe Anthropic::Messages do
  describe "#create" do
    it "sends correct request body" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [{role: "user", content: "Hello, Claude!"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["model"].as_s.should eq("claude-sonnet-4-5-20250929")
      body["max_tokens"].as_i.should eq(1024)
      body["messages"].as_a.size.should eq(1)
      body["messages"][0]["role"].as_s.should eq("user")
      body["messages"][0]["content"].as_s.should eq("Hello, Claude!")
    end

    it "parses basic response" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
      message.type.should eq("message")
      message.role.should eq("assistant")
      message.model.should eq("claude-sonnet-4-5-20250929")
      message.stop_reason.should eq("end_turn")
    end

    it "provides text convenience method" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      # Access text through typed content array
      text_block = message.content.find { |block| block.is_a?(Anthropic::TextContent) }.as?(Anthropic::TextContent)
      text_block.should_not be_nil
      text_block.not_nil!.text.should eq("Hello! I'm Claude, an AI assistant.")
    end

    it "parses usage correctly" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.usage.input_tokens.should eq(10)
      message.usage.output_tokens.should eq(15)
    end

    it "detects tool use in response" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_WITH_TOOL_USE)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "What's the weather?"}]
      )

      message.tool_use?.should be_true
      message.stop_reason.should eq("tool_use")
    end

    it "extracts tool use blocks" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_WITH_TOOL_USE)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "What's the weather?"}]
      )

      blocks = message.tool_use_blocks
      blocks.size.should eq(1)
      blocks[0].name.should eq("get_weather")
      blocks[0].id.should eq("toolu_01xyz")
      blocks[0].input["location"].as_s.should eq("San Francisco")
    end

    it "sends system prompt" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        system: "You are a helpful assistant.",
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["system"].as_s.should eq("You are a helpful assistant.")
    end

    it "sends temperature" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        temperature: 0.7,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["temperature"].as_f.should eq(0.7)
    end

    it "sends top_p" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        top_p: 0.9,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["top_p"].as_f.should eq(0.9)
    end

    it "sends stop_sequences" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        stop_sequences: ["END", "STOP"],
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      stops = body["stop_sequences"].as_a
      stops.size.should eq(2)
      stops[0].as_s.should eq("END")
      stops[1].as_s.should eq("STOP")
    end
  end

  describe "#batches" do
    it "provides access to batches resource" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.batches.should be_a(Anthropic::Batches)
    end
  end
end

describe Anthropic::Message do
  describe "#parsed_output" do
    it "returns nil for non-JSON output" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.parsed_output.should be_nil
    end
  end
end
