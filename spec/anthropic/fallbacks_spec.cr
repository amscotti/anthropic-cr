require "../spec_helper"

# Specs covering the June/July 2026 server-side fallbacks parity additions:
# - FallbackParam / FallbackInfo / FallbackRefusalTrigger request + response types
# - `fallback` content block wiring into the ContentBlock union + converter
# - RefusalStopDetails fallback fields (fallback_credit_token, etc.)
# - Usage.iterations per-hop breakdown
# - Beta header auto-attachment (server-side-fallback-2026-06-01)
# - beta.messages / messages request wiring of `fallbacks` + `fallback_credit_token`
describe "Server-side fallbacks parity additions" do
  describe "FallbackParam serialization" do
    it "serializes a FallbackParam with required model only" do
      param = Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)
      parsed = JSON.parse(param.to_json)

      parsed["model"].as_s.should eq("claude-opus-4-8")
      parsed.as_h.has_key?("max_tokens").should be_false
    end

    it "serializes override fields when provided" do
      param = Anthropic::FallbackParam.new(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 2048,
        speed: "fast",
      )
      parsed = JSON.parse(param.to_json)

      parsed["model"].as_s.should eq("claude-sonnet-5")
      parsed["max_tokens"].as_i.should eq(2048)
      parsed["speed"].as_s.should eq("fast")
    end
  end

  describe "FallbackContent block parsing" do
    it "parses a fallback content block via the ContentBlock converter" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_FALLBACK)
      fallback = message.content.find! { |block| block.is_a?(Anthropic::FallbackContent) }.as(Anthropic::FallbackContent)

      fallback.type.should eq("fallback")
      fallback.from.model.should eq("claude-fable-5")
      fallback.to.model.should eq("claude-opus-4-8")
      fallback.trigger.type.should eq("refusal")
      fallback.trigger.category.should eq("frontier_llm")
    end

    it "parses a FallbackContent directly from JSON" do
      json = %({"type":"fallback","from":{"model":"claude-fable-5"},"to":{"model":"claude-sonnet-5"},"trigger":{"type":"refusal","category":"bio"}})
      block = Anthropic::FallbackContent.from_json(json)

      block.from.model.should eq("claude-fable-5")
      block.to.model.should eq("claude-sonnet-5")
      block.trigger.category.should eq("bio")
    end

    it "round-trips through to_json" do
      block = Anthropic::FallbackContent.new(
        from: Anthropic::FallbackInfo.new("claude-fable-5"),
        to: Anthropic::FallbackInfo.new("claude-opus-4-8"),
        trigger: Anthropic::FallbackRefusalTrigger.new(category: "frontier_llm"),
      )
      parsed = JSON.parse(block.to_json)

      parsed["type"].as_s.should eq("fallback")
      parsed["from"]["model"].as_s.should eq("claude-fable-5")
      parsed["to"]["model"].as_s.should eq("claude-opus-4-8")
      parsed["trigger"]["category"].as_s.should eq("frontier_llm")
    end
  end

  describe "RefusalStopDetails fallback fields" do
    it "parses fallback_credit_token / fallback_has_prefill_claim / recommended_model" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_FALLBACK)
      details = message.refusal_stop_details.not_nil!

      details.category.should eq("frontier_llm")
      details.fallback_credit_token.should eq("fct_01ABC")
      details.fallback_has_prefill_claim.should be_true
      details.recommended_model.should be_nil
    end

    it "round-trips the new fields through to_json" do
      details = Anthropic::RefusalStopDetails.new(
        category: "cyber",
        fallback_credit_token: "fct_xyz",
        fallback_has_prefill_claim: false,
        recommended_model: "claude-opus-4-8",
      )
      parsed = Anthropic::RefusalStopDetails.from_json(details.to_json)

      parsed.fallback_credit_token.should eq("fct_xyz")
      parsed.fallback_has_prefill_claim.should be_false
      parsed.recommended_model.should eq("claude-opus-4-8")
    end
  end

  describe "Usage.iterations per-hop breakdown" do
    it "parses iterations on a fallback response" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_FALLBACK)
      iterations = message.usage.iterations.not_nil!

      iterations.size.should eq(2)
      declined = iterations.first
      declined.declined?.should be_true
      declined.model.should eq("claude-fable-5")

      serving = iterations[1]
      serving.fallback_message?.should be_true
      serving.model.should eq("claude-opus-4-8")
      serving.output_tokens.should eq(30)
    end
  end

  describe "beta header auto-attachment" do
    it "attaches server-side-fallback beta when fallbacks are provided on beta.messages" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 256,
        fallbacks: [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::SERVER_SIDE_FALLBACK_BETA)
      body = JSON.parse(capture.body.not_nil!)
      body["fallbacks"].as_a.size.should eq(1)
      body["fallbacks"][0]["model"].as_s.should eq("claude-opus-4-8")
    end

    it "attaches server-side-fallback beta on the non-beta messages surface" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 256,
        fallbacks: [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_SONNET_5)],
        fallback_credit_token: "fct_existing",
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::SERVER_SIDE_FALLBACK_BETA)
      body = JSON.parse(capture.body.not_nil!)
      body["fallback_credit_token"].as_s.should eq("fct_existing")
    end

    it "attaches the server-side-fallback beta for a bare fallback_credit_token retry" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_8,
        max_tokens: 256,
        fallback_credit_token: "fct_retry",
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::SERVER_SIDE_FALLBACK_BETA)
      body = JSON.parse(capture.body.not_nil!)
      body["fallback_credit_token"].as_s.should eq("fct_retry")
    end

    it "does not attach the fallback beta when fallbacks are omitted" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_5,
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"]?.try(&.includes?(Anthropic::SERVER_SIDE_FALLBACK_BETA)).should_not be_true
    end
  end

  describe "beta header constants" do
    it "exposes the fallback beta constants" do
      Anthropic::SERVER_SIDE_FALLBACK_BETA.should eq("server-side-fallback-2026-06-01")
      Anthropic::FALLBACK_CREDIT_BETA.should eq("fallback-credit-2026-06-01")
      Anthropic::AGENT_MEMORY_BETA.should eq("agent-memory-2026-07-22")
    end
  end
end
