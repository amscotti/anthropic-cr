require "../spec_helper"

describe Anthropic::BetaRefusalFallbackMiddleware do
  it "raises when constructed with an empty fallback chain" do
    expect_raises(ArgumentError, /at least one fallback/) do
      Anthropic::BetaRefusalFallbackMiddleware.new([] of Anthropic::FallbackParam)
    end
  end

  it "passes through non-messages requests untouched" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=20")
      .to_return(body: %({"data":[],"has_more":false,"first_id":null,"last_id":null}))
    client = Anthropic::Client.new(
      api_key: "sk-ant-test",
      middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )],
    )

    response = client.models.list
    response.data.size.should eq(0)
  end

  it "retries down the fallback chain on a refusal and returns the accepting response" do
    refusal = %({"id":"msg_r","type":"message","role":"assistant","content":[{"type":"text","text":"no"}],"model":"claude-fable-5","stop_reason":"refusal","stop_details":{"type":"refusal","category":"frontier_llm","fallback_credit_token":"fct_1"},"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":2}})
    accepted = %({"id":"msg_a","type":"message","role":"assistant","content":[{"type":"text","text":"here you go"}],"model":"claude-opus-4-8","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":4}})

    # First call (primary) refuses, second call (fallback) accepts.
    call_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
      call_count += 1
      HTTP::Client::Response.new(200, body: call_count == 1 ? refusal : accepted)
    end

    client = Anthropic::Client.new(
      api_key: "sk-ant-test",
      max_retries: 0,
      middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )],
    )

    message = client.beta.messages.create(
      model: Anthropic::Model::CLAUDE_FABLE_5,
      max_tokens: 64,
      messages: [{role: "user", content: "hi"}],
    )

    message.model.should eq("claude-opus-4-8")
    message.text.should eq("here you go")
    call_count.should eq(2)
  end

  it "returns the final refusal when the chain is exhausted" do
    refusal1 = %({"id":"msg_r1","type":"message","role":"assistant","content":[],"model":"claude-fable-5","stop_reason":"refusal","stop_details":{"type":"refusal","category":"frontier_llm","fallback_credit_token":"fct_1"},"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}})
    refusal2 = %({"id":"msg_r2","type":"message","role":"assistant","content":[],"model":"claude-opus-4-8","stop_reason":"refusal","stop_details":{"type":"refusal","category":"bio"},"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}})

    call_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
      call_count += 1
      HTTP::Client::Response.new(200, body: call_count == 1 ? refusal1 : refusal2)
    end

    client = Anthropic::Client.new(
      api_key: "sk-ant-test",
      max_retries: 0,
      middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )],
    )

    message = client.beta.messages.create(
      model: Anthropic::Model::CLAUDE_FABLE_5,
      max_tokens: 64,
      messages: [{role: "user", content: "hi"}],
    )

    message.stop_reason.should eq("refusal")
    message.model.should eq("claude-opus-4-8")
    call_count.should eq(2)
  end

  it "raises when the request body also sends server-side fallbacks" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
      .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

    client = Anthropic::Client.new(
      api_key: "sk-ant-test",
      max_retries: 0,
      middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )],
    )

    expect_raises(ArgumentError, /incompatible/) do
      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 64,
        betas: [Anthropic::SERVER_SIDE_FALLBACK_BETA],
        fallbacks: [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
        messages: [{role: "user", content: "hi"}],
      )
    end
  end

  it "tags every hop with the fallback-credit beta and helper header" do
    refusal = %({"id":"msg_r","type":"message","role":"assistant","content":[],"model":"claude-fable-5","stop_reason":"refusal","stop_details":{"type":"refusal","category":"frontier_llm","fallback_credit_token":"fct_1"},"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}})
    accepted = %({"id":"msg_a","type":"message","role":"assistant","content":[{"type":"text","text":"ok"}],"model":"claude-opus-4-8","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":2}})

    call_count = 0
    captured_requests = [] of HTTP::Request
    WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
      captured_requests << req
      call_count += 1
      HTTP::Client::Response.new(200, body: call_count == 1 ? refusal : accepted)
    end

    client = Anthropic::Client.new(
      api_key: "sk-ant-test",
      max_retries: 0,
      middleware: [Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )],
    )

    client.beta.messages.create(
      model: Anthropic::Model::CLAUDE_FABLE_5,
      max_tokens: 64,
      messages: [{role: "user", content: "hi"}],
    )

    captured_requests.size.should eq(2)
    captured_requests.each do |req|
      req.headers["anthropic-beta"].should contain(Anthropic::FALLBACK_CREDIT_BETA)
      req.headers["x-stainless-helper"].should contain(Anthropic::StainlessHelper::FALLBACK_REFUSAL_MIDDLEWARE)
    end

    # Retry hops carry a different body, so they must not reuse the original
    # idempotency key (a key-honoring server would replay the cached refusal).
    captured_requests[0].headers["idempotency-key"].should_not eq(captured_requests[1].headers["idempotency-key"])

    # The retry body carries the credit token + swapped model.
    body2 = JSON.parse(captured_requests[1].body.not_nil!.gets_to_end)
    body2["model"].as_s.should eq("claude-opus-4-8")
    body2["fallback_credit_token"].as_s.should eq("fct_1")
  end
end
