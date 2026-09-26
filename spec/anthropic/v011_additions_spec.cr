require "../spec_helper"

private def v011_tool(name : String) : Anthropic::Tool
  Anthropic.tool(
    name: name,
    description: "A v0.11.0 test tool",
    schema: {} of String => Anthropic::Schema::Property,
    required: [] of String
  ) { |_| "result from #{name}" }
end

private def v011_sse_capture(url : String, body : String) : RequestCapture
  capture = RequestCapture.new

  WebMock.stub(:post, url).to_return do |request|
    capture.body = request.body.to_s
    capture.headers = request.headers
    capture.path = request.resource
    capture.method = request.method
    HTTP::Client::Response.new(
      200,
      headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
      body_io: IO::Memory.new(body)
    )
  end

  capture
end

private def v011_sequenced_stub(url : String, bodies : Array(String), responses : Array(String))
  queue = responses.dup

  WebMock.stub(:post, url).to_return do |request|
    bodies << request.body.to_s
    HTTP::Client::Response.new(200, body: queue.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
  end
end

# Coverage for the v0.11.0 upstream-parity additions: explicit compaction
# (summarize params, signed blocks, per-request batch compaction), the
# September beta revisions, rate-limit groups, MCP tool listings, response
# tools, input transformations, web-fetch URL sources, user external
# details, data-residency geos, and runner tool-change controls.
describe "v0.11.0 parity additions" do
  describe "model constants and beta flags" do
    it "exposes CLAUDE_OPUS_5_5 and the :opus_5_5 shorthand" do
      Anthropic::Model::CLAUDE_OPUS_5_5.should eq("claude-opus-5-5")
      Anthropic.model_name(:opus_5_5).should eq("claude-opus-5-5")
    end

    it "exposes the September beta revision flags" do
      Anthropic::USER_PROFILES_2026_09_04_BETA.should eq("user-profiles-2026-09-04")
      Anthropic::COMPACT_2026_09_04_BETA.should eq("compact-2026-09-04")
      Anthropic::INLINE_TOOLS_2026_09_15_BETA.should eq("inline-tools-2026-09-15")
      Anthropic::MCP_CLIENT_2026_09_15_BETA.should eq("mcp-client-2026-09-15")
    end

    it "parses the compaction model capability when present" do
      json = %({"type":"model","id":"claude-opus-5-5","display_name":"Claude Opus 5.5","capabilities":{"batch":{"supported":true},"citations":{"supported":true},"code_execution":{"supported":true},"compaction":{"summarize":{"supported":true},"supported":true},"context_management":{"supported":true},"effort":{"supported":true,"low":{"supported":true},"medium":{"supported":true},"high":{"supported":true},"max":{"supported":true}},"image_input":{"supported":true},"pdf_input":{"supported":true},"structured_outputs":{"supported":true},"thinking":{"supported":true,"types":{"adaptive":{"supported":true},"enabled":{"supported":true}}}}})
      info = Anthropic::ModelInfo.from_json(json)
      compaction = info.capabilities.not_nil!.compaction
      compaction.should_not be_nil
      compaction.not_nil!.supported?.should be_true
      compaction.not_nil!.summarize.supported?.should be_true
    end

    it "tolerates model payloads that omit the compaction capability" do
      info = Anthropic::ModelInfo.from_json(Fixtures::Responses::MODEL_INFO)
      info.capabilities.not_nil!.compaction.should be_nil
    end
  end

  describe "SummarizeCompaction" do
    it "serializes the default summarize request" do
      json = JSON.parse(Anthropic::SummarizeCompaction.new.to_json)
      json["type"].as_s.should eq("summarize")
      json.as_h.has_key?("instructions").should be_false
    end

    it "serializes custom instructions" do
      json = JSON.parse(Anthropic::SummarizeCompaction.new(instructions: "Focus on decisions.").to_json)
      json["instructions"].as_s.should eq("Focus on decisions.")
    end
  end

  describe "beta messages compaction" do
    it "sends compaction and attaches the compact beta on create" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      message = client.beta.messages.create(
        model: "claude-opus-5-5",
        max_tokens: 1024,
        messages: [{role: "user", content: "hi"}],
        compaction: Anthropic::SummarizeCompaction.new(instructions: "Be brief.")
      )

      message.content.first.should be_a(Anthropic::CompactionContent)

      body = JSON.parse(capture.body.not_nil!)
      body["compaction"]["type"].as_s.should eq("summarize")
      body["compaction"]["instructions"].as_s.should eq("Be brief.")
      capture.headers.not_nil!["anthropic-beta"].should contain("compact-2026-09-04")
    end

    it "attaches the compact beta on streamed compaction requests" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_c1","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      capture = v011_sse_capture("https://api.anthropic.com/v1/messages", sse)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      count = 0
      client.beta.messages.stream(
        model: "claude-opus-5-5",
        max_tokens: 1024,
        messages: [{role: "user", content: "hi"}],
        compaction: Anthropic::SummarizeCompaction.new
      ) { |_| count += 1 }

      count.should eq(2)
      JSON.parse(capture.body.not_nil!)["compaction"]["type"].as_s.should eq("summarize")
      capture.headers.not_nil!["anthropic-beta"].should contain("compact-2026-09-04")
    end

    it "forwards compaction on parse" do
      payload = %({"city":"Paris"}).to_json
      response = %({"id":"msg_parse_beta","type":"message","role":"assistant","content":[{"type":"text","text":#{payload}}],"model":"claude-opus-5-5","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":12}})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", response)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      schema = Anthropic.output_schema(
        name: "city_summary",
        schema: {"city" => Anthropic::Schema.string("City")},
        required: ["city"]
      )

      parsed = client.beta.messages.parse(
        model: "claude-opus-5-5",
        max_tokens: 256,
        output_schema: schema,
        messages: [{role: "user", content: "Name a city"}],
        compaction: Anthropic::SummarizeCompaction.new
      )

      parsed.parsed_output["city"].as_s.should eq("Paris")
      body = JSON.parse(capture.body.not_nil!)
      body["compaction"]["type"].as_s.should eq("summarize")
      capture.headers.not_nil!["anthropic-beta"].should contain("compact-2026-09-04")
    end

    it "sends compaction on token counting" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/count_tokens?beta=true", Fixtures::Responses::TOKEN_COUNT_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      count = client.beta.messages.count_tokens(
        model: "claude-opus-5-5",
        messages: [{role: "user", content: "hi"}],
        compaction: Anthropic::SummarizeCompaction.new
      )

      count.input_tokens.should eq(25)
      JSON.parse(capture.body.not_nil!)["compaction"]["type"].as_s.should eq("summarize")
      capture.headers.not_nil!["anthropic-beta"].should contain("compact-2026-09-04")
    end
  end

  describe "beta batch per-request compaction" do
    it "sends compaction inside the request params and attaches the beta" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/batches?beta=true", Fixtures::Responses::BETA_BATCH_CREATED)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.messages.batches.create(
        requests: [
          Anthropic::BetaBatchRequest.new(
            custom_id: "req-1",
            params: Anthropic::BetaBatchRequestParams.new(
              model: "claude-opus-5-5",
              max_tokens: 100,
              messages: [Anthropic::MessageParam.user("Hello")],
              compaction: Anthropic::SummarizeCompaction.new
            )
          ),
        ]
      )

      body = JSON.parse(capture.body.not_nil!)
      body.as_h.has_key?("compaction").should be_false
      body["requests"][0]["params"]["compaction"]["type"].as_s.should eq("summarize")
      capture.headers.not_nil!["anthropic-beta"].should contain("compact-2026-09-04")
    end
  end

  describe "signed compaction blocks" do
    it "parses signature and tool changes" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION)
      block = message.content.first.as(Anthropic::CompactionContent)
      block.content.should eq("Compacted summary.")
      block.signature.should eq("sig_xyz")

      changes = block.tool_changes.not_nil!
      changes.size.should eq(2)

      addition = changes[0].as(Anthropic::ToolAdditionContent)
      definition = addition.tool.as(Anthropic::ToolChangeToolDefinition).definition
      definition.should be_a(Anthropic::ResponseTool)
      definition.as(Anthropic::ResponseTool).name.should eq("helper")

      removal = changes[1].as(Anthropic::ToolRemovalContent)
      removal.tool.as(Anthropic::ToolChangeToolReference).name.should eq("legacy")
    end

    it "round-trips tool changes through JSON" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION)
      block = message.content.first.as(Anthropic::CompactionContent)
      parsed = Anthropic::CompactionContent.from_json(block.to_json)
      parsed.signature.should eq("sig_xyz")
      parsed.tool_changes.not_nil!.size.should eq(2)
    end

    it "keeps server-tool definitions as raw JSON" do
      json = %({"type":"tool_definition","definition":{"type":"mcp_toolset","mcp_server_name":"srv"}})
      reference = Anthropic::ToolChangeToolDefinition.from_json(json)
      raw = reference.definition.as(JSON::Any)
      raw["type"].as_s.should eq("mcp_toolset")
    end

    it "builds a response tool from a request definition" do
      definition = v011_tool("helper").to_definition
      response = Anthropic::ResponseTool.from_definition(definition)
      response.name.should eq("helper")
      response.input_schema["type"].as_s.should eq("object")
      response.description.should eq(definition.description)
    end
  end

  describe "MCP tool listings" do
    it "parses listing blocks from messages" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_MCP_LISTING)
      block = message.content.first.as(Anthropic::MCPToolListingContent)
      block.mcp_server_name.should eq("my-server")
      block.tools.size.should eq(1)
      block.tools.first.name.should eq("get_data")
      block.tools.first.description.should eq("Fetch data.")
    end

    it "serializes pinned tools on the toolset" do
      toolset = Anthropic::MCPToolset.new(
        mcp_server_name: "srv",
        tools: [Anthropic::MCPToolListingEntry.new(input_schema: JSON.parse(%({"type":"object"})), name: "get_data")]
      )
      json = JSON.parse(toolset.to_json)
      json["tools"][0]["name"].as_s.should eq("get_data")
    end

    it "omits tools when the listing is not pinned" do
      json = JSON.parse(Anthropic::MCPToolset.new(mcp_server_name: "srv").to_json)
      json.as_h.has_key?("tools").should be_false
    end

    it "attaches the new mcp-client beta only for pinned toolsets" do
      pinned = Anthropic::MCPToolset.new(
        mcp_server_name: "srv",
        tools: [Anthropic::MCPToolListingEntry.new(input_schema: JSON.parse(%({"type":"object"})), name: "get_data")]
      )
      betas = Anthropic.beta_headers_for_tools([pinned] of Anthropic::ServerTool | Anthropic::ToolDefinition)
      betas.should contain(Anthropic::MCP_CLIENT_2026_09_15_BETA)
      betas.should_not contain(Anthropic::MCP_CLIENT_BETA)

      unpinned = Anthropic::MCPToolset.new(mcp_server_name: "srv")
      betas = Anthropic.beta_headers_for_tools([unpinned] of Anthropic::ServerTool | Anthropic::ToolDefinition)
      betas.should contain(Anthropic::MCP_CLIENT_BETA)
      betas.should_not contain(Anthropic::MCP_CLIENT_2026_09_15_BETA)
    end
  end

  describe "input transformations" do
    it "exposes the binding-mismatch reason constants" do
      Anthropic::InputTransformationReason::MODEL_BINDING_MISMATCH.should eq("model_binding_mismatch")
      Anthropic::InputTransformationReason::PREFIX_BINDING_MISMATCH.should eq("prefix_binding_mismatch")
      Anthropic::InputTransformationReason::ORGANIZATION_BINDING_MISMATCH.should eq("organization_binding_mismatch")
      Anthropic::InputTransformationReason::END_USER_BINDING_MISMATCH.should eq("end_user_binding_mismatch")
    end

    it "parses transformations reported on a message" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_WITH_INPUT_TRANSFORMATIONS)
      entries = message.input_transformations.not_nil!
      entries.size.should eq(2)

      dropped = entries[0].as(Anthropic::ThinkingDroppedInputTransformation)
      dropped.path.should eq("messages.2.content.0")
      dropped.reason.should eq("model_binding_mismatch")

      allowed = entries[1].as(Anthropic::ThinkingMismatchAllowedInputTransformation)
      allowed.path.should eq("messages.4.content.1")
      allowed.reason.should eq("prefix_binding_mismatch")
    end

    it "leaves transformations nil when the API reports none" do
      message = Anthropic::Message.from_json(Fixtures::Responses::MESSAGE_BASIC)
      message.input_transformations.should be_nil
    end
  end

  describe "streaming compaction and transformation accumulation" do
    it "assigns each compaction delta as the final value" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_c1","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"compaction"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"stale summary"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"final summary","encrypted_content":"BLOB"}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      v011_sse_capture("https://api.anthropic.com/v1/messages", sse)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      final = nil
      client.beta.messages.open_stream(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      ) do |stream|
        stream.each { |_| }
        final = stream.final_message
      end

      block = final.not_nil!.content.first.as(Anthropic::CompactionContent)
      block.content.should eq("final summary")
      block.encrypted_content.should eq("BLOB")
    end

    it "treats null compaction content as a failed compaction" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_c2","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"compaction"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"partial"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":null}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      v011_sse_capture("https://api.anthropic.com/v1/messages", sse)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      final = nil
      client.beta.messages.open_stream(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      ) do |stream|
        stream.each { |_| }
        final = stream.final_message
      end

      block = final.not_nil!.content.first.as(Anthropic::CompactionContent)
      block.content.should be_nil
    end

    it "replaces message_start transformations with the message_delta value" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_t1","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0},"input_transformations":[{"type":"thinking_dropped","path":"messages.0.content.0","reason":"prefix_binding_mismatch"}]}}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5},"input_transformations":[{"type":"thinking_mismatch_allowed","path":"messages.1.content.0","reason":"prefix_binding_mismatch"}]}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      v011_sse_capture("https://api.anthropic.com/v1/messages", sse)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      final = nil
      client.beta.messages.open_stream(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      ) do |stream|
        stream.each { |_| }
        final = stream.final_message
      end

      entries = final.not_nil!.input_transformations.not_nil!
      entries.size.should eq(1)
      entries.first.as(Anthropic::ThinkingMismatchAllowedInputTransformation).path.should eq("messages.1.content.0")
    end
  end

  describe "web-fetch URL sources" do
    it "round-trips every tool-result scope including none" do
      sources = Anthropic::WebFetchURLSources.new(
        client_tool_results: Anthropic::WebFetchURLSourceOnly.tools("search"),
        server_tool_results: Anthropic::WebFetchURLSourceNone.new,
        user_input: Anthropic::WebFetchURLSourceAll.new
      )
      parsed = Anthropic::WebFetchURLSources.from_json(sources.to_json)
      only = parsed.client_tool_results.as(Anthropic::WebFetchURLSourceOnly)
      only.tools.map(&.name).should eq(["search"])
      only.tools.first.type.should eq("tool_reference")
      parsed.server_tool_results.should be_a(Anthropic::WebFetchURLSourceNone)
      parsed.user_input.should be_a(Anthropic::WebFetchURLSourceAll)
    end

    it "round-trips all and except scopes" do
      sources = Anthropic::WebFetchURLSources.new(
        client_tool_results: Anthropic::WebFetchURLSourceAll.new,
        server_tool_results: Anthropic::WebFetchURLSourceExcept.tools("fetch")
      )
      parsed = Anthropic::WebFetchURLSources.from_json(sources.to_json)
      parsed.client_tool_results.should be_a(Anthropic::WebFetchURLSourceAll)
      except = parsed.server_tool_results.as(Anthropic::WebFetchURLSourceExcept)
      except.tools.map(&.name).should eq(["fetch"])
    end

    it "rejects unknown scope types" do
      expect_raises(JSON::ParseException, /Unknown web-fetch URL source scope type: "sometimes"/) do
        Anthropic::WebFetchURLSources.from_json(%({"client_tool_results":{"type":"sometimes"}}))
      end
    end

    it "rejects tool filters on the user-input scope" do
      expect_raises(JSON::ParseException, /Unknown web-fetch user-input scope type/) do
        Anthropic::WebFetchURLSources.from_json(%({"user_input":{"type":"only","tools":[]}}))
      end
      expect_raises(JSON::ParseException, /Unknown web-fetch user-input scope type/) do
        Anthropic::WebFetchURLSources.from_json(%({"user_input":{"type":"except","tools":[]}}))
      end
    end

    it "serializes url_sources on web-fetch tools" do
      tool = Anthropic::WebFetchTool20260318.new(
        url_sources: Anthropic::WebFetchURLSources.new(
          user_input: Anthropic::WebFetchURLSourceNone.new
        )
      )
      json = JSON.parse(tool.to_json)
      json["url_sources"]["user_input"]["type"].as_s.should eq("none")
    end

    it "serializes url_sources on every web-fetch tool version" do
      sources = Anthropic::WebFetchURLSources.new(user_input: Anthropic::WebFetchURLSourceAll.new)

      JSON.parse(Anthropic::WebFetchTool.new(url_sources: sources).to_json)["url_sources"]["user_input"]["type"].as_s.should eq("all")
      JSON.parse(Anthropic::WebFetchTool20260209.new(url_sources: sources).to_json)["url_sources"]["user_input"]["type"].as_s.should eq("all")
      JSON.parse(Anthropic::WebFetchTool20260309.new(url_sources: sources).to_json)["url_sources"]["user_input"]["type"].as_s.should eq("all")
    end

    it "omits url_sources when unset" do
      json = JSON.parse(Anthropic::WebFetchTool.new.to_json)
      json.as_h.has_key?("url_sources").should be_false
    end
  end

  describe "user profile external details" do
    it "sends details and attaches the details beta revision on create" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles?beta=true", Fixtures::Responses::USER_PROFILE_WITH_DETAILS)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      profile = client.beta.user_profiles.create(
        name: "Acme",
        external_user_details: Anthropic::BetaUserProfileExternalUserDetails.new(
          account_status: "active",
          entity_type: "business",
          reference_id: "ref-1"
        )
      )

      profile.external_user_details.not_nil!.reference_id.should eq("ref-1")
      profile.external_user_details.not_nil!.country.should eq("US")

      body = JSON.parse(capture.body.not_nil!)
      body["external_user_details"]["reference_id"].as_s.should eq("ref-1")
      body["external_user_details"].as_h.has_key?("country").should be_false
      capture.headers.not_nil!["anthropic-beta"].should contain("user-profiles-2026-09-04")
    end

    it "omits the details beta revision when no details are sent" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles?beta=true", Fixtures::Responses::USER_PROFILE)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      profile = client.beta.user_profiles.create(name: "Acme")

      profile.external_user_details.should be_nil
      capture.headers.not_nil!["anthropic-beta"].should_not contain("user-profiles-2026-09-04")
    end

    it "parses unset details as nil fields" do
      profile = Anthropic::BetaUserProfile.from_json(Fixtures::Responses::USER_PROFILE_WITH_NULL_DETAILS)
      details = profile.external_user_details.not_nil!
      details.account_status.should be_nil
      details.entity_type.should be_nil
      details.country.should be_nil
      details.email_hash.should be_nil
      details.name_hash.should be_nil
      details.onboarded_at.should be_nil
      details.reference_id.should be_nil
    end

    it "sends details and attaches the details beta revision on update" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles/uprof_01abc?beta=true", Fixtures::Responses::USER_PROFILE_WITH_DETAILS)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      profile = client.beta.user_profiles.update(
        "uprof_01abc",
        external_user_details: Anthropic::BetaUserProfileExternalUserDetails.new(reference_id: "ref-1")
      )

      profile.external_user_details.not_nil!.reference_id.should eq("ref-1")
      body = JSON.parse(capture.body.not_nil!)
      body["external_user_details"]["reference_id"].as_s.should eq("ref-1")
      capture.headers.not_nil!["anthropic-beta"].should contain("user-profiles-2026-09-04")
    end
  end

  describe "data-residency geos" do
    it "exposes the allowed inference geo constants" do
      Anthropic::BetaAllowedInferenceGeo::GLOBAL.should eq("global")
      Anthropic::BetaAllowedInferenceGeo::US.should eq("us")
    end

    it "parses an unrestricted residency" do
      residency = Anthropic::BetaDataResidency.from_json(
        %({"allowed_inference_geos":"unrestricted","default_inference_geo":"global","workspace_geo":"us"})
      )
      residency.unrestricted?.should be_true
    end

    it "parses a listed residency" do
      residency = Anthropic::BetaDataResidency.from_json(
        %({"allowed_inference_geos":["us"],"default_inference_geo":"us","workspace_geo":"us"})
      )
      residency.unrestricted?.should be_false
      residency.allowed_inference_geos.should eq(["us"])
    end

    it "serializes create configs with API defaults omitted" do
      json = JSON.parse(Anthropic::BetaDataResidencyCreateConfig.new.to_json)
      json.as_h.should be_empty

      config = Anthropic::BetaDataResidencyCreateConfig.new(
        allowed_inference_geos: ["us"],
        default_inference_geo: "us"
      )
      json = JSON.parse(config.to_json)
      json["allowed_inference_geos"][0].as_s.should eq("us")
      json.as_h.has_key?("workspace_geo").should be_false
    end

    it "sends data-residency configs on workspace create" do
      workspace = %({"id":"ws_1","archived_at":null,"compartment_id":"comp_1","created_at":"2026-01-01T00:00:00Z","data_residency":null,"display_color":"#fff","external_key_id":null,"name":"prod","tags":{},"type":"workspace"})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces?beta=true", workspace)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      created = client.beta.organization.workspaces.create(
        name: "prod",
        data_residency: Anthropic::BetaDataResidencyCreateConfig.new(
          allowed_inference_geos: "unrestricted",
          default_inference_geo: "global"
        )
      )

      created.data_residency.should be_nil
      body = JSON.parse(capture.body.not_nil!)
      body["data_residency"]["allowed_inference_geos"].as_s.should eq("unrestricted")
      body["data_residency"]["default_inference_geo"].as_s.should eq("global")
    end

    it "parses typed data-residency on workspaces" do
      workspace = %({"id":"ws_1","archived_at":null,"compartment_id":"comp_1","created_at":"2026-01-01T00:00:00Z","data_residency":{"allowed_inference_geos":"unrestricted","default_inference_geo":"global","workspace_geo":"us"},"display_color":"#fff","external_key_id":null,"name":"prod","tags":{},"type":"workspace"})
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces?beta=true", workspace)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      created = client.beta.organization.workspaces.create(name: "prod")
      created.data_residency.not_nil!.unrestricted?.should be_true
    end

    it "sends data-residency configs on workspace update" do
      workspace = %({"id":"ws_1","archived_at":null,"compartment_id":"comp_1","created_at":"2026-01-01T00:00:00Z","data_residency":null,"display_color":"#fff","external_key_id":null,"name":"prod","tags":{},"type":"workspace"})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces/ws_1?beta=true", workspace)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.organization.workspaces.update(
        "ws_1",
        data_residency: Anthropic::BetaDataResidencyUpdateConfig.new(
          allowed_inference_geos: ["us"],
          default_inference_geo: "us"
        )
      )

      body = JSON.parse(capture.body.not_nil!)
      body["data_residency"]["allowed_inference_geos"][0].as_s.should eq("us")
      body["data_residency"].as_h.has_key?("workspace_geo").should be_false
    end

    it "serializes update configs with omitted defaults" do
      json = JSON.parse(Anthropic::BetaDataResidencyUpdateConfig.new.to_json)
      json.as_h.should be_empty
    end
  end

  describe "system role messages" do
    it "serializes Role::System params" do
      param = Anthropic::MessageParam.new(role: Anthropic::Role::System, content: "ctx")
      JSON.parse(param.to_json)["role"].as_s.should eq("system")
    end
  end

  describe "runner tool-change controls" do
    it "sends added tools as tool_addition blocks and runs them" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_EXTRA_TOOL_USE, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.add_tools(v011_tool("extra"))

      first = runner.next_message
      first.not_nil!.tool_use?.should be_true
      second = runner.next_message
      second.not_nil!.tool_use?.should be_false

      bodies.size.should eq(2)
      first_body = JSON.parse(bodies[0])
      system = first_body["messages"][-1]
      system["role"].as_s.should eq("system")
      system["content"][0]["type"].as_s.should eq("tool_addition")
      system["content"][0]["tool"]["type"].as_s.should eq("tool_definition")
      system["content"][0]["tool"]["definition"]["name"].as_s.should eq("extra")

      result = JSON.parse(bodies[1])["messages"][-1]["content"][0]
      result["type"].as_s.should eq("tool_result")
      result["content"].as_s.should eq("result from extra")
    end

    it "attaches the inline-tools beta when tool changes are sent" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.remove_tools("test")
      runner.next_message

      capture.headers.not_nil!["anthropic-beta"].should contain("inline-tools-2026-09-15")
      removal = JSON.parse(capture.body.not_nil!)["messages"][-1]["content"][0]
      removal["type"].as_s.should eq("tool_removal")
      removal["tool"]["name"].as_s.should eq("test")
    end

    it "stops removed tools from running locally" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_TEST_TOOL_USE, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.remove_tools("test")
      runner.next_message
      runner.next_message

      result = JSON.parse(bodies[1])["messages"][-1]["content"][0]
      result["is_error"].as_bool.should be_true
      result["content"].as_s.should eq("Unknown tool: test")
    end

    it "treats raw added definitions as non-runnable overrides" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_TEST_TOOL_USE, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.add_tools(v011_tool("test").to_definition)
      runner.next_message
      runner.next_message

      result = JSON.parse(bodies[1])["messages"][-1]["content"][0]
      result["is_error"].as_bool.should be_true
      result["content"].as_s.should eq("Unknown tool: test")
    end

    it "drops queued tool changes on reset" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.add_tools(v011_tool("extra"))
      runner.reset
      runner.next_message

      messages = JSON.parse(capture.body.not_nil!)["messages"]
      messages.as_a.size.should eq(1)
      messages[0]["role"].as_s.should eq("user")
    end

    it "clears dispatch overrides on reset" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_TEST_TOOL_USE, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.remove_tools("test")
      runner.reset
      runner.next_message
      runner.next_message

      result = JSON.parse(bodies[1])["messages"][-1]["content"][0]
      result["content"].as_s.should eq("result from test")
    end

    it "keeps the inline-tools beta on count_tokens over tool-change history" do
      count_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/count_tokens?beta=true", Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)
      stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool,
        compaction: Anthropic::CompactionConfig.enabled(threshold: 100) { |_, _| }
      )

      runner.remove_tools("test")
      runner.next_message

      count_capture.headers.not_nil!["anthropic-beta"].should contain("inline-tools-2026-09-15")
    end

    it "sends full definitions with cache_control on additions" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      cached = v011_tool("extra").to_definition
      definition = Anthropic::ToolDefinition.new(
        name: cached.name,
        description: cached.description,
        input_schema: cached.input_schema,
        cache_control: Anthropic::CacheControl.ephemeral
      )
      runner.add_tools(definition)
      runner.next_message

      sent = JSON.parse(bodies[0])["messages"][-1]["content"][0]["tool"]["definition"]
      sent["name"].as_s.should eq("extra")
      sent["cache_control"]["type"].as_s.should eq("ephemeral")
    end
  end

  describe "runner explicit compaction" do
    it "runs a compaction turn and replaces the conversation" do
      bodies = [] of String
      headers = [] of HTTP::Headers
      queue = [Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION, Fixtures::Responses::MESSAGE_BASIC]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        bodies << request.body.to_s
        headers << request.headers
        HTTP::Client::Response.new(200, body: queue.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("long conversation")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.compact_before_next_turn
      compacted = runner.next_message
      compacted.not_nil!.content.first.should be_a(Anthropic::CompactionContent)

      compaction_body = JSON.parse(bodies[0])
      compaction_body["compaction"]["type"].as_s.should eq("summarize")
      headers[0]["anthropic-beta"].should contain("compact-2026-09-04")

      runner.next_message
      followup = JSON.parse(bodies[1])
      followup.as_h.has_key?("compaction").should be_false
      followup["messages"].as_a.size.should eq(1)
      followup["messages"][0]["role"].as_s.should eq("assistant")
    end

    it "honours custom compaction instructions" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.compact_before_next_turn(Anthropic::SummarizeCompaction.new(instructions: "Keep todos."))
      runner.next_message

      JSON.parse(bodies[0])["compaction"]["instructions"].as_s.should eq("Keep todos.")
    end

    it "requires a beta runner for explicit compaction" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      expect_raises(ArgumentError, /use_beta/) do
        runner.compact_before_next_turn
      end
    end

    it "requires a beta runner for tool changes" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      expect_raises(ArgumentError, /use_beta/) do
        runner.add_tools(v011_tool("extra"))
      end
      expect_raises(ArgumentError, /use_beta/) do
        runner.remove_tools("test")
      end
    end

    it "falls through to a normal turn when compaction returns no summary" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_BASIC, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.compact_before_next_turn
      message = runner.next_message

      message.should_not be_nil
      bodies.size.should eq(2)
      JSON.parse(bodies[0]).as_h.has_key?("compaction").should be_true
      followup = JSON.parse(bodies[1])
      followup.as_h.has_key?("compaction").should be_false
      followup["messages"].as_a.size.should eq(1)
      followup["messages"][0]["role"].as_s.should eq("user")
    end

    it "accepts encrypted-only compaction summaries" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_ENCRYPTED_COMPACTION, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.compact_before_next_turn
      compacted = runner.next_message
      compacted.not_nil!.content.first.should be_a(Anthropic::CompactionContent)

      bodies.size.should eq(1)
      runner.next_message
      followup = JSON.parse(bodies[1])
      followup["messages"].as_a.size.should eq(1)
      followup["messages"][0]["role"].as_s.should eq("assistant")
    end

    it "runs compaction before flushing queued tool changes" do
      bodies = [] of String
      v011_sequenced_stub(
        "https://api.anthropic.com/v1/messages",
        bodies,
        [Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION, Fixtures::Responses::MESSAGE_BASIC]
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      runner.add_tools(v011_tool("extra"))
      runner.compact_before_next_turn
      runner.next_message

      compaction_body = JSON.parse(bodies[0])
      compaction_body["messages"].as_a.size.should eq(1)
      compaction_body["messages"][0]["role"].as_s.should eq("user")

      runner.next_message
      followup = JSON.parse(bodies[1])
      followup.as_h.has_key?("compaction").should be_false
      system = followup["messages"][-1]
      system["role"].as_s.should eq("system")
      system["content"][0]["type"].as_s.should eq("tool_addition")
    end

    it "runs pending compaction inside the streaming loop" do
      bodies = [] of String
      tool_use_sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_s1","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_s1","name":"test","input":{}}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":10}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      plain_sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_s2","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done"}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      queue = [tool_use_sse, Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION, plain_sse]

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        bodies << request.body.to_s
        body = queue.shift
        if body.starts_with?("event:")
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new(body)
          )
        else
          HTTP::Client::Response.new(200, body: body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [v011_tool("test")] of Anthropic::Tool
      )

      compacted = false
      runner.each_streaming do |event|
        if event.is_a?(Anthropic::MessageStartEvent) && !compacted
          compacted = true
          runner.compact_before_next_turn
        end
      end

      bodies.size.should eq(3)
      JSON.parse(bodies[0]).as_h.has_key?("compaction").should be_false
      JSON.parse(bodies[1])["compaction"]["type"].as_s.should eq("summarize")
      followup = JSON.parse(bodies[2])
      followup.as_h.has_key?("compaction").should be_false
      followup["messages"].as_a.size.should eq(1)
    end
  end

  describe "forward-compatible fallbacks" do
    it "preserves unknown tool-change types" do
      block = Anthropic::CompactionContent.from_json(
        %({"type":"compaction","content":"s","tool_changes":[{"type":"tool_pause","reason":"idle"}]})
      )
      generic = block.tool_changes.not_nil!.first.as(Anthropic::GenericToolChange)
      generic.type.should eq("tool_pause")
      generic.raw["reason"].as_s.should eq("idle")
      generic.to_json.should eq(%({"type":"tool_pause","reason":"idle"}))
    end

    it "preserves unknown input-transformation types" do
      message = Anthropic::Message.from_json(
        %({"id":"m","type":"message","role":"assistant","content":[],"model":"c","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1},"input_transformations":[{"type":"thinking_rewritten","path":"p"}]})
      )
      generic = message.input_transformations.not_nil!.first.as(Anthropic::GenericInputTransformation)
      generic.type.should eq("thinking_rewritten")
      generic.raw["path"].as_s.should eq("p")
    end

    it "preserves unknown rate-limit group types" do
      limits = %({"data":[{"id":"rl_9","group":{"id":"g_9","type":"future_group"},"group_type":"sessions","limits":{},"models":null,"type":"rate_limit"}],"next_page":null})
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rate_limits?beta=true&limit=20", limits)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      listed = client.beta.organization.rate_limits.list
      generic = listed.data.first.group.as(Anthropic::BetaOrganizationRateLimitGenericGroup)
      generic.type.should eq("future_group")
      generic.raw["id"].as_s.should eq("g_9")
    end

    it "treats explicit-null discriminators as unknown, not crashes" do
      block = Anthropic::CompactionContent.from_json(
        %({"type":"compaction","content":"s","tool_changes":[{"type":null}]})
      )
      block.tool_changes.not_nil!.first.as(Anthropic::GenericToolChange).type.should eq("unknown")
    end

    it "rejects by-value definitions on removal blocks" do
      expect_raises(JSON::ParseException, /not valid in a tool_removal block/) do
        Anthropic::ToolRemovalContent.from_json(
          %({"type":"tool_removal","tool":{"type":"tool_definition","definition":{"name":"x","input_schema":{}}}})
        )
      end
    end

    it "keeps cache_control-bearing definitions as raw JSON" do
      reference = Anthropic::ToolChangeToolDefinition.from_json(
        %({"type":"tool_definition","definition":{"name":"x","input_schema":{},"cache_control":{"type":"ephemeral"}}})
      )
      reference.definition.as(JSON::Any)["cache_control"]["type"].as_s.should eq("ephemeral")
    end
  end

  describe "converter null and unknown-type handling" do
    it "parses explicit-null tool changes as nil" do
      block = Anthropic::CompactionContent.from_json(
        %({"type":"compaction","content":"s","tool_changes":null})
      )
      block.tool_changes.should be_nil
    end

    it "parses explicit-null input transformations as nil" do
      message = Anthropic::Message.from_json(
        %({"id":"m","type":"message","role":"assistant","content":[],"model":"c","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1},"input_transformations":null})
      )
      message.input_transformations.should be_nil
    end

    it "parses explicit-null checkout as nil" do
      resource = Anthropic::BetaSessionGitHubRepositoryResource.from_json(
        %({"id":"res_1","created_at":"","mount_path":"/repo","updated_at":"","url":"https://github.com/o/r","checkout":null})
      )
      resource.checkout.should be_nil
    end

    it "raises on unknown checkout types" do
      expect_raises(JSON::ParseException, /Unknown checkout type/) do
        Anthropic::BetaManagedAgentsCheckoutConverter.from_json(
          JSON::PullParser.new(%({"type":"tag","name":"v1"}))
        )
      end
    end

    it "raises on unknown work data types" do
      expect_raises(JSON::ParseException, /Unknown work data type/) do
        Anthropic::BetaSelfHostedWorkDataConverter.from_json(
          JSON::PullParser.new(%({"id":"w","type":"future"}))
        )
      end
    end
  end

  describe "compaction delta key presence" do
    it "tracks encrypted_content presence through parsing" do
      present = Anthropic::CompactionDelta.from_json(%({"type":"compaction_delta","content":"s","encrypted_content":"B"}))
      present.encrypted_content_present?.should be_true

      absent = Anthropic::CompactionDelta.from_json(%({"type":"compaction_delta","content":"s"}))
      absent.encrypted_content_present?.should be_false

      null_valued = Anthropic::CompactionDelta.from_json(%({"type":"compaction_delta","content":"s","encrypted_content":null}))
      null_valued.encrypted_content_present?.should be_true
      null_valued.encrypted_content.should be_nil
    end

    it "keeps encrypted_content across deltas that omit the key" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_e1","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"compaction"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","encrypted_content":"BLOB"}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"final summary"}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      v011_sse_capture("https://api.anthropic.com/v1/messages", sse)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      final = nil
      client.beta.messages.open_stream(
        model: "claude-opus-5-5",
        max_tokens: 64,
        messages: [{role: "user", content: "hi"}]
      ) do |stream|
        stream.each { |_| }
        final = stream.final_message
      end

      block = final.not_nil!.content.first.as(Anthropic::CompactionContent)
      block.content.should eq("final summary")
      block.encrypted_content.should eq("BLOB")
    end
  end
end
