require "../../spec_helper"
require "openssl"
require "openssl/digest"

describe Anthropic::Bedrock::SigV4 do
  # AWS documentation example-style known values (region/service generic).
  # We assert structure and determinism rather than a frozen AWS sample,
  # because timestamps are dynamic.

  it "produces Authorization, x-amz-date, and content hash headers" do
    creds = Anthropic::Bedrock::Credentials.new(
      "AKIAIOSFODNN7EXAMPLE",
      "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      "us-east-1",
    )
    headers = HTTP::Headers{"content-type" => "application/json"}
    body = %({"hello":"world"})

    signed = Anthropic::Bedrock::SigV4.sign(
      creds,
      "POST",
      "https://bedrock-runtime.us-east-1.amazonaws.com/model/foo/invoke",
      headers,
      body,
    )

    signed["authorization"].should start_with("AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/")
    signed["authorization"].should contain("/us-east-1/bedrock/aws4_request")
    signed["authorization"].should contain("SignedHeaders=")
    signed["authorization"].should contain("Signature=")
    signed["x-amz-date"].should match(/\A\d{8}T\d{6}Z\z/)
    signed["x-amz-content-sha256"].should eq(OpenSSL::Digest.new("SHA256").tap(&.update(body)).final.hexstring)
    signed["host"].should eq("bedrock-runtime.us-east-1.amazonaws.com")
    signed.has_key?("x-amz-security-token").should be_false
  end

  it "includes x-amz-security-token when a session token is present" do
    creds = Anthropic::Bedrock::Credentials.new(
      "AKIAIOSFODNN7EXAMPLE",
      "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      "us-west-2",
      "session-token-value",
    )
    signed = Anthropic::Bedrock::SigV4.sign(
      creds,
      "POST",
      "https://bedrock-runtime.us-west-2.amazonaws.com/model/foo/invoke",
      HTTP::Headers{"content-type" => "application/json"},
      "{}",
    )
    signed["x-amz-security-token"].should eq("session-token-value")
    signed["authorization"].should contain("x-amz-security-token")
  end

  it "excludes unsignable headers (proxy-authorization, trace headers, connection) and ignores stale security tokens" do
    creds = Anthropic::Bedrock::Credentials.new(
      "AKIAIOSFODNN7EXAMPLE",
      "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      "us-east-1",
    )
    headers = HTTP::Headers{
      "content-type"         => "application/json",
      "proxy-authorization"  => "Basic secret",
      "connection"           => "keep-alive",
      "traceparent"          => "00-11111111111111111111111111111111-2222222222222222-01",
      "tracestate"           => "congo=t61rcWkgMzE",
      "baggage"              => "userId=alice",
      "x-amz-security-token" => "stale-header-token",
    }

    signed = Anthropic::Bedrock::SigV4.sign(
      creds,
      "POST",
      "https://aws-external-anthropic.us-east-1.api.aws/v1/messages",
      headers,
      "{}",
      service: "aws-external-anthropic",
    )

    signed.has_key?("x-amz-security-token").should be_false
    auth = signed["authorization"]
    auth.should_not contain("proxy-authorization")
    auth.should_not contain("traceparent")
    auth.should_not contain("tracestate")
    auth.should_not contain("baggage")
    auth.should_not contain("connection")
    auth.should_not contain("x-amz-security-token")

    Anthropic::Bedrock::SigV4.signable_header?("Proxy-Authorization").should be_false
    Anthropic::Bedrock::SigV4.signable_header?("traceparent").should be_false
    Anthropic::Bedrock::SigV4.signable_header?("x-custom", ["x-custom"]).should be_false
  end

  it "redacts sensitive headers including proxy-authorization and x-amz-security-token" do
    redacted = Anthropic::Bedrock::SigV4.redact_headers(HTTP::Headers{
      "Authorization"        => "Bearer secret",
      "Proxy-Authorization"  => "Basic abc",
      "x-amz-security-token" => "sts-token",
      "x-api-key"            => "sk-ant-123",
      "content-type"         => "application/json",
    })

    redacted["Authorization"].should eq("***")
    redacted["Proxy-Authorization"].should eq("***")
    redacted["x-amz-security-token"].should eq("***")
    redacted["x-api-key"].should eq("***")
    redacted["content-type"].should eq("application/json")
  end
end
