require "../spec_helper"

describe Anthropic::Client do
  describe "#initialize" do
    it "accepts explicit API key" do
      client = Anthropic::Client.new(api_key: "sk-ant-test-key")
      client.should_not be_nil
    end

    it "reads API key from environment" do
      ENV["ANTHROPIC_API_KEY"] = "sk-ant-env-key"
      client = Anthropic::Client.new
      client.should_not be_nil
      ENV.delete("ANTHROPIC_API_KEY")
    end

    it "raises error when no API key provided" do
      ENV.delete("ANTHROPIC_API_KEY")
      expect_raises(ArgumentError, /API key required/) do
        Anthropic::Client.new
      end
    end

    it "accepts custom base URL" do
      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        base_url: "https://custom.api.example.com"
      )
      client.should_not be_nil
    end

    it "accepts custom timeout" do
      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        timeout: 30.seconds
      )
      client.should_not be_nil
    end

    it "accepts custom headers" do
      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        default_headers: {"X-Custom-Header" => "value"}
      )
      client.should_not be_nil
    end
  end

  describe "#post" do
    it "sends correct headers" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test-key")
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      headers = capture.headers.not_nil!
      headers["x-api-key"].should eq("sk-ant-test-key")
      headers["anthropic-version"].should eq("2023-06-01")
      headers["content-type"].should eq("application/json")
      headers["user-agent"].should start_with("anthropic-crystal/")
    end

    it "includes custom headers" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(
        api_key: "sk-ant-test-key",
        default_headers: {"X-Custom" => "custom-value"}
      )
      client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      capture.headers.not_nil!["X-Custom"].should eq("custom-value")
    end
  end

  describe "error handling" do
    it "raises BadRequestError on 400" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 400, body: Fixtures::Responses::ERROR_BAD_REQUEST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      expect_raises(Anthropic::BadRequestError) do
        client.messages.create(
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end
    end

    it "raises AuthenticationError on 401" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 401, body: Fixtures::Responses::ERROR_UNAUTHORIZED)

      client = Anthropic::Client.new(api_key: "sk-ant-invalid")
      expect_raises(Anthropic::AuthenticationError) do
        client.messages.create(
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end
    end

    it "raises NotFoundError on 404" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/nonexistent")
        .to_return(status: 404, body: Fixtures::Responses::ERROR_NOT_FOUND)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      expect_raises(Anthropic::NotFoundError) do
        client.models.retrieve("nonexistent")
      end
    end

    it "raises RateLimitError on 429" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 429,
          body: Fixtures::Responses::ERROR_RATE_LIMIT,
          headers: HTTP::Headers{"retry-after" => "30"}
        )

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      begin
        client.messages.create(
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      rescue ex : Anthropic::RateLimitError
        ex.retry_after.should eq(30)
      end
    end

    it "captures response headers on errors" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 400,
          body: Fixtures::Responses::ERROR_BAD_REQUEST,
          headers: HTTP::Headers{"x-request-id" => "req_12345", "content-type" => "application/json"}
        )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      begin
        client.messages.create(
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      rescue ex : Anthropic::BadRequestError
        ex.headers.should_not be_nil
        ex.headers.not_nil!["x-request-id"].should eq("req_12345")
        ex.headers.not_nil!["content-type"].should eq("application/json")
      end
    end

    it "raises InternalServerError on 500" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: Fixtures::Responses::ERROR_SERVER)

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      expect_raises(Anthropic::InternalServerError) do
        client.messages.create(
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end
    end
  end

  describe "resource accessors" do
    it "provides messages resource" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.should be_a(Anthropic::Messages)
    end

    it "provides models resource" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.models.should be_a(Anthropic::Models)
    end

    it "provides beta namespace" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.should be_a(Anthropic::Beta)
    end

    it "provides beta.messages" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.should be_a(Anthropic::BetaMessages)
    end

    it "provides beta.files" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.files.should be_a(Anthropic::BetaFiles)
    end

    it "provides beta.messages.tool_runner" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [Anthropic.tool(
        name: "test",
        description: "A test tool",
        schema: {} of String => Anthropic::Schema::Property,
        required: [] of String
      ) { |_| "result" }] of Anthropic::Tool

      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hello")],
        tools: tools
      )
      runner.should be_a(Anthropic::ToolRunner)
    end
  end
end
