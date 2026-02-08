require "../../spec_helper"

describe "Token Counting API" do
  describe Anthropic::TokenCountResponse do
    it "parses basic token count" do
      response = Anthropic::TokenCountResponse.from_json(Fixtures::Responses::TOKEN_COUNT_BASIC)

      response.input_tokens.should eq(25)
      response.cache_creation_input_tokens.should be_nil
      response.cache_read_input_tokens.should be_nil
    end

    it "parses token count with cache creation" do
      response = Anthropic::TokenCountResponse.from_json(Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)

      response.input_tokens.should eq(1500)
      response.cache_creation_input_tokens.should eq(1200)
      response.cache_read_input_tokens.should eq(0)
    end

    it "parses token count with cache hit" do
      response = Anthropic::TokenCountResponse.from_json(Fixtures::Responses::TOKEN_COUNT_CACHE_HIT)

      response.input_tokens.should eq(1500)
      response.cache_creation_input_tokens.should eq(0)
      response.cache_read_input_tokens.should eq(1200)
    end

    it "calculates total billable tokens" do
      response = Anthropic::TokenCountResponse.from_json(Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)

      response.total_billable_tokens.should eq(2700) # 1500 + 1200
    end
  end

  describe Anthropic::Messages do
    describe "#count_tokens" do
      it "makes correct request to count tokens" do
        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
          .to_return(body: Fixtures::Responses::TOKEN_COUNT_BASIC)

        client = Anthropic::Client.new(api_key: "sk-ant-test")
        count = client.messages.count_tokens(
          model: "claude-sonnet-4-5-20250929",
          messages: [{role: "user", content: "Hello!"}]
        )

        count.input_tokens.should eq(25)
      end

      it "returns TokenCountResponse type" do
        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
          .to_return(body: Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)

        client = Anthropic::Client.new(api_key: "sk-ant-test")
        count = client.messages.count_tokens(
          model: "claude-sonnet-4-5-20250929",
          messages: [{role: "user", content: "Hello!"}],
          system: "You are helpful."
        )

        count.should be_a(Anthropic::TokenCountResponse)
        count.input_tokens.should eq(1500)
        count.cache_creation_input_tokens.should eq(1200)
      end
    end
  end
end

describe "Cache Control" do
  describe Anthropic::CacheControl do
    it "creates ephemeral cache control" do
      cache = Anthropic::CacheControl.ephemeral

      cache.type.should eq("ephemeral")
      cache.ttl.should be_nil
    end

    it "creates one-hour cache control" do
      cache = Anthropic::CacheControl.one_hour

      cache.type.should eq("ephemeral")
      cache.ttl.should eq(3600)
    end

    it "creates custom TTL cache control" do
      cache = Anthropic::CacheControl.with_ttl(7200)

      cache.type.should eq("ephemeral")
      cache.ttl.should eq(7200)
    end

    it "serializes ephemeral correctly" do
      cache = Anthropic::CacheControl.ephemeral
      json = cache.to_json

      json.should eq(%({"type":"ephemeral"}))
    end

    it "serializes one-hour with TTL correctly" do
      cache = Anthropic::CacheControl.one_hour
      json = cache.to_json

      json.should eq(%({"type":"ephemeral","ttl":3600}))
    end
  end
end

describe "Compaction Config" do
  describe Anthropic::CompactionConfig do
    it "creates disabled config by default" do
      config = Anthropic::CompactionConfig.new

      config.enabled?.should be_false
      config.context_token_threshold.should eq(10000)
      config.on_compact.should be_nil
    end

    it "creates enabled config with callback" do
      callback_called = false
      tokens_before = 0
      tokens_after = 0

      config = Anthropic::CompactionConfig.enabled(threshold: 5000) do |before, after|
        callback_called = true
        tokens_before = before
        tokens_after = after
      end

      config.enabled?.should be_true
      config.context_token_threshold.should eq(5000)

      # Call the callback
      config.on_compact.try(&.call(1000, 500))
      callback_called.should be_true
      tokens_before.should eq(1000)
      tokens_after.should eq(500)
    end
  end
end

describe "Beta Constants" do
  it "defines web search beta header" do
    Anthropic::WEB_SEARCH_BETA.should eq("web-search-2025-03-05")
  end

  it "defines structured output beta header" do
    Anthropic::STRUCTURED_OUTPUT_BETA.should eq("structured-outputs-2025-11-13")
  end

  it "defines files API beta header" do
    Anthropic::FILES_API_BETA.should eq("files-api-2025-04-14")
  end

  it "defines extended cache TTL beta header" do
    Anthropic::EXTENDED_CACHE_TTL_BETA.should eq("extended-cache-ttl-2025-04-11")
  end

  it "defines token efficient tools beta header" do
    Anthropic::TOKEN_EFFICIENT_TOOLS_BETA.should eq("token-efficient-tools-2025-02-19")
  end

  it "defines fine-grained streaming beta header" do
    Anthropic::FINE_GRAINED_STREAMING_BETA.should eq("fine-grained-tool-streaming-2025-05-14")
  end

  it "defines code execution beta header" do
    Anthropic::CODE_EXECUTION_BETA.should eq("code-execution-2025-08-25")
  end

  it "defines MCP connector beta header" do
    Anthropic::MCP_CONNECTOR_BETA.should eq("mcp-connector-2025-05-01")
  end

  it "defines advanced tool use beta header" do
    Anthropic::ADVANCED_TOOL_USE_BETA.should eq("advanced-tool-use-2025-11-20")
  end
end
