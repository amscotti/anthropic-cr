require "../../spec_helper"

describe Anthropic::Completions do
  completion_json = %({"id":"compl_123","type":"completion","completion":" Hello!","model":"claude-haiku-4-5-20251001","stop_reason":"stop_sequence"})

  it "creates a completion" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/complete", completion_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    completion = client.completions.create(
      model: "claude-haiku-4-5-20251001",
      prompt: "\n\nHuman: Hello!\n\nAssistant:",
      max_tokens_to_sample: 64
    )

    completion.should be_a(Anthropic::Completion)
    completion.id.should eq("compl_123")
    completion.completion.should eq(" Hello!")
    completion.stop_reason.should eq("stop_sequence")

    body = JSON.parse(capture.body.not_nil!)
    body["prompt"].as_s.should contain("Hello!")
    body["max_tokens_to_sample"].as_i.should eq(64)
    body["stream"].as_bool.should be_false
  end

  it "sends betas and workspace_id headers when given" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/complete", completion_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.completions.create(
      model: "claude-haiku-4-5-20251001",
      prompt: "\n\nHuman: Hi\n\nAssistant:",
      max_tokens_to_sample: 16,
      betas: ["some-beta-2026-01-01"],
      workspace_id: "ws_123"
    )

    headers = capture.headers.not_nil!
    headers["anthropic-beta"].should eq("some-beta-2026-01-01")
    headers["anthropic-workspace-id"].should eq("ws_123")
  end

  it "raises ArgumentError when create is called with stream: true" do
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    expect_raises(ArgumentError, /#stream/) do
      client.completions.create(
        model: "claude-haiku-4-5-20251001",
        prompt: "hi",
        max_tokens_to_sample: 16,
        stream: true
      )
    end
  end

  it "streams completion chunks" do
    body = "event: completion\n" \
           "data: {\"id\":\"compl_1\",\"type\":\"completion\",\"completion\":\" Hel\",\"model\":\"m\",\"stop_reason\":null}\n" \
           "\n" \
           "event: completion\n" \
           "data: {\"id\":\"compl_1\",\"type\":\"completion\",\"completion\":\"lo\",\"model\":\"m\",\"stop_reason\":\"stop_sequence\"}\n" \
           "\n"

    WebMock.stub(:post, "https://api.anthropic.com/v1/complete")
      .to_return do |request|
        JSON.parse(request.body.not_nil!)["stream"].as_bool.should be_true
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          body_io: IO::Memory.new(body)
        )
      end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    chunks = [] of Anthropic::Completion

    client.completions.stream(
      model: "claude-haiku-4-5-20251001",
      prompt: "\n\nHuman: Hi\n\nAssistant:",
      max_tokens_to_sample: 16
    ) do |chunk|
      chunks << chunk
    end

    chunks.size.should eq(2)
    chunks.map(&.completion).join.should eq(" Hello")
    chunks.last.stop_reason.should eq("stop_sequence")
  end

  it "raises ArgumentError when stream is called with stream: false" do
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    expect_raises(ArgumentError, /#create/) do
      client.completions.stream(
        model: "claude-haiku-4-5-20251001",
        prompt: "hi",
        max_tokens_to_sample: 16,
        stream: false
      ) { |_| }
    end
  end
end
