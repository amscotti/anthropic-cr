require "../spec_helper"

describe Anthropic::Vertex::Client do
  it "requires a region and project" do
    expect_raises(ArgumentError, /region/) do
      Anthropic::Vertex::Client.new(project_id: "proj")
    end

    expect_raises(ArgumentError, /project_id/) do
      Anthropic::Vertex::Client.new(region: "us-central1")
    end
  end

  it "derives regional base URLs" do
    Anthropic::Vertex::Client.default_base_url("global").should eq("https://aiplatform.googleapis.com/v1")
    Anthropic::Vertex::Client.default_base_url("us").should eq("https://aiplatform.us.rep.googleapis.com/v1")
    Anthropic::Vertex::Client.default_base_url("eu").should eq("https://aiplatform.eu.rep.googleapis.com/v1")
    Anthropic::Vertex::Client.default_base_url("us-central1").should eq("https://us-central1-aiplatform.googleapis.com/v1")
  end

  it "rewrites /v1/messages to rawPredict with a Bearer token" do
    capture = RequestCapture.new
    WebMock.stub(:post, /aiplatform\.googleapis\.com\/v1\/projects\//).to_return do |request|
      capture.body = request.body.to_s
      capture.headers = request.headers
      capture.path = request.resource
      HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
    end

    client = Anthropic::Vertex::Client.new(
      region: "us-central1",
      project_id: "proj-123",
      access_token: "vertex-test-token-abc",
    )

    message = client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}]
    )

    message.should be_a(Anthropic::Message)
    capture.path.not_nil!.should contain("/v1/projects/proj-123/locations/us-central1/publishers/anthropic/models/claude-sonnet-4-6:rawPredict")
    headers = capture.headers.not_nil!
    headers["authorization"].should eq("Bearer vertex-test-token-abc")
    headers["x-api-key"]?.should be_nil

    body = JSON.parse(capture.body.not_nil!)
    body.as_h.has_key?("model").should be_false
    body["anthropic_version"].as_s.should eq("vertex-2023-10-16")
    body["max_tokens"].as_i.should eq(32)
  end

  it "uses streamRawPredict for streaming requests" do
    capture = RequestCapture.new
    WebMock.stub(:post, /aiplatform\.googleapis\.com\/v1\/projects\//).to_return do |request|
      capture.path = request.resource
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
        body_io: IO::Memory.new("data: [DONE]\n\n")
      )
    end

    client = Anthropic::Vertex::Client.new(
      region: "us-central1",
      project_id: "proj-123",
      access_token: "vertex-test-token-abc",
    )

    client.messages.stream(
      model: "claude-sonnet-4-6",
      max_tokens: 16,
      messages: [{role: "user", content: "hi"}]
    ) { |_| }

    capture.path.not_nil!.should contain(":streamRawPredict")
  end

  it "rejects the Batch API" do
    client = Anthropic::Vertex::Client.new(
      region: "us-central1",
      project_id: "proj-123",
      access_token: "vertex-test-token-abc",
    )

    expect_raises(NotImplementedError, /Batch API/) do
      client.post("/v1/messages/batches", {"foo" => "bar"})
    end
  end
end

describe Anthropic::GoogleCloud::Client do
  it "requires a workspace ID unless skip_auth is set" do
    expect_raises(ArgumentError, /workspace/) do
      Anthropic::GoogleCloud::Client.new(project: "proj-123")
    end
  end

  it "derives the gateway base URL" do
    client = Anthropic::GoogleCloud::Client.new(
      project: "proj-123",
      location: "global",
      workspace_id: "ws_123",
      access_token: "vertex-test-token-abc",
    )

    client.messages.should be_a(Anthropic::Messages)
  end

  it "sends Bearer auth through the gateway untouched" do
    capture = RequestCapture.new
    WebMock.stub(:post, /claude\.googleapis\.com\/v1alpha\/projects\//).to_return do |request|
      capture.body = request.body.to_s
      capture.headers = request.headers
      capture.path = request.resource
      HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
    end

    client = Anthropic::GoogleCloud::Client.new(
      project: "proj-123",
      location: "global",
      workspace_id: "ws_123",
      access_token: "vertex-test-token-abc",
    )

    message = client.messages.create(
      model: "claude-sonnet-5",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}]
    )

    message.should be_a(Anthropic::Message)
    capture.path.not_nil!.should contain("/v1alpha/projects/proj-123/locations/global/workspaces/ws_123/invoke/v1/messages")
    headers = capture.headers.not_nil!
    headers["authorization"].should eq("Bearer vertex-test-token-abc")
    headers["x-api-key"]?.should be_nil

    JSON.parse(capture.body.not_nil!)["model"].as_s.should eq("claude-sonnet-5")
  end

  it "supports skip_auth with an explicit base URL" do
    WebMock.stub(:post, "https://proxy.test/v1/messages")
      .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

    client = Anthropic::GoogleCloud::Client.new(
      base_url: "https://proxy.test",
      skip_auth: true
    )

    client.skip_auth?.should be_true
    client.messages.create(
      model: "claude-sonnet-5",
      max_tokens: 8,
      messages: [{role: "user", content: "hi"}]
    ).should be_a(Anthropic::Message)
  end
end

describe Anthropic::GoogleAuth::Provider do
  it "returns an explicit access token without network access" do
    provider = Anthropic::GoogleAuth::Provider.new(access_token: "static-token")
    provider.token.should eq("static-token")
    provider.authorization_header.should eq("Bearer static-token")
  end

  it "calls the token provider proc" do
    calls = 0
    provider = Anthropic::GoogleAuth::Provider.new(token_provider: -> {
      calls += 1
      "proc-token"
    })
    provider.token.should eq("proc-token")
    calls.should eq(1)
  end

  it "refreshes authorized_user credentials from disk" do
    adc = %({"type":"authorized_user","client_id":"cid","client_secret":"csec","refresh_token":"rtok"})
    path = File.tempfile("adc", ".json") do |file|
      file.print(adc)
    end.path

    WebMock.stub(:post, "https://oauth2.googleapis.com/token")
      .to_return(body: %({"access_token":"refreshed","expires_in":3600,"token_type":"Bearer"}))

    begin
      provider = Anthropic::GoogleAuth::Provider.new(credentials_path: path)
      provider.token.should eq("refreshed")
    ensure
      File.delete(path)
    end
  end

  it "rejects service-account key files with an actionable error" do
    adc = %({"type":"service_account","project_id":"p","private_key":"k","client_email":"e"})
    path = File.tempfile("adc-sa", ".json") do |file|
      file.print(adc)
    end.path

    begin
      provider = Anthropic::GoogleAuth::Provider.new(
        credentials_path: path,
        enable_metadata_server: false
      )
      expect_raises(ArgumentError, /RS256/) do
        provider.token
      end
    ensure
      File.delete(path)
    end
  end
end

describe Anthropic::AWS::Client do
  it "sends x-api-key and workspace headers in API-key mode" do
    capture = RequestCapture.new
    WebMock.stub(:post, /aws-external-anthropic\.us-east-1\.api\.aws\/v1\/messages/).to_return do |request|
      capture.body = request.body.to_s
      capture.headers = request.headers
      HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
    end

    client = Anthropic::AWS::Client.new(
      api_key: "aws-gateway-key",
      aws_region: "us-east-1",
      workspace_id: "ws_123"
    )

    client.api_key_mode?.should be_true
    message = client.messages.create(
      model: "claude-sonnet-5",
      max_tokens: 32,
      messages: [{role: "user", content: "hi"}]
    )

    message.should be_a(Anthropic::Message)
    headers = capture.headers.not_nil!
    headers["x-api-key"].should eq("aws-gateway-key")
    headers["anthropic-workspace-id"].should eq("ws_123")
    headers["Authorization"]?.should be_nil
  end

  it "SigV4-signs requests with explicit credentials" do
    capture = RequestCapture.new
    WebMock.stub(:post, /aws-external-anthropic\.eu-west-1\.api\.aws\/v1\/messages/).to_return do |request|
      capture.headers = request.headers
      HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
    end

    client = Anthropic::AWS::Client.new(
      aws_access_key: "[REDACTED]",
      aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      aws_region: "eu-west-1"
    )

    client.api_key_mode?.should be_false
    client.messages.create(
      model: "claude-sonnet-5",
      max_tokens: 8,
      messages: [{role: "user", content: "hi"}]
    ).should be_a(Anthropic::Message)

    headers = capture.headers.not_nil!
    headers["Authorization"].should start_with("AWS4-HMAC-SHA256")
    headers["x-api-key"]?.should be_nil
  end

  it "prefers an explicit api_key over platform args" do
    capture = RequestCapture.new
    WebMock.stub(:post, /aws-external-anthropic\.us-east-1\.api\.aws\/v1\/messages/).to_return do |request|
      capture.headers = request.headers
      HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
    end

    client = Anthropic::AWS::Client.new(
      api_key: "explicit-key",
      aws_access_key: "[REDACTED]",
      aws_secret_key: "secret",
      aws_region: "us-east-1"
    )

    client.api_key_mode?.should be_true
    client.messages.create(
      model: "claude-sonnet-5",
      max_tokens: 8,
      messages: [{role: "user", content: "hi"}]
    ).should be_a(Anthropic::Message)

    headers = capture.headers.not_nil!
    headers["x-api-key"].should eq("explicit-key")
    headers["Authorization"]?.should be_nil
  end

  it "requires a region in SigV4 mode" do
    expect_raises(ArgumentError, /region/) do
      Anthropic::AWS::Client.new(
        aws_access_key: "[REDACTED]",
        aws_secret_key: "secret",
        aws_region: ""
      )
    end
  end
end
