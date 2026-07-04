require "../spec_helper"

describe Anthropic::StainlessHelper do
  it "exposes the header key and a closed vocabulary of tag values" do
    Anthropic::StainlessHelper::HEADER.should eq("x-stainless-helper")
    Anthropic::StainlessHelper::BETA_TOOL_RUNNER.should eq("BetaToolRunner")
    Anthropic::StainlessHelper::FALLBACK_REFUSAL_MIDDLEWARE.should eq("fallback-refusal-middleware")
    Anthropic::StainlessHelper::SESSION_TOOL_RUNNER.should eq("session-tool-runner")
    Anthropic::StainlessHelper::COMPACTION.should eq("compaction")
  end

  it "builds a single-entry header hash via .header" do
    Anthropic::StainlessHelper.header("BetaToolRunner").should eq({"x-stainless-helper" => "BetaToolRunner"})
  end

  it "sets the header when none is present" do
    result = Anthropic::StainlessHelper.merge_helper_header({"foo" => "bar"}, "BetaToolRunner")
    result["x-stainless-helper"].should eq("BetaToolRunner")
    result["foo"].should eq("bar")
  end

  it "appends to an existing helper header with comma-join semantics" do
    base = Anthropic::StainlessHelper.header("BetaToolRunner")
    result = Anthropic::StainlessHelper.merge_helper_header(base, "session-tool-runner")
    result["x-stainless-helper"].should eq("BetaToolRunner,session-tool-runner")
  end

  it "drops duplicate values when appending" do
    base = Anthropic::StainlessHelper.header("BetaToolRunner")
    result = Anthropic::StainlessHelper.merge_helper_header(base, "BetaToolRunner")
    result["x-stainless-helper"].should eq("BetaToolRunner")
  end

  it "works on a nil base hash" do
    result = Anthropic::StainlessHelper.merge_helper_header(nil, "compaction")
    result["x-stainless-helper"].should eq("compaction")
  end
end

describe "x-stainless-helper request tagging" do
  it "threads extra_headers through beta.messages.create with append semantics" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.beta.messages.create(
      model: Anthropic::Model::CLAUDE_SONNET_5,
      max_tokens: 64,
      messages: [{role: "user", content: "hi"}],
      extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::FALLBACK_REFUSAL_MIDDLEWARE)
    )

    capture.headers.not_nil!["x-stainless-helper"].should eq("fallback-refusal-middleware")
  end

  it "threads extra_headers through the non-beta messages surface" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.messages.create(
      model: Anthropic::Model::CLAUDE_SONNET_5,
      max_tokens: 64,
      messages: [{role: "user", content: "hi"}],
      extra_headers: Anthropic::StainlessHelper.header(Anthropic::StainlessHelper::SESSION_TOOL_RUNNER)
    )

    capture.headers.not_nil!["x-stainless-helper"].should eq("session-tool-runner")
  end
end
