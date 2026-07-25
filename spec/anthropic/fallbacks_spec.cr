require "../spec_helper"

# Specs covering the June/July 2026 server-side fallbacks parity additions:
# - FallbackParam / FallbackInfo / FallbackRefusalTrigger request + response types
# - `fallbacks: "default"` string form
# - FallbackCreditTokenParam object form + bare-string union
# - `fallback` content block wiring into the ContentBlock union + converter
# - RefusalStopDetails fallback fields (fallback_credit_token, etc.)
# - Usage.iterations / usage.fallback_credit / usage.speed
# - Beta header auto-attachment (server-side-fallback-2026-07-01, fallback-credit-2026-07-01)
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

  describe "FallbacksParam (array or \"default\")" do
    it "serializes fallbacks: \"default\" on MessageCreateParams" do
      params = Anthropic::MessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
        fallbacks: "default",
      )
      parsed = JSON.parse(params.to_json)

      parsed["fallbacks"].as_s.should eq("default")
    end

    it "serializes an array of FallbackParam" do
      params = Anthropic::MessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
        fallbacks: [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)],
      )
      parsed = JSON.parse(params.to_json)

      parsed["fallbacks"].as_a.size.should eq(1)
      parsed["fallbacks"][0]["model"].as_s.should eq("claude-opus-4-8")
    end

    it "omits fallbacks when nil" do
      params = Anthropic::MessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
      )
      parsed = JSON.parse(params.to_json)

      parsed.as_h.has_key?("fallbacks").should be_false
    end

    it "rejects non-\"default\" strings on serialization" do
      params = Anthropic::MessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
        fallbacks: "defaults",
      )
      expect_raises(ArgumentError, /only "default" is allowed/) do
        params.to_json
      end
    end

    it "rejects non-\"default\" strings on parse" do
      # Exercise the converter directly — full MessageCreateParams.from_json
      # also pulls abstract ServerTool into the deserializable union.
      expect_raises(JSON::ParseException, /only "default" is allowed/) do
        Anthropic::FallbacksParamConverter.from_json(JSON::PullParser.new(%("defaults")))
      end
    end

    it "parses the exact \"default\" string" do
      value = Anthropic::FallbacksParamConverter.from_json(JSON::PullParser.new(%("default")))
      value.should eq("default")
    end
  end

  describe "Anthropic.fallbacks_present?" do
    it "is true for \"default\" and non-empty arrays" do
      Anthropic.fallbacks_present?("default").should be_true
      Anthropic.fallbacks_present?([Anthropic::FallbackParam.new(model: "claude-opus-4-8")]).should be_true
    end

    it "is false for nil, empty arrays, and non-\"default\" strings" do
      Anthropic.fallbacks_present?(nil).should be_false
      Anthropic.fallbacks_present?([] of Anthropic::FallbackParam).should be_false
      Anthropic.fallbacks_present?("").should be_false
      Anthropic.fallbacks_present?("defaults").should be_false
      Anthropic.fallbacks_present?("Default").should be_false
    end
  end

  describe "FallbackCreditTokenParam" do
    it "serializes object form with token and mode" do
      token = Anthropic::FallbackCreditTokenParam.new(token: "fct_01ABC", mode: "best_effort")
      parsed = JSON.parse(token.to_json)

      parsed["token"].as_s.should eq("fct_01ABC")
      parsed["mode"].as_s.should eq("best_effort")
    end

    it "omits mode when nil" do
      token = Anthropic::FallbackCreditTokenParam.new(token: "fct_xyz")
      parsed = JSON.parse(token.to_json)

      parsed["token"].as_s.should eq("fct_xyz")
      parsed.as_h.has_key?("mode").should be_false
    end

    it "serializes bare string credit token on params" do
      params = Anthropic::MessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_OPUS_4_8,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
        fallback_credit_token: "fct_bare",
      )
      parsed = JSON.parse(params.to_json)

      parsed["fallback_credit_token"].as_s.should eq("fct_bare")
    end

    it "serializes object-form credit token on params" do
      params = Anthropic::BetaMessageCreateParams.new(
        model: Anthropic::Model::CLAUDE_OPUS_4_8,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: "user", content: "hi")],
        fallback_credit_token: Anthropic::FallbackCreditTokenParam.new(
          token: "fct_obj",
          mode: "strict",
        ),
      )
      parsed = JSON.parse(params.to_json)

      parsed["fallback_credit_token"]["token"].as_s.should eq("fct_obj")
      parsed["fallback_credit_token"]["mode"].as_s.should eq("strict")
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

  describe "Usage.fallback_credit and speed" do
    it "parses redeemed fallback_credit status" do
      json = %({"input_tokens":10,"output_tokens":5,"fallback_credit":{"status":{"type":"redeemed"}},"speed":"fast"})
      usage = Anthropic::Usage.from_json(json)

      usage.speed.should eq("fast")
      credit = usage.fallback_credit.not_nil!
      credit.redeemed?.should be_true
      credit.status.as(Anthropic::FallbackCreditRedeemed).type.should eq("redeemed")
    end

    it "parses not_applied fallback_credit with reason and remove_to_redeem" do
      json = %({"input_tokens":10,"output_tokens":5,"fallback_credit":{"status":{"type":"not_applied","reason":"variant_fields_present","remove_to_redeem":["thinking","speed"]}}})
      usage = Anthropic::Usage.from_json(json)

      credit = usage.fallback_credit.not_nil!
      credit.not_applied?.should be_true
      status = credit.status.as(Anthropic::FallbackCreditNotApplied)
      status.reason.should eq("variant_fields_present")
      status.remove_to_redeem.should eq(["thinking", "speed"])
    end

    it "parses not_applied without remove_to_redeem" do
      json = %({"input_tokens":10,"output_tokens":5,"fallback_credit":{"status":{"type":"not_applied","reason":"expired"}}})
      usage = Anthropic::Usage.from_json(json)

      status = usage.fallback_credit.not_nil!.status.as(Anthropic::FallbackCreditNotApplied)
      status.reason.should eq("expired")
      status.remove_to_redeem.should be_nil
    end

    it "parses fallback_credit on DeltaUsage" do
      json = %({"output_tokens":12,"fallback_credit":{"status":{"type":"redeemed"}},"iterations":[{"type":"fallback_message","model":"claude-opus-4-8","input_tokens":5,"output_tokens":12}]})
      delta = Anthropic::DeltaUsage.from_json(json)

      delta.output_tokens.should eq(12)
      delta.fallback_credit.not_nil!.redeemed?.should be_true
      delta.iterations.not_nil!.size.should eq(1)
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

    it "serializes fallbacks: \"default\" and attaches the July server-side beta" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_FABLE_5,
        max_tokens: 256,
        fallbacks: "default",
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::SERVER_SIDE_FALLBACK_BETA_2026_07_01)
      body = JSON.parse(capture.body.not_nil!)
      body["fallbacks"].as_s.should eq("default")
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

    it "attaches fallback-credit-2026-07-01 for object-form credit token" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_8,
        max_tokens: 256,
        fallback_credit_token: Anthropic::FallbackCreditTokenParam.new(
          token: "fct_mode",
          mode: "best_effort",
        ),
        messages: [{role: "user", content: "hi"}]
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::FALLBACK_CREDIT_BETA_2026_07_01)
      body = JSON.parse(capture.body.not_nil!)
      body["fallback_credit_token"]["token"].as_s.should eq("fct_mode")
      body["fallback_credit_token"]["mode"].as_s.should eq("best_effort")
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
    it "exposes June and July fallback beta constants" do
      Anthropic::SERVER_SIDE_FALLBACK_BETA_2026_06_01.should eq("server-side-fallback-2026-06-01")
      Anthropic::SERVER_SIDE_FALLBACK_BETA_2026_07_01.should eq("server-side-fallback-2026-07-01")
      Anthropic::SERVER_SIDE_FALLBACK_BETA.should eq("server-side-fallback-2026-07-01")

      Anthropic::FALLBACK_CREDIT_BETA_2026_06_01.should eq("fallback-credit-2026-06-01")
      Anthropic::FALLBACK_CREDIT_BETA_2026_07_01.should eq("fallback-credit-2026-07-01")
      Anthropic::FALLBACK_CREDIT_BETA.should eq("fallback-credit-2026-07-01")

      Anthropic::AGENT_MEMORY_BETA.should eq("agent-memory-2026-07-22")
    end
  end
end
