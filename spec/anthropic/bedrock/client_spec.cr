require "../../spec_helper"

describe Anthropic::Bedrock::Client do
  response_body = Fixtures::Responses::MESSAGE_BASIC

  it "rewrites /v1/messages to Bedrock invoke and SigV4-signs the request" do
    capture = nil
    WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |request|
      capture = request
      HTTP::Client::Response.new(200, body: response_body)
    end

    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAIOSFODNN7EXAMPLE",
      aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      aws_region: "us-east-1",
    )

    message = client.messages.create(
      model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}],
    )

    message.should be_a(Anthropic::Message)
    req = capture.not_nil!
    req.uri.to_s.should contain("/model/us.anthropic.claude-haiku-4-5-20251001-v1:0/invoke")
    req.headers["Authorization"]?.should be_truthy
    req.headers["Authorization"].should start_with("AWS4-HMAC-SHA256")
    req.headers["x-amz-date"]?.should be_truthy
    req.headers["x-api-key"]?.should be_nil

    body = JSON.parse(req.body.not_nil!)
    body.as_h.has_key?("model").should be_false
    body.as_h.has_key?("stream").should be_false
    body["anthropic_version"].as_s.should eq("bedrock-2023-05-31")
    body["max_tokens"].as_i.should eq(32)
    body["messages"].as_a.size.should eq(1)
  end

  it "rejects batch and count_tokens routes" do
    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-east-1",
    )

    expect_raises(NotImplementedError, /Batch API/) do
      client.post("/v1/messages/batches", {"foo" => "bar"})
    end

    expect_raises(NotImplementedError, /Token counting/) do
      client.post("/v1/messages/count_tokens", {"foo" => "bar"})
    end

    expect_raises(NotImplementedError, /Bedrock control plane/) do
      client.models.list
    end
  end

  it "rejects combining bearer token with AWS credentials" do
    expect_raises(ArgumentError, /Cannot specify both/) do
      Anthropic::Bedrock::Client.new(
        api_key: "bedrock-bearer",
        aws_access_key: "AKIAEXAMPLE",
        aws_secret_key: "secret",
      )
    end
  end

  it "supports messages.stream via invoke-with-response-stream path rewrite" do
    frame = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"message_stop"}))
    capture = nil

    WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |request|
      capture = request
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "application/vnd.amazon.eventstream"},
        body_io: IO::Memory.new(frame),
      )
    end

    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-east-1",
    )

    events = [] of Anthropic::AnyStreamEvent
    client.messages.stream(
      model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
      max_tokens: 16,
      messages: [{role: "user", content: "hi"}],
    ) { |event| events << event }

    capture.not_nil!.uri.to_s.should contain("invoke-with-response-stream")
    events[0].should be_a(Anthropic::MessageStopEvent)
  end
end
