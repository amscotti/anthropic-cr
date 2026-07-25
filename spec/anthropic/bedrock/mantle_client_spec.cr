require "../../spec_helper"

describe Anthropic::Bedrock::MantleClient do
  response_body = Fixtures::Responses::MESSAGE_BASIC

  it "posts native /v1/messages with model in body and SigV4 (bedrock-mantle)" do
    capture = nil
    WebMock.stub(:post, /bedrock-mantle\.us-east-1\.api\.aws\/anthropic\/v1\/messages/).to_return do |request|
      capture = request
      HTTP::Client::Response.new(200, body: response_body)
    end

    client = Anthropic::Bedrock::MantleClient.new(
      aws_access_key: "AKIAIOSFODNN7EXAMPLE",
      aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      aws_region: "us-east-1",
    )

    message = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}],
    )

    message.should be_a(Anthropic::Message)
    req = capture.not_nil!
    # WebMock exposes path on uri/resource; host is in the Host header.
    req.headers["Host"]?.should eq("bedrock-mantle.us-east-1.api.aws")
    # Default Mantle base includes /anthropic prefix; path is native Anthropic (no invoke rewrite)
    req.resource.should eq("/anthropic/v1/messages")
    req.uri.path.should eq("/anthropic/v1/messages")
    req.uri.path.should_not contain("/model/")
    req.uri.path.should_not contain("/invoke")

    req.headers["Authorization"]?.should be_truthy
    req.headers["Authorization"].should start_with("AWS4-HMAC-SHA256")
    req.headers["Authorization"].should contain("/us-east-1/bedrock-mantle/aws4_request")
    req.headers["x-amz-date"]?.should be_truthy
    req.headers["x-api-key"]?.should be_nil

    body = JSON.parse(req.body.not_nil!)
    body["model"].as_s.should eq("claude-haiku-4-5-20251001")
    body["max_tokens"].as_i.should eq(32)
    body["messages"].as_a.size.should eq(1)
    body.as_h.has_key?("anthropic_version").should be_false
  end

  it "uses Bearer auth when api_key is provided" do
    capture = nil
    WebMock.stub(:post, /bedrock-mantle\.eu-west-1\.api\.aws\/anthropic\/v1\/messages/).to_return do |request|
      capture = request
      HTTP::Client::Response.new(200, body: response_body)
    end

    client = Anthropic::Bedrock::MantleClient.new(
      api_key: "bedrock-bearer-token",
      aws_region: "eu-west-1",
    )

    client.use_sig_v4?.should be_false
    client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 16,
      messages: [{role: "user", content: "hi"}],
    )

    req = capture.not_nil!
    req.headers["Authorization"]?.should eq("Bearer bedrock-bearer-token")
    req.headers["x-api-key"]?.should be_nil
    req.resource.should eq("/anthropic/v1/messages")
    body = JSON.parse(req.body.not_nil!)
    body["model"].as_s.should eq("claude-haiku-4-5-20251001")
  end

  it "respects ANTHROPIC_BEDROCK_MANTLE_BASE_URL override" do
    capture = nil
    WebMock.stub(:post, "https://mantle.example.com/v1/messages").to_return do |request|
      capture = request
      HTTP::Client::Response.new(200, body: response_body)
    end

    client = Anthropic::Bedrock::MantleClient.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-west-2",
      base_url: "https://mantle.example.com",
    )

    client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 8,
      messages: [{role: "user", content: "hi"}],
    )

    req = capture.not_nil!
    req.headers["Host"]?.should eq("mantle.example.com")
    req.resource.should eq("/v1/messages")
    req.headers["Authorization"].should contain("/bedrock-mantle/aws4_request")
  end

  it "rejects models, batches, and non-messages beta resources" do
    client = Anthropic::Bedrock::MantleClient.new(
      aws_access_key: "AKIAEXAMPLE",
      aws_secret_key: "secret",
      aws_region: "us-east-1",
    )

    expect_raises(NotImplementedError, /Models listing/) do
      client.models.list
    end

    expect_raises(NotImplementedError, /Batch API/) do
      client.post("/v1/messages/batches", {"foo" => "bar"})
    end

    expect_raises(NotImplementedError, /Token counting/) do
      client.post("/v1/messages/count_tokens", {"foo" => "bar"})
    end

    expect_raises(NotImplementedError, /Beta files/) do
      client.beta.files
    end

    expect_raises(NotImplementedError, /Beta models/) do
      client.beta.models
    end

    client.beta.messages.should be_a(Anthropic::BetaMessages)
  end

  it "rejects partial AWS credentials" do
    expect_raises(ArgumentError, /must be provided together/) do
      Anthropic::Bedrock::MantleClient.new(
        aws_access_key: "AKIAEXAMPLE",
        aws_region: "us-east-1",
      )
    end
  end

  it "raises when region and base URL are both missing" do
    # Isolate from ambient AWS region env vars.
    original_region = ENV["AWS_REGION"]?
    original_default = ENV["AWS_DEFAULT_REGION"]?
    original_mantle = ENV["ANTHROPIC_BEDROCK_MANTLE_BASE_URL"]?
    ENV.delete("AWS_REGION")
    ENV.delete("AWS_DEFAULT_REGION")
    ENV.delete("ANTHROPIC_BEDROCK_MANTLE_BASE_URL")

    begin
      expect_raises(ArgumentError, /No AWS region or base URL/) do
        Anthropic::Bedrock::MantleClient.new(
          api_key: "bearer-only",
        )
      end
    ensure
      original_region.try { |v| ENV["AWS_REGION"] = v }
      original_default.try { |v| ENV["AWS_DEFAULT_REGION"] = v }
      original_mantle.try { |v| ENV["ANTHROPIC_BEDROCK_MANTLE_BASE_URL"] = v }
    end
  end

  it "skips auth when skip_auth is true" do
    capture = nil
    WebMock.stub(:post, "https://proxy.example.com/v1/messages").to_return do |request|
      capture = request
      HTTP::Client::Response.new(200, body: response_body)
    end

    client = Anthropic::Bedrock::MantleClient.new(
      skip_auth: true,
      base_url: "https://proxy.example.com",
    )

    client.skip_auth?.should be_true
    client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 8,
      messages: [{role: "user", content: "hi"}],
    )

    req = capture.not_nil!
    req.headers["Authorization"]?.should be_nil
    req.headers["x-api-key"]?.should be_nil
    req.headers["x-amz-date"]?.should be_nil
  end
end
