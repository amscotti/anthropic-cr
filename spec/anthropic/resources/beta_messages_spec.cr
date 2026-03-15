require "../../spec_helper"

private def create_beta_tool(name = "test") : Anthropic::Tool
  Anthropic.tool(
    name: name,
    description: "A test tool",
    schema: {} of String => Anthropic::Schema::Property,
    required: [] of String
  ) { |_| "result" }
end

private struct ParsedWeatherSummary
  include JSON::Serializable

  getter city : String
  getter temperature_c : Int32
end

describe Anthropic::BetaMessages do
  describe "#create" do
    it "auto-adds the structured outputs beta header for output_schema" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      schema = Anthropic.output_schema(
        name: "summary_result",
        schema: {"summary" => Anthropic::Schema.string("Summary")},
        required: ["summary"]
      )

      client.beta.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        output_schema: schema,
        messages: [{role: "user", content: "Summarize this"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::STRUCTURED_OUTPUT_BETA)
    end

    it "merges explicit betas with server tool betas" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.create(
        betas: ["custom-beta"],
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        server_tools: [Anthropic::WebSearchTool.new] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Search for Crystal language"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("custom-beta")
      headers["anthropic-beta"].should contain(Anthropic::WEB_SEARCH_BETA)
    end

    it "sends top-level cache_control and extended cache beta" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        cache_control: Anthropic::CacheControl.one_hour,
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["cache_control"]["ttl"].as_i.should eq(3600)
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::EXTENDED_CACHE_TTL_BETA)
    end

    it "accepts container identifiers for reuse" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        container: "cont_123",
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["container"].as_s.should eq("cont_123")
    end
  end

  describe "#parse" do
    it "returns a typed parsed message for typed output schemas" do
      payload = %({"city":"Paris","temperature_c":21}).to_json
      response = %({"id":"msg_parse_01","type":"message","role":"assistant","content":[{"type":"text","text":#{payload}}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":12}})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", response)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      schema = Anthropic.output_schema(type: ParsedWeatherSummary, name: "weather_summary")

      parsed = client.beta.messages.parse(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        output_schema: schema,
        messages: [{role: "user", content: "Summarize the weather"}]
      )

      parsed.text.should eq(%({"city":"Paris","temperature_c":21}))
      parsed.parsed_output.city.should eq("Paris")
      parsed.parsed_output.temperature_c.should eq(21)
      parsed.message.should be_a(Anthropic::Message)
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::STRUCTURED_OUTPUT_BETA)
    end

    it "raises a structured output parse error when the response is invalid JSON" do
      response = %({"id":"msg_parse_02","type":"message","role":"assistant","content":[{"type":"text","text":"not-json"}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":12}})
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: response)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      schema = Anthropic.output_schema(type: ParsedWeatherSummary, name: "weather_summary")

      expect_raises(Anthropic::StructuredOutputParseError) do
        client.beta.messages.parse(
          model: "claude-sonnet-4-6",
          max_tokens: 256,
          output_schema: schema,
          messages: [{role: "user", content: "Summarize the weather"}]
        )
      end
    end
  end

  describe "#tool_runner" do
    it "uses beta message requests when betas are provided" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        betas: ["custom-beta"],
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        messages: [Anthropic::MessageParam.user("Hello")],
        tools: [create_beta_tool] of Anthropic::Tool
      )

      runner.next_message

      capture.headers.not_nil!["anthropic-beta"].should contain("custom-beta")
    end
  end

  describe "#count_tokens" do
    it "posts to the beta token counting endpoint with required betas" do
      capture = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/messages/count_tokens?beta=true",
        Fixtures::Responses::TOKEN_COUNT_BASIC
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      count = client.beta.messages.count_tokens(
        betas: ["custom-beta"],
        model: "claude-sonnet-4-6",
        messages: [{role: "user", content: "Count these tokens"}],
        server_tools: [Anthropic::WebSearchTool.new] of Anthropic::ServerTool,
        speed: "fast",
        output_config: Anthropic::OutputConfig.new(effort: "high")
      )

      count.input_tokens.should eq(25)

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("custom-beta")
      headers["anthropic-beta"].should contain(Anthropic::TOKEN_COUNTING_BETA)
      headers["anthropic-beta"].should contain(Anthropic::WEB_SEARCH_BETA)

      body = JSON.parse(capture.body.not_nil!)
      body["speed"].as_s.should eq("fast")
      body["output_config"]["effort"].as_s.should eq("high")
    end

    it "auto-adds the structured outputs beta header for output_schema" do
      capture = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/messages/count_tokens?beta=true",
        Fixtures::Responses::TOKEN_COUNT_BASIC
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      schema = Anthropic.output_schema(
        name: "summary_result",
        schema: {"summary" => Anthropic::Schema.string("Summary")},
        required: ["summary"]
      )

      client.beta.messages.count_tokens(
        model: "claude-sonnet-4-6",
        messages: [{role: "user", content: "Summarize this"}],
        output_schema: schema
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::STRUCTURED_OUTPUT_BETA)
    end
  end

  describe "MCP request shapes" do
    it "serializes mcp_servers and mcp_toolset fields correctly" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        mcp_servers: [
          Anthropic::MCPServerDefinition.new(
            url: "https://mcp.example.com",
            name: "context7",
            authorization_token: "token-123",
            tool_configuration: Anthropic::MCPToolConfiguration.new(
              allowed_tools: ["resolve-library-id", "query-docs"],
              enabled: true
            )
          ),
        ],
        server_tools: [
          Anthropic::MCPToolset.new(
            mcp_server_name: "context7",
            default_config: Anthropic::MCPToolsetConfig.new(enabled: true, defer_loading: false),
            configs: {"query-docs" => Anthropic::MCPToolsetConfig.new(enabled: true, defer_loading: true)},
            cache_control: Anthropic::CacheControl.ephemeral
          ),
        ] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Use the MCP tools"}]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain(Anthropic::MCP_CLIENT_BETA)

      body = JSON.parse(capture.body.not_nil!)
      server = body["mcp_servers"][0]
      server["name"].as_s.should eq("context7")
      server["authorization_token"].as_s.should eq("token-123")
      server["tool_configuration"]["allowed_tools"].as_a.map(&.as_s).should eq(["resolve-library-id", "query-docs"])
      server["tool_configuration"]["enabled"].as_bool.should be_true

      toolset = body["tools"][0]
      toolset["type"].as_s.should eq("mcp_toolset")
      toolset["mcp_server_name"].as_s.should eq("context7")
      toolset["default_config"]["enabled"].as_bool.should be_true
      toolset["configs"]["query-docs"]["defer_loading"].as_bool.should be_true
      toolset["cache_control"]["type"].as_s.should eq("ephemeral")
    end
  end

  describe "#open_stream" do
    it "yields the rich beta message stream helper" do
      body = "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_stream_01\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-6\",\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":1,\"output_tokens\":0}}}\n\nevent: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\nevent: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello beta\"}}\n\nevent: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n"

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

      client.beta.messages.open_stream(
        betas: ["custom-beta"],
        model: "claude-sonnet-4-6",
        max_tokens: 16,
        messages: [{role: "user", content: "Hello"}]
      ) do |stream|
        stream.should be_a(Anthropic::MessageStream)
        collected = stream.collect_text
      end

      collected.should eq("Hello beta")
    end
  end
end
