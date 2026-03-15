require "../../spec_helper"

describe Anthropic::BetaBatches do
  describe "#create" do
    it "creates a beta batch with required headers" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/batches?beta=true", Fixtures::Responses::BETA_BATCH_CREATED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      batch = client.beta.messages.batches.create(
        requests: [
          Anthropic::BatchRequest.new(
            custom_id: "req-1",
            params: Anthropic::BatchRequestParams.new(
              model: "claude-haiku-4-5-20251001",
              max_tokens: 100,
              messages: [Anthropic::MessageParam.user("2+2=?")],
            )
          ),
        ],
        betas: ["custom-beta"]
      )

      batch.id.should eq("msgbatch_01abc")
      capture.headers.not_nil!["anthropic-beta"].should contain("message-batches-2024-09-24")
      capture.headers.not_nil!["anthropic-beta"].should contain("custom-beta")
    end

    it "merges request-derived beta headers for batch features" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/batches?beta=true", Fixtures::Responses::BETA_BATCH_CREATED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.batches.create(
        requests: [
          Anthropic::BatchRequest.new(
            custom_id: "req-1",
            params: Anthropic::BatchRequestParams.new(
              model: "claude-sonnet-4-6",
              max_tokens: 100,
              messages: [Anthropic::MessageParam.user("Hello")],
              tools: [Anthropic::WebFetchTool20260209.new] of (Anthropic::ToolDefinition | Anthropic::ServerTool),
              cache_control: Anthropic::CacheControl.one_hour
            )
          ),
        ]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("message-batches-2024-09-24")
      headers["anthropic-beta"].should contain(Anthropic::WEB_FETCH_BETA)
      headers["anthropic-beta"].should contain(Anthropic::EXTENDED_CACHE_TTL_BETA)
    end

    it "supports current MCP batch request shapes" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/batches?beta=true", Fixtures::Responses::BETA_BATCH_CREATED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.batches.create(
        requests: [
          Anthropic::BetaBatchRequest.new(
            custom_id: "req-mcp",
            params: Anthropic::BetaBatchRequestParams.new(
              model: "claude-sonnet-4-6",
              max_tokens: 256,
              messages: [Anthropic::MessageParam.user("Use MCP")],
              tools: [
                Anthropic::MCPToolset.new(
                  mcp_server_name: "context7",
                  default_config: Anthropic::MCPToolsetConfig.new(enabled: true),
                  configs: {"query-docs" => Anthropic::MCPToolsetConfig.new(defer_loading: true)}
                ),
              ] of (Anthropic::ToolDefinition | Anthropic::ServerTool),
              context_management: Anthropic::ContextManagementConfig.auto_compact,
              mcp_servers: [
                Anthropic::MCPServerDefinition.new(
                  url: "https://mcp.example.com",
                  name: "context7",
                  authorization_token: "token-123",
                  tool_configuration: Anthropic::MCPToolConfiguration.new(
                    allowed_tools: ["query-docs"],
                    enabled: true
                  )
                ),
              ],
              speed: "fast"
            )
          ),
        ]
      )

      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("message-batches-2024-09-24")
      headers["anthropic-beta"].should contain(Anthropic::MCP_CLIENT_BETA)

      body = JSON.parse(capture.body.not_nil!)
      params = body["requests"][0]["params"]
      params["speed"].as_s.should eq("fast")
      params["context_management"]["edits"].as_a.size.should eq(1)
      params["mcp_servers"][0]["authorization_token"].as_s.should eq("token-123")
      params["tools"][0]["mcp_server_name"].as_s.should eq("context7")
    end
  end

  describe "#list" do
    it "lists beta batches" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?beta=true&limit=20")
        .to_return(body: Fixtures::Responses::BETA_BATCH_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.beta.messages.batches.list

      result.should be_a(Anthropic::BetaBatchListResponse)
      result.data.first.id.should eq("msgbatch_01abc")
    end
  end

  describe "#results" do
    it "streams beta batch results" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/msgbatch_01abc/results?beta=true")
        .to_return do |_request|
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "application/x-jsonl"},
            body_io: IO::Memory.new("#{Fixtures::Responses::BATCH_RESULT_LINE}\n")
          )
        end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      results = [] of Anthropic::BatchResult

      client.beta.messages.batches.results("msgbatch_01abc") do |result|
        results << result
      end

      results.size.should eq(1)
      results.first.custom_id.should eq("req-1")
    end
  end
end

describe Anthropic::BetaBatchRequestParams do
  describe ".with_tools" do
    it "supports mcp toolsets and current beta-only request fields" do
      params = Anthropic::BetaBatchRequestParams.with_tools(
        model: "claude-sonnet-4-6",
        max_tokens: 256,
        messages: [Anthropic::MessageParam.user("Use MCP")],
        tools: [Anthropic.tool(
          name: "test",
          description: "test tool",
          schema: {} of String => Anthropic::Schema::Property,
          required: [] of String
        ) { |_| "ok" }] of Anthropic::Tool,
        server_tools: [Anthropic::MCPToolset.new(mcp_server_name: "context7")] of Anthropic::ServerTool,
        metadata: Anthropic::Metadata.new(user_id: "user-123"),
        speed: "fast",
        context_management: Anthropic::ContextManagementConfig.auto_compact,
        container: "container_123",
        mcp_servers: [Anthropic::MCPServerDefinition.new(url: "https://mcp.example.com", name: "context7")]
      )

      params.tools.should_not be_nil
      params.tools.not_nil!.size.should eq(2)
      params.speed.should eq("fast")
      params.container.should eq("container_123")
      params.mcp_servers.should_not be_nil
      params.context_management.should_not be_nil
    end
  end
end

describe Anthropic::BetaBatchListResponse do
  describe "#auto_paging_all" do
    it "auto-paginates beta batch lists" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?beta=true&limit=20")
        .to_return(body: %({"data":[{"id":"batch1","type":"message_batch","processing_status":"ended","request_counts":{"processing":0,"succeeded":1,"errored":0,"canceled":0,"expired":0},"ended_at":"2025-01-01T01:00:00Z","created_at":"2025-01-01T00:00:00Z","expires_at":"2025-01-02T00:00:00Z","cancel_initiated_at":null,"results_url":null}],"has_more":true,"first_id":"batch1","last_id":"batch1"}))

      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?beta=true&limit=20&after_id=batch1")
        .to_return(body: %({"data":[{"id":"batch2","type":"message_batch","processing_status":"ended","request_counts":{"processing":0,"succeeded":1,"errored":0,"canceled":0,"expired":0},"ended_at":"2025-01-01T02:00:00Z","created_at":"2025-01-01T00:30:00Z","expires_at":"2025-01-02T00:30:00Z","cancel_initiated_at":null,"results_url":null}],"has_more":false,"first_id":"batch2","last_id":"batch2"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      list = client.beta.messages.batches.list
      all = list.auto_paging_all(client)

      all.map(&.id).should eq(["batch1", "batch2"])
    end
  end
end
