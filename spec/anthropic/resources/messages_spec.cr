require "../../spec_helper"

describe Anthropic::Messages do
  describe "#create" do
    it "sends correct request body" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [{role: "user", content: "Hello, Claude!"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["model"].as_s.should eq("claude-sonnet-4-6")
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
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
      message.type.should eq("message")
      message.role.should eq("assistant")
      message.model.should eq("claude-sonnet-4-6")
      message.stop_reason.should eq("end_turn")
    end

    it "provides text convenience method" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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

    it "sends output_config with effort" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_OPUS_46)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_6,
        max_tokens: 16384,
        output_config: Anthropic::OutputConfig.new(effort: "high"),
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["output_config"]["effort"].as_s.should eq("high")
    end

    it "sends inference_geo" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_OPUS_46)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_6,
        max_tokens: 16384,
        inference_geo: "us",
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["inference_geo"].as_s.should eq("us")
    end

    it "omits output_config and inference_geo when nil" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["output_config"]?.should be_nil
      body["inference_geo"]?.should be_nil
    end

    it "sends computer use beta header for ComputerUseTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080)] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Click the button"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("computer-use-2025-01-24")
    end

    it "sends code execution beta header for CodeExecutionTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::CodeExecutionTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Run some code"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("code-execution-2025-08-25")
    end

    it "sends web fetch beta header for WebFetchTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::WebFetchTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Fetch a page"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("web-fetch-2025-09-10")
    end

    it "sends memory beta header for MemoryTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::MemoryTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Remember this"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("context-management-2025-06-27")
    end

    it "sends MCP connector beta header for MCPTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::MCPTool.new(name: "test", server_label: "test", server_url: "https://example.com/mcp")] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Use MCP"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("mcp-connector-2025-05-01")
    end

    it "sends advanced tool use beta header for ToolSearchBM25Tool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::ToolSearchBM25Tool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Find a tool"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("advanced-tool-use-2025-11-20")
    end

    it "sends advanced tool use beta header for ToolSearchRegexTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::ToolSearchRegexTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Search tools"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("advanced-tool-use-2025-11-20")
    end

    it "sends the expected beta headers for newer server tool versions" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [
          Anthropic::WebSearchTool20260209.new,
          Anthropic::WebFetchTool20260209.new,
          Anthropic::CodeExecutionTool20260120.new,
          Anthropic::ComputerUseTool20251124.new(display_width_px: 1920, display_height_px: 1080),
        ] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Use all the tools"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain(Anthropic::WEB_SEARCH_BETA)
      headers["anthropic-beta"].should contain(Anthropic::WEB_FETCH_BETA)
      headers["anthropic-beta"].should contain(Anthropic::CODE_EXECUTION_BETA)
      headers["anthropic-beta"].should contain(Anthropic::COMPUTER_USE_BETA)
    end

    it "does not send beta headers for BashTool or TextEditorTool" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        server_tools: [Anthropic::BashTool.new, Anthropic::TextEditorTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Do something"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"]?.should be_nil
    end

    it "sends metadata with user_id" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        metadata: Anthropic::Metadata.new(user_id: "user-123"),
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["metadata"]["user_id"].as_s.should eq("user-123")
    end

    it "sends ThinkingConfig.adaptive" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_OPUS_46)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_6,
        max_tokens: 16384,
        thinking: Anthropic::ThinkingConfig.adaptive,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["thinking"]["type"].as_s.should eq("adaptive")
      body["thinking"]["budget_tokens"]?.should be_nil
    end

    it "sends top-level cache_control" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        cache_control: Anthropic::CacheControl.ephemeral,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["cache_control"]["type"].as_s.should eq("ephemeral")
    end

    it "sends non-beta container identifier" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        container: "container_123",
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["container"].as_s.should eq("container_123")
    end

    it "sends extended cache TTL beta header for top-level cache_control" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        cache_control: Anthropic::CacheControl.one_hour,
        messages: [{role: "user", content: "Hello"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::EXTENDED_CACHE_TTL_BETA)
    end
  end

  describe "#batches" do
    it "provides access to batches resource" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.batches.should be_a(Anthropic::Batches)
    end
  end
end

describe Anthropic::Usage do
  it "parses cache_creation and inference_geo" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
      .to_return(body: Fixtures::Responses::MESSAGE_WITH_CACHE_CREATION)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    message = client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 100,
      messages: [{role: "user", content: "Hello"}]
    )

    message.usage.cache_creation.should_not be_nil
    cc = message.usage.cache_creation.not_nil!
    cc.ephemeral_1h_input_tokens.should eq(60)
    cc.ephemeral_5m_input_tokens.should eq(20)

    message.usage.inference_geo.should eq("us")
  end

  it "parses server_tool_use" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
      .to_return(body: Fixtures::Responses::MESSAGE_WITH_SERVER_TOOL_USAGE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    message = client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 100,
      messages: [{role: "user", content: "Search for something"}]
    )

    message.usage.server_tool_use.should_not be_nil
    message.usage.server_tool_use.not_nil!.web_search_requests.should eq(3)
  end
end

describe Anthropic::Message do
  describe "#redacted_thinking_blocks" do
    it "extracts redacted thinking blocks" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_WITH_REDACTED_THINKING)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-opus-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Think about this"}]
      )

      message.redacted_thinking_blocks.size.should eq(1)
      message.redacted_thinking_blocks[0].data.should eq("cmVkYWN0ZWQ=")
      message.thinking_blocks.size.should eq(1)
    end
  end

  describe "#parsed_output" do
    it "returns nil for non-JSON output" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.parsed_output.should be_nil
    end
  end

  describe "#parsed_output_as!" do
    it "raises when structured output cannot be parsed" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      expect_raises(Anthropic::StructuredOutputParseError) do
        message.parsed_output_as!(JSON::Any)
      end
    end
  end

  describe "#container_id" do
    it "parses container information from message responses" do
      response = %({"id":"msg_container_01","type":"message","role":"assistant","container":{"id":"cont_123","expires_at":"2026-03-14T12:00:00Z"},"content":[{"type":"text","text":"Hello"}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":5}})

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: response)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      message.container.should_not be_nil
      message.container_id.should eq("cont_123")
      message.container.not_nil!.expires_at.should eq("2026-03-14T12:00:00Z")
    end
  end

  describe "#open_stream" do
    it "yields a rich message stream helper" do
      body = "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_stream_01\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-6\",\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":1,\"output_tokens\":0}}}\n\nevent: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\nevent: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\nevent: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n"

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |_request|
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new(body)
          )
        end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      collected = ""

      client.messages.open_stream(
        model: "claude-sonnet-4-6",
        max_tokens: 16,
        messages: [{role: "user", content: "Hello"}]
      ) do |stream|
        stream.should be_a(Anthropic::MessageStream)
        collected = stream.collect_text
      end

      collected.should eq("Hello")
    end

    it "sends container in streaming requests" do
      capture = RequestCapture.new

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |request|
          capture.body = request.body.to_s
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new("data: [DONE]\n\n")
          )
        end

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.open_stream(
        model: "claude-sonnet-4-6",
        max_tokens: 16,
        container: "container_123",
        messages: [{role: "user", content: "Hello"}]
      ) { |_stream| }

      JSON.parse(capture.body.not_nil!)["container"].as_s.should eq("container_123")
    end
  end
end

describe Anthropic::ContextManagementConfig do
  it "serializes auto_compact" do
    config = Anthropic::ContextManagementConfig.auto_compact
    json = config.to_json
    parsed = JSON.parse(json)

    parsed["edits"].as_a.size.should eq(1)
    parsed["edits"][0]["type"].as_s.should eq("compact_20260112")
  end

  it "serializes with instructions and trigger" do
    config = Anthropic::ContextManagementConfig.auto_compact(
      instructions: "Keep key facts",
      trigger: "auto"
    )
    json = config.to_json
    parsed = JSON.parse(json)

    parsed["edits"][0]["instructions"].as_s.should eq("Keep key facts")
    parsed["edits"][0]["trigger"].as_s.should eq("auto")
  end

  it "serializes multiple edits" do
    config = Anthropic::ContextManagementConfig.new(edits: [
      Anthropic::CompactEdit.new,
      Anthropic::ClearToolUsesEdit.new,
      Anthropic::ClearThinkingEdit.new,
    ] of Anthropic::ContextManagementEdit)

    json = config.to_json
    parsed = JSON.parse(json)

    parsed["edits"].as_a.size.should eq(3)
    parsed["edits"][0]["type"].as_s.should eq("compact_20260112")
    parsed["edits"][1]["type"].as_s.should eq("clear_tool_uses_20250919")
    parsed["edits"][2]["type"].as_s.should eq("clear_thinking_20251015")
  end
end

describe Anthropic::ContainerConfig do
  it "serializes with skills" do
    config = Anthropic::ContainerConfig.new(
      skills: [Anthropic::ContainerSkill.new(skill_id: "my-skill")]
    )
    json = config.to_json
    parsed = JSON.parse(json)

    parsed["skills"].as_a.size.should eq(1)
    parsed["skills"][0]["type"].as_s.should eq("anthropic")
    parsed["skills"][0]["skill_id"].as_s.should eq("my-skill")
  end

  it "serializes with version" do
    config = Anthropic::ContainerConfig.new(
      skills: [Anthropic::ContainerSkill.new(skill_id: "my-skill", version: "1.0")]
    )
    json = config.to_json
    parsed = JSON.parse(json)

    parsed["skills"][0]["version"].as_s.should eq("1.0")
  end

  it "omits version when nil" do
    config = Anthropic::ContainerConfig.new(
      skills: [Anthropic::ContainerSkill.new(skill_id: "my-skill")]
    )
    json = config.to_json
    parsed = JSON.parse(json)

    parsed["skills"][0]["version"]?.should be_nil
  end
end

describe Anthropic::MCPServerDefinition do
  it "serializes with required fields" do
    server = Anthropic::MCPServerDefinition.new(
      url: "https://mcp.example.com/sse",
      name: "my-server"
    )
    json = server.to_json
    parsed = JSON.parse(json)

    parsed["type"].as_s.should eq("url")
    parsed["url"].as_s.should eq("https://mcp.example.com/sse")
    parsed["name"].as_s.should eq("my-server")
  end

  it "serializes with authorization_token" do
    server = Anthropic::MCPServerDefinition.new(
      url: "https://mcp.example.com/sse",
      name: "my-server",
      authorization_token: "token-123"
    )
    json = server.to_json
    parsed = JSON.parse(json)

    parsed["authorization_token"].as_s.should eq("token-123")
  end

  it "serializes with tool_configuration" do
    server = Anthropic::MCPServerDefinition.new(
      url: "https://mcp.example.com/sse",
      name: "my-server",
      tool_configuration: Anthropic::MCPToolConfiguration.new(
        allowed_tools: ["tool1", "tool2"],
        enabled: true
      )
    )
    json = server.to_json
    parsed = JSON.parse(json)

    parsed["tool_configuration"]["allowed_tools"].as_a.map(&.as_s).should eq(["tool1", "tool2"])
    parsed["tool_configuration"]["enabled"].as_bool.should be_true
  end

  it "omits optional fields when nil" do
    server = Anthropic::MCPServerDefinition.new(
      url: "https://mcp.example.com/sse",
      name: "my-server"
    )
    json = server.to_json
    json.should_not contain("authorization_token")
    json.should_not contain("tool_configuration")
  end
end

describe Anthropic::CompactionDelta do
  it "parses from JSON" do
    json = %({"type":"compaction_delta","content":"Compacted summary."})
    delta = Anthropic::CompactionDelta.from_json(json)

    delta.type.should eq("compaction_delta")
    delta.content.should eq("Compacted summary.")
  end

  it "parses via StreamDeltaConverter" do
    event_json = %({"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"Summary text."}})
    event = Anthropic::ContentBlockDeltaEvent.from_json(event_json)

    event.delta.should be_a(Anthropic::CompactionDelta)
    event.delta.as(Anthropic::CompactionDelta).content.should eq("Summary text.")
  end
end

describe Anthropic::Metadata do
  it "serializes with user_id" do
    metadata = Anthropic::Metadata.new(user_id: "user-123")
    json = metadata.to_json
    parsed = JSON.parse(json)

    parsed["user_id"].as_s.should eq("user-123")
  end

  it "omits user_id when nil" do
    metadata = Anthropic::Metadata.new
    json = metadata.to_json
    json.should_not contain("user_id")
  end
end

describe Anthropic::ServerToolUseContent do
  it "parses object-shaped caller info from API responses" do
    response = %({"id":"msg_server_tool_use","type":"message","role":"assistant","content":[{"type":"server_tool_use","id":"stu_01","name":"web_search","input":{"query":"latest Crystal news"},"caller":{"type":"direct"}},{"type":"text","text":"done"}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":5}})

    WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
      .to_return(body: response)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    message = client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 100,
      server_tools: [Anthropic::WebSearchTool.new] of Anthropic::ServerTool,
      messages: [{role: "user", content: "Search for Crystal news"}]
    )

    block = message.content.first.as(Anthropic::ServerToolUseContent)
    block.caller.should eq("direct")
    block.caller_tool_id.should be_nil
    block.caller_info.should_not be_nil
    block.caller_info.not_nil!.direct?.should be_true
  end

  it "still parses legacy string caller values" do
    block = Anthropic::ServerToolUseContent.from_json(
      %({"type":"server_tool_use","id":"stu_02","name":"code_execution","input":{"code":"print(42)"},"caller":"code_execution_20250825"})
    )

    block.caller.should eq("code_execution_20250825")
    block.caller_tool_id.should be_nil
  end
end
