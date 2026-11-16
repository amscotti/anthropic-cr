require "socket"
require "../spec_helper"

private class ProviderBetaCaptureMiddleware
  include Anthropic::Middleware

  getter seen_beta = [] of Bool

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    @seen_beta << request.beta?
    nxt.call(request)
  end
end

private def with_temp_env(vars : Hash(String, String?), &)
  saved = {} of String => String?
  vars.each_key { |key| saved[key] = ENV[key]? }
  begin
    vars.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    saved.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end

describe "v0.12.0 cloud providers parity (2026-10-21)" do
  describe "supports_message_threads?" do
    it "is true for AWS and GoogleCloud, and false for Bedrock, Mantle, and Vertex" do
      aws = Anthropic::AWS::Client.new(api_key: "aws-k", aws_region: "us-east-1", workspace_id: "ws_1")
      gc = Anthropic::GoogleCloud::Client.new(project: "proj-1", skip_auth: true)
      bedrock = Anthropic::Bedrock::Client.new(api_key: "br-k", aws_region: "us-east-1")
      mantle = Anthropic::Bedrock::MantleClient.new(api_key: "mt-k", aws_region: "us-east-1")
      vertex = Anthropic::Vertex::Client.new(region: "us-central1", project_id: "proj-1", access_token: "tok")

      aws.supports_message_threads?.should be_true
      gc.supports_message_threads?.should be_true
      bedrock.supports_message_threads?.should be_false
      mantle.supports_message_threads?.should be_false
      vertex.supports_message_threads?.should be_false

      aws.with_options(max_retries: 0).supports_message_threads?.should be_true
      gc.with_options(max_retries: 0).supports_message_threads?.should be_true
      bedrock.with_options(max_retries: 0).supports_message_threads?.should be_false
      mantle.with_options(max_retries: 0).supports_message_threads?.should be_false
      vertex.with_options(max_retries: 0).supports_message_threads?.should be_false
    end
  end

  describe "HTTP status and (status_code, error_code) error delegation" do
    it "delegates Bedrock::Client, Bedrock::MantleClient, and Vertex::Client errors to Anthropic.build_api_error" do
      WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//)
        .to_return(
          status: 400,
          body: %({"error":{"type":"invalid_request_error","message":"duplicate tool","details":{"error_code":"tool_name_conflict"}}}),
        )
      bedrock = Anthropic::Bedrock::Client.new(api_key: "br-k", aws_region: "us-east-1", max_retries: 0)
      expect_raises(Anthropic::ToolNameConflictError) do
        bedrock.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      end
      expect_raises(Anthropic::ToolNameConflictError) do
        bedrock.messages.stream(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}]) { |_| }
      end

      WebMock.stub(:post, /bedrock-mantle\.us-east-1\.api\.aws\/anthropic\/v1\/messages/)
        .to_return(
          status: 499,
          body: %({"error":{"type":"invalid_request_error","message":"client closed"}}),
        )
      mantle = Anthropic::Bedrock::MantleClient.new(api_key: "mt-k", aws_region: "us-east-1", max_retries: 0)
      expect_raises(Anthropic::ClientClosedRequestError) do
        mantle.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      end
      expect_raises(Anthropic::ClientClosedRequestError) do
        mantle.messages.stream(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}]) { |_| }
      end

      WebMock.stub(:post, /us-central1-aiplatform\.googleapis\.com\/v1\/projects\//)
        .to_return(
          status: 404,
          body: %({"error":{"type":"not_found_error","message":"missing thread","details":{"error_code":"thread_not_found"}}}),
        )
      vertex = Anthropic::Vertex::Client.new(region: "us-central1", project_id: "proj-1", access_token: "tok", max_retries: 0)
      expect_raises(Anthropic::ThreadNotFoundError) do
        vertex.messages.create(model: "claude-sonnet-4-6", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      end
      expect_raises(Anthropic::ThreadNotFoundError) do
        vertex.messages.stream(model: "claude-sonnet-4-6", max_tokens: 8, messages: [{role: "user", content: "hi"}]) { |_| }
      end
    end

    it "maps 408, 412, 413, 431, 501, 504, and 529 status codes across providers" do
      [
        {408, Anthropic::RequestTimeoutError},
        {412, Anthropic::PreconditionFailedError},
        {413, Anthropic::ContentTooLargeError},
        {431, Anthropic::RequestHeaderFieldsTooLargeError},
        {501, Anthropic::HTTPNotImplementedError},
        {504, Anthropic::GatewayTimeoutError},
        {529, Anthropic::OverloadedError},
      ].each do |status_code, expected_class|
        WebMock.reset
        WebMock.stub(:post, "https://bedrock-mantle.us-east-1.api.aws/anthropic/v1/messages")
          .to_return(status: status_code, body: %({"error":{"type":"api_error","message":"err"}}))
        mantle = Anthropic::Bedrock::MantleClient.new(api_key: "mt-k", aws_region: "us-east-1", max_retries: 0)
        ex = expect_raises(Anthropic::APIError) do
          mantle.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
        end
        ex.class.should eq(expected_class)
      end
    end
  end

  describe Anthropic::AWS::Client do
    it "skips ANTHROPIC_AWS_API_KEY env lookup when api_key: nil is explicit" do
      with_temp_env({"ANTHROPIC_AWS_API_KEY" => "env-aws-key", "ANTHROPIC_API_KEY" => "leaked-key"}) do
        capture = RequestCapture.new
        WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/messages").to_return do |req|
          capture.headers = req.headers
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end

        client = Anthropic::AWS::Client.new(
          api_key: nil,
          aws_access_key: "AKIA1",
          aws_secret_key: "secret1",
          aws_region: "us-east-1",
          workspace_id: "ws_1",
        )
        client.api_key_mode?.should be_false
        client.api_key.should be_nil
        client.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
        capture.headers.not_nil!["Authorization"].should start_with("AWS4-HMAC-SHA256")
      end
    end

    it "rejects conflicting explicit auth arguments cleanly" do
      expect_raises(ArgumentError, /Cannot provide both api_key and auth_token/) do
        Anthropic::AWS::Client.new(api_key: "k", auth_token: "t", aws_region: "us-east-1")
      end

      expect_raises(ArgumentError, /auth_token/) do
        Anthropic::AWS::Client.new(auth_token: "t", aws_region: "us-east-1")
      end

      aws_api_client = Anthropic::AWS::Client.new(api_key: "k", aws_region: "us-east-1", workspace_id: "ws_1")
      expect_raises(ArgumentError, /Cannot provide both api_key and auth_token/) do
        aws_api_client.with_options(auth_token: "t")
      end
      aws_api_client.with_options(auth_token: nil).api_key.should eq("k")

      aws_sigv4_client = Anthropic::AWS::Client.new(aws_access_key: "ak", aws_secret_key: "sk", aws_region: "us-east-1")
      expect_raises(ArgumentError, /auth_token/) do
        aws_sigv4_client.with_options(auth_token: "t")
      end

      with_temp_env({"ANTHROPIC_AWS_API_KEY" => "env-aws-key"}) do
        via_env = Anthropic::AWS::Client.new(auth_token: nil, aws_region: "us-east-1", workspace_id: "ws_1")
        via_env.api_key_mode?.should be_true
        via_env.api_key.should eq("env-aws-key")
      end

      expect_raises(ArgumentError, /provided together/) do
        Anthropic::AWS::Client.new(aws_access_key: "ak", aws_region: "us-east-1")
      end

      expect_raises(ArgumentError, /aws_session_token/) do
        Anthropic::AWS::Client.new(aws_session_token: "sess", aws_region: "us-east-1")
      end

      expect_raises(ArgumentError, /Cannot specify both/) do
        Anthropic::AWS::Client.new(
          aws_profile: "prof",
          aws_access_key: "ak",
          aws_secret_key: "sk",
          aws_region: "us-east-1",
        )
      end
    end

    it "rejects POST /v1/user_profiles/{id}/action_urls client-side without making HTTP calls" do
      client = Anthropic::AWS::Client.new(api_key: "aws-k", aws_region: "us-east-1", workspace_id: "ws_1")

      expect_raises(ArgumentError, /User profile action URLs are not supported in the AWS client\./) do
        client.post("/v1/user_profiles/prof_123/action_urls", {} of String => String)
      end

      expect_raises(ArgumentError, /User profile action URLs are not supported in the AWS client\./) do
        client.post("/v1/user_profiles/prof_123/action_urls?beta=true", {} of String => String)
      end
    end

    it "preserves client-level anthropic-workspace-id when omitted and supports per-request overrides" do
      captured_headers = [] of HTTP::Headers
      WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/messages").to_return do |req|
        captured_headers << req.headers
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
      end

      client = Anthropic::AWS::Client.new(api_key: "aws-k", aws_region: "us-east-1", workspace_id: "ws_default")
      client.post("/v1/messages", {"model" => "claude-sonnet-5"})
      client.post("/v1/messages", {"model" => "claude-sonnet-5"}, extra_headers: {"anthropic-workspace-id" => "ws_override"})

      captured_headers[0]["anthropic-workspace-id"].should eq("ws_default")
      captured_headers[1]["anthropic-workspace-id"].should eq("ws_override")
    end

    it "with_options preserves config, updates region URL, replaces AWS creds atomically, and clears api_key/workspace_id without reading env" do
      with_temp_env({"ANTHROPIC_AWS_API_KEY" => "env-aws-key", "ANTHROPIC_AWS_WORKSPACE_ID" => "env-ws"}) do
        parent = Anthropic::AWS::Client.new(
          aws_access_key: "AKIAOLD",
          aws_secret_key: "secretold",
          aws_session_token: "old-session-token",
          aws_region: "us-east-1",
          workspace_id: "ws_parent",
        )

        # New access/secret key must drop old session token and re-derive URL on region change.
        capture_sigv4 = RequestCapture.new
        WebMock.stub(:post, "https://aws-external-anthropic.eu-west-1.api.aws/v1/messages").to_return do |req|
          capture_sigv4.headers = req.headers
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end

        rotated = parent.with_options(
          aws_access_key: "AKIANEW",
          aws_secret_key: "secretnew",
          aws_region: "eu-west-1",
          max_retries: 0,
        )
        rotated.aws_region.should eq("eu-west-1")
        rotated.workspace_id.should eq("ws_parent")
        rotated.aws_session_token.should be_nil
        rotated.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])

        hdrs = capture_sigv4.headers.not_nil!
        hdrs["Authorization"].should contain("AKIANEW")
        hdrs["Authorization"].should contain("/eu-west-1/aws-external-anthropic/")
        hdrs["x-amz-security-token"]?.should be_nil
        hdrs["anthropic-workspace-id"].should eq("ws_parent")

        # Switching to explicit api_key, then clearing with api_key: nil and workspace_id: nil must not read ENV.
        bearer_client = Anthropic::AWS::Client.new(api_key: "explicit-k", aws_region: "us-east-1", workspace_id: "ws_1")
        cleared = bearer_client.with_options(
          api_key: nil,
          workspace_id: nil,
          aws_access_key: "AKIA2",
          aws_secret_key: "secret2",
        )
        cleared.api_key_mode?.should be_false
        cleared.api_key.should be_nil
        cleared.workspace_id.should be_nil

        capture_cleared = RequestCapture.new
        WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/messages").to_return do |req|
          capture_cleared.headers = req.headers
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
        cleared.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
        capture_cleared.headers.not_nil!["Authorization"].should contain("AKIA2")
        capture_cleared.headers.not_nil!["anthropic-workspace-id"]?.should be_nil

        # Explicit base_url is preserved across aws_region override.
        WebMock.stub(:post, "https://custom.aws.example/v1/messages")
          .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
        pinned = Anthropic::AWS::Client.new(
          api_key: "k",
          aws_region: "us-east-1",
          base_url: "https://custom.aws.example",
        )
        pinned.with_options(aws_region: "ap-northeast-1")
          .messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
          .should be_a(Anthropic::Message)
      end
    end
  end

  describe Anthropic::Bedrock::Client do
    it "moves anthropic-version header into body and removes outbound header on request and stream" do
      captures = [] of HTTP::Request
      ping = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"message_stop"}))

      WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |req|
        captures << req
        if req.uri.path.ends_with?("/invoke-with-response-stream")
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "application/vnd.amazon.eventstream"},
            body_io: IO::Memory.new(ping),
          )
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
      end

      client = Anthropic::Bedrock::Client.new(
        api_key: "br-token",
        aws_region: "us-east-1",
        default_headers: {"anthropic-beta" => "interleaved-thinking-2025-05-14"},
      )

      client.post(
        "/v1/messages",
        {"model" => "us.anthropic.claude-sonnet-5", "max_tokens" => 16, "messages" => [{"role" => "user", "content" => "hi"}]},
        extra_headers: {"anthropic-version" => "2026-11-01"},
      )
      client.post(
        "/v1/messages",
        {
          "model"             => "us.anthropic.claude-sonnet-5",
          "anthropic_version" => "custom-body-ver",
          "max_tokens"        => 16,
          "messages"          => [{"role" => "user", "content" => "hi"}],
        },
      )
      client.messages.stream(
        model: "us.anthropic.claude-sonnet-5",
        max_tokens: 16,
        messages: [{role: "user", content: "hi"}],
      ) { |_| }

      captures[0].headers["anthropic-version"]?.should be_nil
      body0 = JSON.parse(captures[0].body.not_nil!)
      body0["anthropic_version"].as_s.should eq("2026-11-01")
      body0["anthropic_beta"].as_a.map(&.as_s).should eq(["interleaved-thinking-2025-05-14"])

      captures[1].headers["anthropic-version"]?.should be_nil
      JSON.parse(captures[1].body.not_nil!)["anthropic_version"].as_s.should eq("custom-body-ver")

      captures[2].headers["anthropic-version"]?.should be_nil
      JSON.parse(captures[2].body.not_nil!)["anthropic_version"].as_s.should eq("2026-10-21")
    end

    it "validates model path segments and keeps ':' and ';' unencoded" do
      capture = RequestCapture.new
      WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//).to_return do |req|
        capture.path = req.uri.path
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
      end

      client = Anthropic::Bedrock::Client.new(api_key: "br-token", aws_region: "us-east-1")

      client.messages.create(
        model: "arn:aws:bedrock:us-east-1:123/profile;tier=priority",
        max_tokens: 8,
        messages: [{role: "user", content: "hi"}],
      )
      capture.path.should eq("/model/arn:aws:bedrock:us-east-1:123%2Fprofile;tier%3Dpriority/invoke")

      ["", ";matrix", ".", "..", ".;v=1", "..;v=1", "%2e", "%2e%3bv=1"].each do |bad_model|
        expect_raises(ArgumentError) do
          client.messages.create(model: bad_model, max_tokens: 8, messages: [{role: "user", content: "hi"}])
        end
      end
    end

    it "uses AWS_REGION/AWS_DEFAULT_REGION in API-key mode and disables AWS_BEARER_TOKEN_BEDROCK when api_key: nil" do
      with_temp_env({
        "AWS_BEARER_TOKEN_BEDROCK" => "env-bedrock-bearer",
        "AWS_REGION"               => nil,
        "AWS_DEFAULT_REGION"       => "ap-south-1",
      }) do
        WebMock.stub(:post, /bedrock-runtime\.ap-south-1\.amazonaws\.com\/model\//)
          .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
        api_key_client = Anthropic::Bedrock::Client.new
        api_key_client.use_sig_v4?.should be_false
        api_key_client.aws_region.should eq("ap-south-1")
        api_key_client.messages.create(model: "us.anthropic.claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
          .should be_a(Anthropic::Message)

        ENV["AWS_REGION"] = "eu-central-1"
        env_region_client = Anthropic::Bedrock::Client.new(api_key: "explicit-br")
        env_region_client.aws_region.should eq("eu-central-1")

        sigv4_client = Anthropic::Bedrock::Client.new(
          api_key: nil,
          aws_access_key: "AKIABED",
          aws_secret_key: "secbed",
          aws_region: "us-west-2",
        )
        sigv4_client.use_sig_v4?.should be_true
        sigv4_client.api_key.should be_nil
      end
    end

    it "raises NotImplementedError for user_profiles and supports with_options atomicity" do
      with_temp_env({"AWS_BEARER_TOKEN_BEDROCK" => "env-br"}) do
        client = Anthropic::Bedrock::Client.new(
          aws_access_key: "AKIA1",
          aws_secret_key: "sec1",
          aws_session_token: "old-tok",
          aws_region: "us-east-1",
        )

        expect_raises(NotImplementedError) { client.user_profiles }
        expect_raises(NotImplementedError) { client.beta.user_profiles }
        expect_raises(NotImplementedError) { client.get("/v1/user_profiles") }

        capture = RequestCapture.new
        WebMock.stub(:post, /bedrock-runtime\.eu-west-1\.amazonaws\.com\/model\//).to_return do |req|
          capture.headers = req.headers
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end

        rotated = client.with_options(
          aws_access_key: "AKIA2",
          aws_secret_key: "sec2",
          aws_region: "eu-west-1",
          max_retries: 1,
        )
        rotated.aws_region.should eq("eu-west-1")
        rotated.aws_session_token.should be_nil
        rotated.messages.create(model: "us.anthropic.claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
        capture.headers.not_nil!["x-amz-security-token"]?.should be_nil
        capture.headers.not_nil!["Authorization"].should contain("AKIA2")

        # Switching to Bearer and back to SigV4 with api_key: nil must not re-read AWS_BEARER_TOKEN_BEDROCK.
        bearer_copy = rotated.with_options(api_key: "br-explicit")
        bearer_copy.use_sig_v4?.should be_false
        bearer_copy.api_key.should eq("br-explicit")

        cleared_copy = bearer_copy.with_options(
          api_key: nil,
          aws_access_key: "AKIA3",
          aws_secret_key: "sec3",
        )
        cleared_copy.use_sig_v4?.should be_true
        cleared_copy.api_key.should be_nil
      end
    end
  end

  describe Anthropic::Bedrock::MantleClient do
    it "sends 2026-10-21 version, moves anthropic-user-profile-id into JSON body on message routes, and keeps it as header elsewhere" do
      captures = [] of HTTP::Request
      WebMock.stub(:post, /bedrock-mantle\.us-east-1\.api\.aws\/anthropic\/v1\/.*/).to_return do |req|
        captures << req
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
      end
      WebMock.stub(:get, /bedrock-mantle\.us-east-1\.api\.aws\/anthropic\/v1\/.*/).to_return do |req|
        captures << req
        HTTP::Client::Response.new(200, body: "{}")
      end

      client = Anthropic::Bedrock::MantleClient.new(
        aws_access_key: "AKIAMT",
        aws_secret_key: "secretmt",
        aws_region: "us-east-1",
        user_profile_id: "prof_client",
      )

      client.post("/v1/messages", {"model" => "claude-haiku-4-5-20251001", "max_tokens" => 8, "messages" => [{"role" => "user", "content" => "hi"}]})
      client.post("/v1/messages/count_tokens?beta=true", {"model" => "claude-haiku-4-5-20251001", "messages" => [{"role" => "user", "content" => "hi"}]})
      client.post(
        "/v1/messages",
        {"model" => "claude-haiku-4-5-20251001", "user_profile_id" => "prof_body"},
        extra_headers: {"anthropic-user-profile-id" => "prof_header"},
      )
      client.get("/v1/custom_route", extra_headers: {"anthropic-user-profile-id" => "prof_other"})

      captures[0].headers["anthropic-version"].should eq("2026-10-21")
      captures[0].headers["anthropic-user-profile-id"]?.should be_nil
      JSON.parse(captures[0].body.not_nil!)["user_profile_id"].as_s.should eq("prof_client")

      captures[1].headers["anthropic-user-profile-id"]?.should be_nil
      JSON.parse(captures[1].body.not_nil!)["user_profile_id"].as_s.should eq("prof_client")

      captures[2].headers["anthropic-user-profile-id"]?.should be_nil
      JSON.parse(captures[2].body.not_nil!)["user_profile_id"].as_s.should eq("prof_body")

      captures[3].headers["anthropic-user-profile-id"].should eq("prof_other")
    end

    it "uses brackets for array query params and supports with_options without re-reading env on api_key: nil" do
      with_temp_env({"AWS_BEARER_TOKEN_BEDROCK" => "env-mt-bearer", "ANTHROPIC_AWS_API_KEY" => "env-aws-key"}) do
        capture = RequestCapture.new
        WebMock.stub(:get, /bedrock-mantle\.us-west-2\.api\.aws\/anthropic\/v1\/custom/).to_return do |req|
          capture.path = req.resource
          capture.headers = req.headers
          HTTP::Client::Response.new(200, body: "{}")
        end

        client = Anthropic::Bedrock::MantleClient.new(
          api_key: "explicit-mt",
          aws_region: "us-east-1",
        )
        rotated = client.with_options(
          api_key: nil,
          aws_access_key: "AKIAMT2",
          aws_secret_key: "secretmt2",
          aws_region: "us-west-2",
        )
        rotated.use_sig_v4?.should be_true
        rotated.api_key.should be_nil
        rotated.aws_region.should eq("us-west-2")

        rotated.get("/v1/custom", params: {"tags" => ["a", "b"]})
        capture.path.should eq("/anthropic/v1/custom?tags%5B%5D=a&tags%5B%5D=b")
        capture.headers.not_nil!["Authorization"].should contain("/us-west-2/bedrock-mantle/")
      end
    end
  end

  describe Anthropic::GoogleCloud::Client do
    it "routes organizations and user_profiles to claudeOrganization without requiring workspace_id" do
      with_temp_env({"ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID" => "env-ws-ignored"}) do
        captures = [] of HTTP::Request
        WebMock.stub(:get, /claude\.googleapis\.com\/v1\/projects\/my%2Fproj\/locations\/global\/claudeOrganization\/invoke\/.*/).to_return do |req|
          captures << req
          HTTP::Client::Response.new(200, body: "{}")
        end
        WebMock.stub(:post, /claude\.googleapis\.com\/v1\/projects\/my%2Fproj\/locations\/global\/claudeOrganization\/invoke\/.*/).to_return do |req|
          captures << req
          HTTP::Client::Response.new(200, body: "{}")
        end

        client = Anthropic::GoogleCloud::Client.new(
          project: "my/proj",
          workspace_id: nil,
          skip_auth: true,
        )
        client.workspace_id.should be_nil

        client.get("/v1/organizations/me")
        client.get("/v1/user_profiles")
        client.post("/v1/user_profiles/prof_1/action_urls?beta=true", {} of String => String)

        captures[0].uri.path.should eq("/v1/projects/my%2Fproj/locations/global/claudeOrganization/invoke/v1/organizations/me")
        captures[1].uri.path.should eq("/v1/projects/my%2Fproj/locations/global/claudeOrganization/invoke/v1/user_profiles")
        captures[2].uri.path.should eq("/v1/projects/my%2Fproj/locations/global/claudeOrganization/invoke/v1/user_profiles/prof_1/action_urls")
        captures[2].uri.query.should eq("beta=true")

        expect_raises(ArgumentError, /workspace/) do
          client.models.list
        end
      end
    end

    it "validates segments and supports with_options re-derivation and atomic Google auth replacement" do
      expect_raises(ArgumentError) do
        Anthropic::GoogleCloud::Client.new(project: "..", skip_auth: true)
      end
      expect_raises(ArgumentError) do
        Anthropic::GoogleCloud::Client.new(project: "proj", workspace_id: ";matrix", skip_auth: true)
      end

      capture = RequestCapture.new
      WebMock.stub(:post, "https://claude.googleapis.com/v1/projects/proj-2/locations/us-east5/workspaces/ws%202/invoke/v1/messages").to_return do |req|
        capture.headers = req.headers
        capture.path = req.uri.path
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
      end

      client = Anthropic::GoogleCloud::Client.new(
        project: "proj-1",
        location: "global",
        workspace_id: "ws-1",
        access_token: "old-static-token",
      )
      updated = client.with_options(
        project: "proj-2",
        location: "us-east5",
        workspace_id: "ws 2",
        token_provider: -> { "fresh-provider-token" },
      )

      updated.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      capture.path.should eq("/v1/projects/proj-2/locations/us-east5/workspaces/ws%202/invoke/v1/messages")
      capture.headers.not_nil!["Authorization"].should eq("Bearer fresh-provider-token")

      # Clearing workspace_id disables workspace routes without reading ENV.
      with_temp_env({"ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID" => "env-ws"}) do
        no_ws = updated.with_options(workspace_id: nil)
        no_ws.workspace_id.should be_nil
      end
    end
  end

  describe Anthropic::Vertex::Client do
    it "moves anthropic-version header into JSON body, removes outbound header, encodes ';' as '%3B', and preserves '@'" do
      captures = [] of HTTP::Request
      WebMock.stub(:post, /us-central1-aiplatform\.googleapis\.com\/v1\/projects\//).to_return do |req|
        captures << req
        if req.uri.path.ends_with?(":streamRawPredict")
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new("data: [DONE]\n\n"),
          )
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
        end
      end

      client = Anthropic::Vertex::Client.new(
        region: "us-central1",
        project_id: "proj/1",
        access_token: "vtx-tok",
        default_headers: {"anthropic-version" => "2026-10-21"},
      )

      client.post(
        "/v1/messages",
        {"model" => "claude-3-5-sonnet@20240620;tier=1", "max_tokens" => 8, "messages" => [{"role" => "user", "content" => "hi"}]},
        extra_headers: {"anthropic-version" => "2026-12-01"},
      )
      client.messages.stream(
        model: "claude-sonnet-4-6;beta=1",
        max_tokens: 8,
        messages: [{role: "user", content: "hi"}],
      ) { |_| }

      captures[0].uri.path.should eq("/v1/projects/proj%2F1/locations/us-central1/publishers/anthropic/models/claude-3-5-sonnet@20240620%3Btier=1:rawPredict")
      captures[0].headers["anthropic-version"]?.should be_nil
      JSON.parse(captures[0].body.not_nil!)["anthropic_version"].as_s.should eq("2026-12-01")

      captures[1].uri.path.should eq("/v1/projects/proj%2F1/locations/us-central1/publishers/anthropic/models/claude-sonnet-4-6%3Bbeta=1:streamRawPredict")
      captures[1].headers["anthropic-version"]?.should be_nil
      JSON.parse(captures[1].body.not_nil!)["anthropic_version"].as_s.should eq("2026-10-21")
    end

    it "validates region, project_id, and model, disables user_profiles, and supports with_options" do
      expect_raises(ArgumentError) { Anthropic::Vertex::Client.new(region: ".", project_id: "proj", access_token: "tok") }
      expect_raises(ArgumentError) { Anthropic::Vertex::Client.new(region: "global", project_id: ";bad", access_token: "tok") }

      client = Anthropic::Vertex::Client.new(region: "global", project_id: "proj-a", access_token: "old-tok")
      expect_raises(NotImplementedError) { client.user_profiles }
      expect_raises(NotImplementedError) { client.beta.user_profiles }
      expect_raises(NotImplementedError) { client.get("/v1/user_profiles") }

      ["", ".", "..", ";foo", "%2e"].each do |bad_model|
        expect_raises(ArgumentError) do
          client.messages.create(model: bad_model, max_tokens: 8, messages: [{role: "user", content: "hi"}])
        end
      end

      capture = RequestCapture.new
      WebMock.stub(:post, "https://aiplatform.eu.rep.googleapis.com/v1/projects/proj-b/locations/eu/publishers/anthropic/models/claude-sonnet-4-6:rawPredict").to_return do |req|
        capture.headers = req.headers
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC)
      end

      rotated = client.with_options(
        region: "eu",
        project_id: "proj-b",
        token_provider: -> { "new-vertex-token" },
      )
      rotated.region.should eq("eu")
      rotated.project_id.should eq("proj-b")
      rotated.messages.create(model: "claude-sonnet-4-6", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      capture.headers.not_nil!["Authorization"].should eq("Bearer new-vertex-token")
    end
  end

  describe "additional transport and credential-guard parity" do
    it "SigV4-signs get_stream, get_raw, and post_multipart on AWS::Client" do
      captured = [] of {String, HTTP::Headers}

      WebMock.stub(:get, "https://aws-external-anthropic.us-east-1.api.aws/v1/stream").to_return do |req|
        captured << {"get_stream", req.headers}
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          body_io: IO::Memory.new("data: [DONE]\n\n"),
        )
      end
      WebMock.stub(:get, "https://aws-external-anthropic.us-east-1.api.aws/v1/files/f1/content").to_return do |req|
        captured << {"get_raw", req.headers}
        HTTP::Client::Response.new(200, body: "raw-bytes")
      end
      WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/files").to_return do |req|
        captured << {"post_multipart", req.headers}
        HTTP::Client::Response.new(200, body: %({"id":"file_1"}))
      end

      client = Anthropic::AWS::Client.new(
        aws_access_key: "AKIA_TEST",
        aws_secret_key: "secret_test",
        aws_region: "us-east-1",
        workspace_id: "ws_1",
      )

      client.get_stream("/v1/stream") { |_| }
      client.get_raw("/v1/files/f1/content").gets_to_end.should eq("raw-bytes")
      client.post_multipart("/v1/files", IO::Memory.new("abc"), filename: "a.txt").status_code.should eq(200)

      captured.size.should eq(3)
      captured.each do |_, hdrs|
        hdrs["Authorization"].should start_with("AWS4-HMAC-SHA256")
        hdrs["Authorization"].should contain("/us-east-1/aws-external-anthropic/aws4_request")
      end
    end

    it "moves anthropic-user-profile-id into JSON body during MantleClient post_stream and SigV4-signs the rewritten body" do
      capture = RequestCapture.new
      WebMock.stub(:post, "https://bedrock-mantle.us-east-1.api.aws/anthropic/v1/messages").to_return do |req|
        capture.headers = req.headers
        capture.body = req.body.to_s
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          body_io: IO::Memory.new("data: [DONE]\n\n"),
        )
      end

      client = Anthropic::Bedrock::MantleClient.new(
        aws_access_key: "AKIAMT_STRM",
        aws_secret_key: "secret_strm",
        aws_region: "us-east-1",
        user_profile_id: "prof_stream",
      )

      client.post_stream("/v1/messages", {"model" => "claude-haiku-4-5-20251001", "stream" => true}) { |_| }

      hdrs = capture.headers.not_nil!
      hdrs["anthropic-user-profile-id"]?.should be_nil
      hdrs["Authorization"].should start_with("AWS4-HMAC-SHA256")
      JSON.parse(capture.body.not_nil!)["user_profile_id"].as_s.should eq("prof_stream")
    end

    it "rejects unsupported credential options on Bedrock, Mantle, Vertex, and GoogleCloud" do
      expect_raises(ArgumentError, /auth_token/) do
        Anthropic::Bedrock::Client.new(api_key: "br", auth_token: "bad", aws_region: "us-east-1")
      end
      expect_raises(ArgumentError, /auth_token/) do
        Anthropic::Bedrock::MantleClient.new(api_key: "mt", auth_token: "bad", aws_region: "us-east-1")
      end
      expect_raises(ArgumentError, /api_key/) do
        Anthropic::GoogleCloud::Client.new(project: "proj", api_key: "bad", skip_auth: true)
      end
      expect_raises(ArgumentError, /auth_token/) do
        Anthropic::GoogleCloud::Client.new(project: "proj", auth_token: "bad", skip_auth: true)
      end
      expect_raises(ArgumentError, /api_key/) do
        Anthropic::Vertex::Client.new(region: "global", project_id: "proj", api_key: "bad", access_token: "tok")
      end
      expect_raises(ArgumentError, /auth_token/) do
        Anthropic::Vertex::Client.new(region: "global", project_id: "proj", auth_token: "bad", access_token: "tok")
      end
    end

    it "preserves explicit base_url across region overrides in with_options" do
      WebMock.stub(:post, /custom\.bedrock\.example\/model\//)
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
      WebMock.stub(:post, "https://custom.mantle.example/proxy/v1/messages")
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
      WebMock.stub(:post, "https://custom.vertex.example/v1/projects/proj/locations/eu/publishers/anthropic/models/claude-sonnet-4-6:rawPredict")
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
      WebMock.stub(:post, "https://custom.gc.example/v1/messages")
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)

      br = Anthropic::Bedrock::Client.new(api_key: "br", aws_region: "us-east-1", base_url: "https://custom.bedrock.example")
      br.with_options(aws_region: "eu-west-1").messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])

      mt = Anthropic::Bedrock::MantleClient.new(api_key: "mt", aws_region: "us-east-1", base_url: "https://custom.mantle.example/proxy")
      mt.with_options(aws_region: "eu-west-1").messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])

      vtx = Anthropic::Vertex::Client.new(region: "global", project_id: "proj", access_token: "tok", base_url: "https://custom.vertex.example")
      vtx.with_options(region: "eu").messages.create(model: "claude-sonnet-4-6", max_tokens: 8, messages: [{role: "user", content: "hi"}])

      gc = Anthropic::GoogleCloud::Client.new(project: "proj-1", workspace_id: "ws-1", skip_auth: true, base_url: "https://custom.gc.example")
      gc.with_options(project: "proj-2", workspace_id: "ws-2").messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
    end

    it "propagates per-request beta and timeout context on AWS, Bedrock, and Mantle" do
      aws_mw = ProviderBetaCaptureMiddleware.new
      bedrock_mw = ProviderBetaCaptureMiddleware.new
      mantle_mw = ProviderBetaCaptureMiddleware.new

      WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/messages")
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
      WebMock.stub(:post, /bedrock-runtime\.us-east-1\.amazonaws\.com\/model\//)
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)
      WebMock.stub(:post, "https://bedrock-mantle.us-east-1.api.aws/anthropic/v1/messages")
        .to_return(status: 200, body: Fixtures::Responses::MESSAGE_BASIC)

      aws = Anthropic::AWS::Client.new(api_key: "aws-k", aws_region: "us-east-1", workspace_id: "ws_1", middleware: [aws_mw], max_retries: 0)
      bedrock = Anthropic::Bedrock::Client.new(api_key: "br-k", aws_region: "us-east-1", middleware: [bedrock_mw], max_retries: 0)
      mantle = Anthropic::Bedrock::MantleClient.new(api_key: "mt-k", aws_region: "us-east-1", middleware: [mantle_mw], max_retries: 0)

      aws.beta.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      bedrock.beta.messages.create(model: "us.anthropic.claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])
      mantle.beta.messages.create(model: "claude-sonnet-5", max_tokens: 8, messages: [{role: "user", content: "hi"}])

      aws_mw.seen_beta.should eq([true])
      bedrock_mw.seen_beta.should eq([true])
      mantle_mw.seen_beta.should eq([true])

      # Verify socket read timeout from request context is enforced on AWS, Bedrock, and Mantle.
      WebMock.allow_net_connect = true
      server = TCPServer.new("127.0.0.1", 0)
      begin
        port = server.local_address.port
        3.times do
          spawn do
            begin
              client_sock = server.accept
              client_sock.gets
              sleep(0.15.seconds)
              client_sock.close
            rescue
            end
          end
        end

        slow_aws = Anthropic::AWS::Client.new(
          api_key: "aws-k",
          aws_region: "us-east-1",
          base_url: "http://127.0.0.1:#{port}",
          max_retries: 0,
        )
        slow_bedrock = Anthropic::Bedrock::Client.new(
          api_key: "br-k",
          aws_region: "us-east-1",
          base_url: "http://127.0.0.1:#{port}",
          max_retries: 0,
        )
        slow_mantle = Anthropic::Bedrock::MantleClient.new(
          api_key: "mt-k",
          aws_region: "us-east-1",
          base_url: "http://127.0.0.1:#{port}",
          max_retries: 0,
        )

        [slow_aws, slow_bedrock, slow_mantle].each do |slow_client|
          expect_raises(Anthropic::APITimeoutError) do
            slow_client.post("/v1/messages", {"model" => "claude-sonnet-5"}, timeout: 0.03.seconds)
          end
        end
      ensure
        server.close
        WebMock.allow_net_connect = false
      end
    end

    it "emits empty filename for unnamed FileUpload parts under AWS SigV4 post_multipart_files" do
      captured_body = ""
      WebMock.stub(:post, "https://aws-external-anthropic.us-east-1.api.aws/v1/skills").to_return do |req|
        captured_body = req.body.to_s
        HTTP::Client::Response.new(200, body: %({"id":"skill_1"}))
      end

      client = Anthropic::AWS::Client.new(
        aws_access_key: "AKIA_TEST",
        aws_secret_key: "secret_test",
        aws_region: "us-east-1",
        workspace_id: "ws_1",
      )

      upload = Anthropic::FileUpload.new(io: IO::Memory.new("skill-bytes"), filename: nil)
      client.post_multipart_files("/v1/skills", [upload]).status_code.should eq(200)
      captured_body.should contain("filename=\"\"")
      captured_body.should contain("skill-bytes")
    end
  end
end
