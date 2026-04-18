require "../spec_helper"

# Specs covering the Opus 4.7 / April 2026 parity updates.
#
# Groups: model constants, citation variants, stop_details unions,
# advisor tool + content blocks, user profiles resource, task budgets,
# encrypted compaction, and error handling gaps (413/504/529 + error_type).
describe "Opus 4.7 parity updates" do
  describe Anthropic::Model do
    it "exposes claude-opus-4-7 and claude-mythos-preview constants" do
      Anthropic::Model::CLAUDE_OPUS_4_7.should eq("claude-opus-4-7")
      Anthropic::Model::CLAUDE_MYTHOS_PREVIEW.should eq("claude-mythos-preview")
    end

    it "points CLAUDE_OPUS rolling alias at 4.7" do
      Anthropic::Model::CLAUDE_OPUS.should eq(Anthropic::Model::CLAUDE_OPUS_4_7)
    end

    it "resolves :opus and :opus_4_7 via model_name" do
      Anthropic.model_name(:opus).should eq("claude-opus-4-7")
      Anthropic.model_name(:opus_4_7).should eq("claude-opus-4-7")
    end

    it "resolves :mythos via model_name" do
      Anthropic.model_name(:mythos).should eq("claude-mythos-preview")
    end

    it "preserves legacy shorthand mappings" do
      Anthropic.model_name(:sonnet).should eq("claude-sonnet-4-6")
      Anthropic.model_name(:haiku).should eq("claude-haiku-4-5-20251001")
      Anthropic.model_name(:opus_4_5).should eq("claude-opus-4-5-20251101")
    end

    it "raises an ArgumentError for unknown shorthand" do
      expect_raises(ArgumentError, /Unknown model shorthand/) do
        Anthropic.model_name(:nonexistent_model)
      end
    end
  end

  describe "EffortCapability" do
    it "parses an xhigh effort level when present" do
      json = %({"supported":true,"low":{"supported":true},"medium":{"supported":true},"high":{"supported":true},"max":{"supported":true},"xhigh":{"supported":true}})
      caps = Anthropic::EffortCapability.from_json(json)
      caps.xhigh.should_not be_nil
      caps.xhigh.not_nil!.supported?.should be_true
    end

    it "tolerates payloads that omit xhigh" do
      json = %({"supported":true,"low":{"supported":true},"medium":{"supported":true},"high":{"supported":true},"max":{"supported":true}})
      caps = Anthropic::EffortCapability.from_json(json)
      caps.xhigh.should be_nil
    end
  end

  describe "CompactionContent with encrypted_content" do
    it "parses encrypted_content on compaction blocks" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_ENCRYPTED_COMPACTION)
      compaction = message.content.first.as(Anthropic::CompactionContent)
      compaction.encrypted_content.should eq("ENCRYPTED_SUMMARY_BLOB")
      compaction.content.should be_nil
    end

    it "serializes encrypted_content on round-trip" do
      block = Anthropic::CompactionContent.new(encrypted_content: "BLOB")
      JSON.parse(block.to_json)["encrypted_content"].as_s.should eq("BLOB")
    end

    it "parses encrypted_content on compaction deltas" do
      json = %({"type":"compaction_delta","encrypted_content":"ENC_XYZ"})
      delta = Anthropic::CompactionDelta.from_json(json)
      delta.encrypted_content.should eq("ENC_XYZ")
    end
  end

  describe "Citation union variants" do
    it "parses page-location citations via TextContentWithCitations" do
      block_json = %({"type":"text","text":"per the 2023 report","citations":[{"type":"page_location","document_title":"Annual Report","document_index":0,"start_page_number":12,"end_page_number":13,"cited_text":"revenue grew 20%"}]})
      block = Anthropic::TextContentWithCitations.from_json(block_json)
      block.citations.not_nil!.size.should eq(1)
      citation = block.citations.not_nil!.first.as(Anthropic::CitationPageLocation)
      citation.start_page_number.should eq(12)
      citation.end_page_number.should eq(13)
      citation.cited_text.not_nil!.should eq("revenue grew 20%")
    end

    it "falls back to char_location for untagged citations" do
      block_json = %({"type":"text","text":"see the report","citations":[{"start_char":5,"end_char":10,"document_title":"doc","document_index":0,"cited_text":"hello"}]})
      block = Anthropic::TextContentWithCitations.from_json(block_json)
      citation = block.citations.not_nil!.first.as(Anthropic::Citation)
      citation.start_char.should eq(5)
      citation.end_char.should eq(10)
    end

    it "parses web_search_result_location citations" do
      json = %({"type":"web_search_result_location","cited_text":"x","title":"T","url":"https://example.com"})
      citation = Anthropic::CitationConverter.from_json(JSON::PullParser.new(json))
      web = citation.as(Anthropic::CitationWebSearchResultLocation)
      web.url.not_nil!.should eq("https://example.com")
    end
  end

  describe "CitationsDelta (streaming) variants" do
    it "exposes char-location citation deltas via citation()" do
      json = %({"type":"citations_delta","citation":{"type":"char_location","start_char_index":0,"end_char_index":5,"document_title":"doc","document_index":0,"cited_text":"hello"}})
      delta = Anthropic::CitationsDelta.from_json(json)
      delta.citation_type.should eq("char_location")
      data = delta.citation.not_nil!
      data.start_char_index.should eq(0)
      data.end_char_index.should eq(5)
    end

    it "returns nil from citation() for non-char-location variants" do
      json = %({"type":"citations_delta","citation":{"type":"page_location","start_page_number":1,"end_page_number":2}})
      delta = Anthropic::CitationsDelta.from_json(json)
      delta.citation_type.should eq("page_location")
      delta.citation.should be_nil
    end

    it "preserves the raw citation payload for non-char variants" do
      json = %({"type":"citations_delta","citation":{"type":"page_location","start_page_number":1,"end_page_number":2,"document_title":"Doc"}})
      delta = Anthropic::CitationsDelta.from_json(json)
      delta.citation_data["document_title"].as_s.should eq("Doc")
    end
  end

  describe "stop_details union" do
    it "parses refusal stop_details into RefusalStopDetails" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_REFUSAL)
      details = message.refusal_stop_details.not_nil!
      details.category.not_nil!.should eq("cyber")
      message.refusal?.should be_true
    end

    it "falls back to GenericStopDetails for unknown variants" do
      json = %({"id":"msg_x","type":"message","role":"assistant","content":[{"type":"text","text":"hi"}],"model":"claude-opus-4-7","stop_reason":"end_turn","stop_details":{"type":"future_variant","custom":"data"},"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}})
      message = Anthropic::Message.from_json(json)
      details = message.stop_details.as?(Anthropic::GenericStopDetails).not_nil!
      details.type.should eq("future_variant")
      details.raw["custom"].as_s.should eq("data")
      message.refusal_stop_details.should be_nil
      message.refusal?.should be_false
    end

    it "round-trips refusal stop_details through to_json" do
      details = Anthropic::RefusalStopDetails.new(category: "cyber", explanation: "nope")
      json = details.to_json
      parsed = Anthropic::RefusalStopDetails.from_json(json)
      parsed.category.not_nil!.should eq("cyber")
    end
  end

  describe "Advisor tool + result blocks" do
    it "serializes AdvisorTool with the advisor_20260301 type" do
      tool = Anthropic::AdvisorTool.new(model: Anthropic::Model::CLAUDE_HAIKU_4_5, max_uses: 3)
      parsed = JSON.parse(tool.to_json)
      parsed["type"].as_s.should eq("advisor_20260301")
      parsed["name"].as_s.should eq("advisor")
      parsed["model"].as_s.should eq("claude-haiku-4-5-20251001")
      parsed["max_uses"].as_i.should eq(3)
    end

    it "collects the advisor beta header via beta_headers_for_tools" do
      tools = [Anthropic::AdvisorTool.new(model: Anthropic::Model::CLAUDE_HAIKU_4_5)] of (Anthropic::ServerTool | Anthropic::ToolDefinition)
      Anthropic.beta_headers_for_tools(tools).should eq([Anthropic::ADVISOR_TOOL_BETA])
    end

    it "parses advisor_result content blocks" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_ADVISOR)
      advisor_block = message.content.find! { |block| block.is_a?(Anthropic::AdvisorToolResultContent) }.as(Anthropic::AdvisorToolResultContent)
      advisor_block.tool_use_id.should eq("stu_adv_01")
      inner = advisor_block.content.as(Anthropic::AdvisorResultContent)
      inner.text.should eq("No critical issues spotted.")
    end

    it "parses encrypted advisor_redacted_result content blocks" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_ADVISOR_REDACTED)
      advisor_block = message.content.first.as(Anthropic::AdvisorToolResultContent)
      inner = advisor_block.content.as(Anthropic::AdvisorRedactedResultContent)
      inner.encrypted_content.should eq("OPAQUE_BLOB_XYZ")
    end

    it "parses advisor_tool_result_error content blocks" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_ADVISOR_ERROR)
      advisor_block = message.content.first.as(Anthropic::AdvisorToolResultContent)
      inner = advisor_block.content.as(Anthropic::AdvisorToolResultErrorContent)
      inner.error_code.should eq("max_uses_exceeded")
    end
  end

  describe "Additional code_execution / text_editor tool versions" do
    it "CodeExecutionTool20250522 serializes with the original type string" do
      tool = Anthropic::CodeExecutionTool20250522.new
      JSON.parse(tool.to_json)["type"].as_s.should eq("code_execution_20250522")
    end

    it "TextEditorTool20250124 serializes with the legacy editor name" do
      tool = Anthropic::TextEditorTool20250124.new
      parsed = JSON.parse(tool.to_json)
      parsed["type"].as_s.should eq("text_editor_20250124")
      parsed["name"].as_s.should eq("str_replace_editor")
    end

    it "TextEditorTool20250429 serializes with the current editor name" do
      tool = Anthropic::TextEditorTool20250429.new
      parsed = JSON.parse(tool.to_json)
      parsed["type"].as_s.should eq("text_editor_20250429")
      parsed["name"].as_s.should eq("str_replace_based_edit_tool")
    end

    it "collects the right beta header for CodeExecutionTool20250522" do
      tools = [Anthropic::CodeExecutionTool20250522.new] of (Anthropic::ServerTool | Anthropic::ToolDefinition)
      Anthropic.beta_headers_for_tools(tools).should eq([Anthropic::CODE_EXECUTION_BETA])
    end
  end

  describe "Beta header constants" do
    it "exposes ADVISOR_TOOL_BETA and USER_PROFILES_BETA" do
      Anthropic::ADVISOR_TOOL_BETA.should eq("advisor-tool-2026-03-01")
      Anthropic::USER_PROFILES_BETA.should eq("user-profiles-2026-03-24")
    end

    it "exposes additional historical / newer beta headers" do
      Anthropic::CONTEXT_1M_BETA.should eq("context-1m-2025-08-07")
      Anthropic::INTERLEAVED_THINKING_BETA.should eq("interleaved-thinking-2025-05-14")
      Anthropic::FAST_MODE_BETA.should eq("fast-mode-2026-02-01")
      Anthropic::OUTPUT_300K_BETA.should eq("output-300k-2026-03-24")
    end
  end

  describe "BetaTokenTaskBudget + OutputConfig task_budget" do
    it "serializes a BetaTokenTaskBudget with type: tokens" do
      budget = Anthropic::BetaTokenTaskBudget.new(total: 100_000, remaining: 75_000)
      parsed = JSON.parse(budget.to_json)
      parsed["type"].as_s.should eq("tokens")
      parsed["total"].as_i.should eq(100_000)
      parsed["remaining"].as_i.should eq(75_000)
    end

    it "omits remaining when not set" do
      budget = Anthropic::BetaTokenTaskBudget.new(total: 100_000)
      parsed = JSON.parse(budget.to_json)
      parsed.as_h.has_key?("remaining").should be_false
    end

    it "includes task_budget on OutputConfig JSON payload" do
      budget = Anthropic::BetaTokenTaskBudget.new(total: 200_000)
      output_config = Anthropic::OutputConfig.new(effort: "xhigh", task_budget: budget)
      parsed = JSON.parse(output_config.to_json)
      parsed["effort"].as_s.should eq("xhigh")
      parsed["task_budget"]["total"].as_i.should eq(200_000)
    end

    it "omits task_budget when not set" do
      output_config = Anthropic::OutputConfig.new(effort: "high")
      parsed = JSON.parse(output_config.to_json)
      parsed.as_h.has_key?("task_budget").should be_false
    end
  end

  describe "BetaMessageCreateParams#user_profile_id wiring" do
    it "includes user_profile_id in the request body when provided" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_7,
        max_tokens: 128,
        messages: [Anthropic::MessageParam.user("hi")],
        user_profile_id: "uprof_01abc"
      )

      body = JSON.parse(capture.body.not_nil!)
      body["user_profile_id"].as_s.should eq("uprof_01abc")
    end

    it "adds the user-profiles beta header automatically" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_7,
        max_tokens: 128,
        messages: [Anthropic::MessageParam.user("hi")],
        user_profile_id: "uprof_01abc"
      )

      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::USER_PROFILES_BETA)
    end

    it "does not add the user-profiles beta header when user_profile_id is omitted" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_OPUS_4_7,
        max_tokens: 128,
        messages: [Anthropic::MessageParam.user("hi")]
      )

      capture.headers.not_nil!["anthropic-beta"]?.try(&.includes?(Anthropic::USER_PROFILES_BETA)).should_not be_true
    end
  end

  describe Anthropic::BetaUserProfiles do
    it "creates a profile and POSTs external_id + metadata" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles?beta=true", Fixtures::Responses::USER_PROFILE)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      profile = client.beta.user_profiles.create(
        external_id: "ext-123",
        metadata: {"plan" => "pro"}
      )

      profile.id.should eq("uprof_01abc")
      profile.external_id.not_nil!.should eq("ext-123")

      body = JSON.parse(capture.body.not_nil!)
      body["external_id"].as_s.should eq("ext-123")
      body["metadata"]["plan"].as_s.should eq("pro")

      capture.headers.not_nil!["anthropic-beta"].should eq(Anthropic::USER_PROFILES_BETA)
    end

    it "retrieves a profile" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/user_profiles/uprof_01abc?beta=true")
        .to_return(body: Fixtures::Responses::USER_PROFILE)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      profile = client.beta.user_profiles.retrieve("uprof_01abc")
      profile.metadata["plan"].should eq("pro")
    end

    it "lists profiles" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/user_profiles?beta=true&limit=20")
        .to_return(body: Fixtures::Responses::USER_PROFILE_LIST)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response = client.beta.user_profiles.list
      response.data.size.should eq(1)
      response.data.first.trust_grants["memory"].status.should eq("active")
    end

    it "creates an enrollment URL" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/user_profiles/uprof_01abc/enrollment_url?beta=true")
        .to_return(body: Fixtures::Responses::USER_PROFILE_ENROLLMENT_URL)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      enrollment = client.beta.user_profiles.create_enrollment_url("uprof_01abc")
      enrollment.type.should eq("enrollment_url")
      enrollment.url.should contain("uprof_01abc")
    end
  end

  describe "APIError error_type and status code mapping" do
    it "populates error_type from the error envelope" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 400, body: Fixtures::Responses::ERROR_BAD_REQUEST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      begin
        client.messages.create(
          model: Anthropic::Model::CLAUDE_OPUS_4_7,
          max_tokens: 10,
          messages: [{role: "user", content: "hi"}]
        )
      rescue ex : Anthropic::BadRequestError
        ex.error_type.not_nil!.should eq("invalid_request_error")
      end
    end

    it "raises PayloadTooLargeError on 413" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 413, body: Fixtures::Responses::ERROR_PAYLOAD_TOO_LARGE)

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      expect_raises(Anthropic::PayloadTooLargeError) do
        client.messages.create(
          model: Anthropic::Model::CLAUDE_OPUS_4_7,
          max_tokens: 10,
          messages: [{role: "user", content: "hi"}]
        )
      end
    end

    it "raises GatewayTimeoutError on 504" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 504, body: Fixtures::Responses::ERROR_GATEWAY_TIMEOUT)

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        max_retries: 0,
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0,
      )
      expect_raises(Anthropic::GatewayTimeoutError) do
        client.messages.create(
          model: Anthropic::Model::CLAUDE_OPUS_4_7,
          max_tokens: 10,
          messages: [{role: "user", content: "hi"}]
        )
      end
    end

    it "raises OverloadedError on 529" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 529, body: Fixtures::Responses::ERROR_OVERLOADED)

      client = Anthropic::Client.new(
        api_key: "sk-ant-test",
        max_retries: 0,
        initial_retry_delay: 0.0,
        max_retry_delay: 0.0,
      )
      expect_raises(Anthropic::OverloadedError) do
        client.messages.create(
          model: Anthropic::Model::CLAUDE_OPUS_4_7,
          max_tokens: 10,
          messages: [{role: "user", content: "hi"}]
        )
      end
    end

    it "tolerates empty error bodies" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 400, body: "")

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      begin
        client.messages.create(
          model: Anthropic::Model::CLAUDE_OPUS_4_7,
          max_tokens: 10,
          messages: [{role: "user", content: "hi"}]
        )
      rescue ex : Anthropic::BadRequestError
        ex.error_type.should be_nil
      end
    end
  end

  describe "Streaming raises on SSE error events" do
    it "raises OverloadedError when the stream includes an overloaded_error event" do
      body = "event: error\ndata: {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Please retry\"}}\n\n"
      response = HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
        body_io: IO::Memory.new(body),
      )
      stream = Anthropic::MessageStream.new(response)

      expect_raises(Anthropic::OverloadedError) do
        stream.each { |_event| }
      end
    end

    it "raises BadRequestError for invalid_request_error SSE events" do
      body = "event: error\ndata: {\"type\":\"error\",\"error\":{\"type\":\"invalid_request_error\",\"message\":\"bad\"}}\n\n"
      response = HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
        body_io: IO::Memory.new(body),
      )
      stream = Anthropic::MessageStream.new(response)

      begin
        stream.each { |_event| }
      rescue ex : Anthropic::BadRequestError
        ex.error_type.should eq("invalid_request_error")
      end
    end
  end
end
