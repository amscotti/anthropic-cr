require "../../spec_helper"

describe "Anthropic::Bedrock::Client streaming" do
  it "rewrites stream requests to invoke-with-response-stream and SigV4-signs" do
    capture = nil
    ping = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"message_stop"}))

    WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |request|
      capture = request
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "application/vnd.amazon.eventstream"},
        body_io: IO::Memory.new(ping),
      )
    end

    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAIOSFODNN7EXAMPLE",
      aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      aws_region: "us-east-1",
    )

    events = [] of Anthropic::AnyStreamEvent
    client.messages.stream(
      model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
      max_tokens: 16,
      messages: [{role: "user", content: "hi"}],
    ) do |event|
      events << event
    end

    req = capture.not_nil!
    req.uri.to_s.should contain("/model/us.anthropic.claude-haiku-4-5-20251001-v1:0/invoke-with-response-stream")
    req.headers["Authorization"]?.should be_truthy
    req.headers["Authorization"].should start_with("AWS4-HMAC-SHA256")
    req.headers["x-api-key"]?.should be_nil

    body = JSON.parse(req.body.not_nil!)
    body.as_h.has_key?("model").should be_false
    body.as_h.has_key?("stream").should be_false
    body["anthropic_version"].as_s.should eq("bedrock-2023-05-31")

    events.size.should eq(1)
    events[0].should be_a(Anthropic::MessageStopEvent)
  end

  it "transcodes multi-event AWS streams into MessageStream text" do
    frames = [
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"message_start","message":{"id":"msg_b","type":"message","role":"assistant","content":[],"model":"claude-haiku","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":0}}})
      ),
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})
      ),
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello Bedrock"}})
      ),
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"content_block_stop","index":0})
      ),
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":3}})
      ),
      Anthropic::Bedrock::EventStream.encode_chunk_event(
        %({"type":"message_stop"})
      ),
    ]

    total = frames.sum(&.size)
    blob = Bytes.new(total)
    offset = 0
    frames.each do |frame|
      frame.copy_to(blob + offset)
      offset += frame.size
    end

    WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |_request|
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "application/vnd.amazon.eventstream"},
        body_io: IO::Memory.new(blob),
      )
    end

    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-east-1",
    )

    text = nil
    client.messages.open_stream(
      model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}],
    ) do |stream|
      text = stream.collect_text
    end

    text.should eq("Hello Bedrock")
  end

  it "raises typed API errors from in-stream exception frames" do
    frame = Anthropic::Bedrock::EventStream.encode_exception(
      "throttlingException",
      "Rate exceeded"
    )

    WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |_request|
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

    expect_raises(Anthropic::APIError, /Rate exceeded/) do
      client.messages.stream(
        model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        max_tokens: 16,
        messages: [{role: "user", content: "hi"}],
      ) { }
    end
  end
end

describe Anthropic::Bedrock::Beta do
  it "exposes beta.messages and rejects other beta surfaces" do
    client = Anthropic::Bedrock::Client.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-east-1",
    )

    client.beta.should be_a(Anthropic::Bedrock::Beta)
    client.beta.messages.should be_a(Anthropic::BetaMessages)

    expect_raises(NotImplementedError, /beta\.files/) do
      client.beta.files
    end

    expect_raises(NotImplementedError, /beta\.dreams/) do
      client.beta.dreams
    end

    expect_raises(NotImplementedError, /beta\.tunnels/) do
      client.beta.tunnels
    end

    expect_raises(NotImplementedError, /beta\.sessions/) do
      client.beta.sessions
    end
  end
end
