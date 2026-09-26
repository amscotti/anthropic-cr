require "../spec_helper"

private def with_saved_env(*keys : String, &)
  saved = {} of String => String?
  keys.each { |k| saved[k] = ENV[k]? }
  begin
    yield
  ensure
    keys.each do |k|
      if value = saved[k]
        ENV[k] = value
      else
        ENV.delete(k)
      end
    end
  end
end

# Spawns a fake HTTP proxy that answers one CONNECT with 200 and then
# closes (so the client's TLS handshake fails). Yields the proxy port
# and a channel that receives the raw CONNECT head. Enables real
# connections for the block so the CONNECT bytes hit the fake server.
private def with_fake_proxy(& : Int32, Channel(String) -> _)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.port
  received = Channel(String).new
  spawn do
    begin
      sock = server.accept
      lines = [] of String
      while (line = sock.gets) && line != "\r\n" && !line.empty?
        lines << line
      end
      sock << "HTTP/1.1 200 Connection established\r\n\r\n"
      sock.flush
      received.send(lines.join)
    rescue ex
      received.send("FIBER-ERROR: #{ex.message}")
    ensure
      sock.close if sock
      server.close
    end
  end

  prior_allow_net_connect = WebMock.allows_net_connect?
  WebMock.allow_net_connect = true
  begin
    yield port, received
  ensure
    WebMock.allow_net_connect = prior_allow_net_connect
  end
end

private def receive_connect_head(received : Channel(String)) : String
  select
  when head = received.receive
    head
  when timeout(10.seconds)
    raise "timed out waiting for the proxy CONNECT request"
  end
end

describe Anthropic::Client do
  describe "#initialize" do
    it "accepts explicit API key" do
      client = Anthropic::Client.new(api_key: "sk-ant-test-key")
      client.should_not be_nil
    end

    it "reads API key from environment" do
      with_saved_env("ANTHROPIC_API_KEY") do
        ENV["ANTHROPIC_API_KEY"] = "sk-ant-env-key"
        client = Anthropic::Client.new
        client.should_not be_nil
      end
    end

    it "raises error when no API key provided" do
      with_saved_env("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN") do
        ENV.delete("ANTHROPIC_API_KEY")
        ENV.delete("ANTHROPIC_AUTH_TOKEN")
        expect_raises(ArgumentError, /API key or auth token required/) do
          Anthropic::Client.new
        end
      end
    end

    it "accepts an auth token instead of an API key" do
      with_saved_env("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN") do
        ENV.delete("ANTHROPIC_API_KEY")
        ENV.delete("ANTHROPIC_AUTH_TOKEN")
        client = Anthropic::Client.new(auth_token: "oauth-token")
        client.should_not be_nil
      end
    end

    it "reads auth token from environment" do
      with_saved_env("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN") do
        ENV.delete("ANTHROPIC_API_KEY")
        ENV["ANTHROPIC_AUTH_TOKEN"] = "oauth-env-token"
        client = Anthropic::Client.new
        client.should_not be_nil
      end
    end

    it "sends bearer auth for token credentials" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(auth_token: "oauth-token")
      client.models.list

      headers = capture.headers.not_nil!
      headers["authorization"].should eq("Bearer oauth-token")
      headers.has_key?("x-api-key").should be_false
    end

    it "prefers the API key when both credentials are present" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test", auth_token: "oauth-token")
      client.models.list

      headers = capture.headers.not_nil!
      headers["x-api-key"].should eq("sk-ant-test")
      headers.has_key?("authorization").should be_false
    end

    it "accepts custom base URL" do
      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        base_url: "https://custom.api.example.com"
      )
      client.should_not be_nil
    end

    it "reads base URL from environment" do
      with_saved_env("ANTHROPIC_BASE_URL") do
        ENV["ANTHROPIC_BASE_URL"] = "https://proxy.example.com"
        capture = stub_and_capture(:get, "https://proxy.example.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

        client = Anthropic::Client.new(api_key: "sk-ant-test")
        client.models.list

        capture.path.not_nil!.should contain("/v1/models")
      end
    end

    it "appends default query params to requests" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20&hello=world", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test", default_query: {"hello" => "world"})
      client.models.list

      capture.path.not_nil!.should contain("hello=world")
    end

    it "lets per-request query params win over defaults" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=5&other=x", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test", default_query: {"limit" => "20", "other" => "x"})
      client.get("/v1/models", {"limit" => "5"})

      capture.path.should eq("/v1/models?limit=5&other=x")
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

  describe "#with_options" do
    it "scopes extra headers and query to the copy" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages?debug=true", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      scoped = client.with_options(
        extra_headers: {"X-Scoped" => "yes"},
        extra_query: {"debug" => "true"}
      )
      scoped.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )

      capture.headers.not_nil!["X-Scoped"].should eq("yes")
      capture.path.not_nil!.should contain("debug=true")
    end

    it "does not mutate the original client" do
      plain_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages?base=1", Fixtures::Responses::MESSAGE_BASIC)
      scoped_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages?base=1&scoped=true", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        default_headers: {"X-Base" => "base"},
        default_query: {"base" => "1"}
      )
      scoped = client.with_options(
        timeout: 30.seconds,
        max_retries: 0,
        extra_headers: {"X-Scoped" => "yes"},
        extra_query: {"scoped" => "true"}
      )
      scoped.should_not be(client)

      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )
      plain_capture.headers.not_nil!.has_key?("X-Scoped").should be_false
      plain_capture.path.not_nil!.should_not contain("scoped=true")

      scoped.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 100,
        messages: [{role: "user", content: "Hello"}]
      )
      scoped_capture.headers.not_nil!["X-Base"].should eq("base")
      scoped_capture.headers.not_nil!["X-Scoped"].should eq("yes")
    end

    it "scopes credentials, base URL, and proxy to the copy" do
      stub_and_capture(:get, "https://api.anthropic.com/v1/models", Fixtures::Responses::MODEL_LIST)
      tenant_capture = stub_and_capture(:get, "https://tenant.example.com/v1/models", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      scoped = client.with_options(api_key: "sk-ant-tenant", base_url: "https://tenant.example.com/")
      scoped.get("/v1/models")

      tenant_capture.headers.not_nil!["x-api-key"].should eq("sk-ant-tenant")
      tenant_capture.path.should eq("/v1/models")
    end

    it "scopes a proxy override without touching the original" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models", Fixtures::Responses::MODEL_LIST)
        client = Anthropic::Client.new(api_key: "sk-ant-test")
        scoped = client.with_options(proxy: "http://127.0.0.1:9", max_retries: 0)

        expect_raises(Anthropic::APIConnectionError) do
          scoped.get("/v1/models")
        end
        client.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end
  end

  describe "error handling" do
    it "exposes the request-id response header on API errors" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 400,
          body: Fixtures::Responses::ERROR_BAD_REQUEST,
          headers: HTTP::Headers{"request-id" => "req_abc123"}
        )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      ex = expect_raises(Anthropic::BadRequestError) do
        client.messages.create(
          model: "claude-sonnet-4-6",
          max_tokens: 100,
          messages: [{role: "user", content: "Hello"}]
        )
      end
      ex.request_id.should eq("req_abc123")
    end

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

  describe "proxy support" do
    it "raises APIConnectionError when the proxy refuses the connection" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        client = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://127.0.0.1:9", max_retries: 0)
        expect_raises(Anthropic::APIConnectionError) do
          client.get("/v1/models")
        end
      end
    end

    it "honors HTTPS_PROXY from the environment" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")
        ENV["HTTPS_PROXY"] = "http://127.0.0.1:9"

        client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
        expect_raises(Anthropic::APIConnectionError) do
          client.get("/v1/models")
        end
      end
    end

    it "prefers an explicit proxy over the environment" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")
        ENV["HTTPS_PROXY"] = "http://127.0.0.1:9"

        with_fake_proxy do |port, received|
          client = Anthropic::Client.new(
            api_key: "sk-ant-test",
            proxy: "http://127.0.0.1:#{port}",
            max_retries: 0,
            timeout: 10.seconds
          )
          # The fake proxy closes after CONNECT, so the TLS handshake fails —
          # but the CONNECT bytes prove the explicit proxy won over the env.
          expect_raises(Anthropic::APIConnectionError) do
            client.get("/v1/models")
          end
          receive_connect_head(received).should contain("CONNECT api.anthropic.com:443 HTTP/1.1")
        end
      end
    end

    it "bypasses the proxy when NO_PROXY matches" do
      with_saved_env("NO_PROXY", "no_proxy", "HTTPS_PROXY", "https_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("no_proxy")
        ENV["NO_PROXY"] = "api.anthropic.com"

        capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models", Fixtures::Responses::MODEL_LIST)
        client = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://127.0.0.1:9", max_retries: 0)
        client.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end

    it "bypasses all hosts when NO_PROXY is a wildcard" do
      with_saved_env("NO_PROXY", "no_proxy", "HTTPS_PROXY", "https_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("no_proxy")
        ENV["NO_PROXY"] = "*"

        capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models", Fixtures::Responses::MODEL_LIST)
        client = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://127.0.0.1:9", max_retries: 0)
        client.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end

    it "honors lowercase proxy env vars" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")
        ENV["https_proxy"] = "http://127.0.0.1:9"

        client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
        expect_raises(Anthropic::APIConnectionError) do
          client.get("/v1/models")
        end

        ENV.delete("https_proxy")
        ENV["no_proxy"] = "api.anthropic.com"
        capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models", Fixtures::Responses::MODEL_LIST)
        bypassing = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://127.0.0.1:9", max_retries: 0)
        bypassing.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end

    it "matches NO_PROXY subdomains and leading dots" do
      with_saved_env("NO_PROXY", "no_proxy", "HTTPS_PROXY", "https_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("no_proxy")
        ENV["NO_PROXY"] = ".example.com"

        capture = stub_and_capture(:get, "https://api.example.com/v1/models", Fixtures::Responses::MODEL_LIST)
        client = Anthropic::Client.new(
          api_key: "sk-ant-test",
          base_url: "https://api.example.com",
          proxy: "http://127.0.0.1:9",
          max_retries: 0
        )
        client.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end

    it "rejects non-http proxy schemes" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        tls_proxy = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "https://127.0.0.1:9", max_retries: 0)
        expect_raises(ArgumentError, /Only http:\/\/ proxies/) do
          tls_proxy.get("/v1/models")
        end

        socks_proxy = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "socks5://127.0.0.1:1080", max_retries: 0)
        expect_raises(ArgumentError, /Only http:\/\/ proxies/) do
          socks_proxy.get("/v1/models")
        end
      end
    end

    it "bypasses the proxy for plain-HTTP base URLs" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        capture = stub_and_capture(:get, "http://localhost:8080/v1/models", Fixtures::Responses::MODEL_LIST)
        client = Anthropic::Client.new(api_key: "sk-ant-test", base_url: "http://localhost:8080", proxy: "http://127.0.0.1:9")
        client.get("/v1/models")
        capture.path.should eq("/v1/models")
      end
    end

    it "raises ArgumentError for an invalid proxy URL" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        client = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://host:notaport", max_retries: 0)
        expect_raises(ArgumentError) do
          client.get("/v1/models")
        end

        missing_host = Anthropic::Client.new(api_key: "sk-ant-test", proxy: "http://:8080", max_retries: 0)
        expect_raises(ArgumentError) do
          missing_host.get("/v1/models")
        end
      end
    end

    it "tunnels via CONNECT with Proxy-Authorization" do
      with_saved_env("HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy") do
        ENV.delete("HTTPS_PROXY")
        ENV.delete("https_proxy")
        ENV.delete("NO_PROXY")
        ENV.delete("no_proxy")

        with_fake_proxy do |port, received|
          client = Anthropic::Client.new(
            api_key: "sk-ant-test",
            proxy: "http://proxyuser:proxypass@127.0.0.1:#{port}",
            max_retries: 0,
            timeout: 10.seconds
          )
          # The fake proxy closes after CONNECT, so the TLS handshake fails.
          expect_raises(Anthropic::APIConnectionError) do
            client.get("/v1/models")
          end

          head = receive_connect_head(received)
          head.should contain("CONNECT api.anthropic.com:443 HTTP/1.1")
          head.should contain("Proxy-Authorization: Basic #{Base64.strict_encode("proxyuser:proxypass")}")
        end
      end
    end
  end
end
