require "../spec_helper"

# Specs for the HTTP middleware system.
describe "HTTP Middleware" do
  describe "client-level middleware registration" do
    it "runs middleware around each request (outermost first)" do
      OrderMiddleware.reset
      stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test", middleware: [OrderMiddleware.new("outer"), OrderMiddleware.new("inner")])

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      )

      OrderMiddleware.log.should eq(["-> outer", "-> inner", "<- inner", "<- outer"])
    end

    it "does not engage the chain when no middleware is configured" do
      OrderMiddleware.reset
      stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      )

      OrderMiddleware.log.should be_empty
    end
  end

  describe "request/response rewriting" do
    it "lets middleware rewrite the request headers" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test", middleware: [AddHeaderMiddleware.new])

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["x-custom"]?.should eq("injected")
    end

    it "lets middleware short-circuit by returning a fabricated response" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: "should not reach")
      client = Anthropic::Client.new(api_key: "sk-ant-test", middleware: [ShortCircuitMiddleware.new])

      message = client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      )

      message.text.should eq("Hello! I'm Claude, an AI assistant.")
    end

    it "lets middleware observe 4xx without raising inside the chain" do
      stub_seen = false
      mw = ObservingMiddleware.new { |_req, resp| stub_seen = !resp.success? }

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 429, body: Fixtures::Responses::ERROR_RATE_LIMIT)
      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0, middleware: [mw])

      expect_raises(Anthropic::RateLimitError) do
        client.messages.create(
          model: Anthropic::Model::CLAUDE_SONNET_5,
          max_tokens: 64,
          messages: [{role: "user", content: "hi"}]
        )
      end

      stub_seen.should be_true
    end
  end
end

# --- Test middleware fixtures ---

class OrderMiddleware
  include Anthropic::Middleware
  @@log = [] of String

  def initialize(@name : String)
  end

  def self.log : Array(String)
    @@log
  end

  def self.reset : Nil
    @@log.clear
  end

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    @@log << "-> #{@name}"
    response = nxt.call(request)
    @@log << "<- #{@name}"
    response
  end
end

class AddHeaderMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    new_headers = request.headers.dup
    new_headers["x-custom"] = "injected"
    nxt.call(request.with(headers: new_headers))
  end
end

class ShortCircuitMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    Anthropic::APIResponse.new(
      200,
      HTTP::Headers{"Content-Type" => "application/json"},
      Fixtures::Responses::MESSAGE_BASIC,
      request,
    )
  end
end

class ObservingMiddleware
  include Anthropic::Middleware

  def initialize(&@block : Anthropic::APIRequest, Anthropic::APIResponse -> Nil)
  end

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    response = nxt.call(request)
    @block.call(request, response)
    response
  end
end
