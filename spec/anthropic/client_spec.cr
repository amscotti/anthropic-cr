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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
          model: "claude-sonnet-4-6",
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
          model: "claude-sonnet-4-6",
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
          model: "claude-sonnet-4-6",
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
          model: "claude-sonnet-4-6",
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
          model: "claude-sonnet-4-6",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end
    end
  end

  describe "retry behavior" do
    it "retries retryable responses and eventually succeeds" do
      attempts = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
        attempts += 1

        if attempts == 1
          HTTP::Client::Response.new(500, body: Fixtures::Responses::ERROR_SERVER)
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
      end

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0
      )

      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      attempts.should eq(2)
      message.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
    end

    it "respects x-should-retry false on otherwise retryable responses" do
      attempts = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
        attempts += 1
        HTTP::Client::Response.new(
          500,
          body: Fixtures::Responses::ERROR_SERVER,
          headers: HTTP::Headers{"x-should-retry" => "false"}
        )
      end

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0
      )

      expect_raises(Anthropic::InternalServerError) do
        client.messages.create(
          model: "claude-sonnet-4-6",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end

      attempts.should eq(1)
    end

    it "respects x-should-retry true on otherwise non-retryable responses" do
      attempts = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
        attempts += 1

        if attempts == 1
          HTTP::Client::Response.new(
            400,
            body: Fixtures::Responses::ERROR_BAD_REQUEST,
            headers: HTTP::Headers{"x-should-retry" => "true"}
          )
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
      end

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0
      )

      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      attempts.should eq(2)
      message.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
    end

    it "retries transport errors and eventually succeeds" do
      attempts = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
        attempts += 1

        if attempts == 1
          raise IO::Error.new("connection dropped")
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
      end

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0
      )

      message = client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      attempts.should eq(2)
      message.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
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

    it "provides beta.models" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.models.should be_a(Anthropic::BetaModels)
    end

    it "provides beta.messages.batches" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.batches.should be_a(Anthropic::BetaBatches)
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
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hello")],
        tools: tools
      )
      runner.should be_a(Anthropic::ToolRunner)
    end
  end

  describe "centralized beta headers resolution" do
    it "combines caching, diagnostics, and tools headers correctly" do
      # Test cache beta
      cache = Anthropic::CacheControl.one_hour
      headers = Anthropic.resolve_beta_headers(cache_control: cache)
      headers.should_not be_nil
      headers.not_nil!["anthropic-beta"].should contain(Anthropic::EXTENDED_CACHE_TTL_BETA)

      # Test diagnostics beta
      diag = Anthropic::DiagnosticsParam.new("msg_123")
      headers = Anthropic.resolve_beta_headers(diagnostics: diag)
      headers.should_not be_nil
      headers.not_nil!["anthropic-beta"].should contain(Anthropic::CACHE_DIAGNOSTICS_BETA)

      # Test tools beta
      tools = [Anthropic::WebSearchTool.new]
      headers = Anthropic.resolve_beta_headers(server_tools: tools)
      headers.should_not be_nil
      headers.not_nil!["anthropic-beta"].should contain(Anthropic::WEB_SEARCH_BETA)

      # Test combination
      headers = Anthropic.resolve_beta_headers(
        betas: ["custom-beta"],
        server_tools: tools,
        cache_control: cache,
        diagnostics: diag
      )
      headers.should_not be_nil
      val = headers.not_nil!["anthropic-beta"]
      val.should contain("custom-beta")
      val.should contain(Anthropic::EXTENDED_CACHE_TTL_BETA)
      val.should contain(Anthropic::CACHE_DIAGNOSTICS_BETA)
      val.should contain(Anthropic::WEB_SEARCH_BETA)
    end
  end

  describe "automated idempotency keys" do
    it "automatically generates a UUID idempotency key on POST requests" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.post("/v1/messages", {test: "body"})

      headers = capture.headers.not_nil!
      headers.has_key?("idempotency-key").should be_true
      headers["idempotency-key"].should match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end

    it "respects manually supplied idempotency keys and does not overwrite them" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.post("/v1/messages", {test: "body"}, {"idempotency-key" => "user-custom-key-123"})

      headers = capture.headers.not_nil!
      headers["idempotency-key"].should eq("user-custom-key-123")
    end

    it "does not generate an idempotency key on GET requests" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6", Fixtures::Responses::MODEL_INFO)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.get("/v1/models/claude-sonnet-4-6")

      headers = capture.headers.not_nil!
      headers.has_key?("idempotency-key").should be_false
    end
  end
end
