require "../spec_helper"

struct V012StructuredCity
  include JSON::Serializable
  getter city : String
end

struct V012MacroToolInput
  include JSON::Serializable

  @[JSON::Field(description: "Search term")]
  getter query : String
end

class V012NoThreadsClient < Anthropic::Client
  def supports_message_threads? : Bool
    false
  end
end

describe "v0.12.0 Messages, Threads, Toolsets & Runner Parity" do
  describe "1. Sampling param and CompactionConfig removals" do
    it "removes temperature, top_p, and top_k from MessageCreateParams and BetaMessageCreateParams" do
      ({{ Anthropic::MessageCreateParams.methods.any? { |method| method.name == "temperature" || method.name == "top_p" || method.name == "top_k" } }}).should be_false
      ({{ Anthropic::BetaMessageCreateParams.methods.any? { |method| method.name == "temperature" || method.name == "top_p" || method.name == "top_k" } }}).should be_false
      ({{ Anthropic::BatchRequestParams.methods.any? { |method| method.name == "temperature" || method.name == "top_p" || method.name == "top_k" } }}).should be_false
      ({{ Anthropic::BetaBatchRequestParams.methods.any? { |method| method.name == "temperature" || method.name == "top_p" || method.name == "top_k" } }}).should be_false
    end

    it "removes client-side CompactionConfig while keeping SummarizeCompaction" do
      ({{ Anthropic.constants.any? { |const_name| const_name.stringify == "CompactionConfig" } }}).should be_false
      ({{ Anthropic.constants.any? { |const_name| const_name.stringify == "SummarizeCompaction" } }}).should be_true
    end
  end

  describe "2. GA speed, CacheMissReason nilable tokens, and ThinkingConfig.between_tools" do
    it "sends speed on GA create, parse, stream, count_tokens, and BatchRequestParams without beta headers" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        speed: "fast",
        messages: [{role: "user", content: "Hello"}]
      )

      body = JSON.parse(capture.body.not_nil!)
      body["speed"].as_s.should eq("fast")
      capture.headers.not_nil!["anthropic-beta"]?.should be_nil

      count_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/count_tokens", Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)
      client.messages.count_tokens(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        speed: "standard",
        messages: [{role: "user", content: "Hello"}]
      )
      JSON.parse(count_capture.body.not_nil!)["speed"].as_s.should eq("standard")

      batch_params = Anthropic::BatchRequestParams.new(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("Hi")],
        speed: "fast"
      )
      JSON.parse(batch_params.to_json)["speed"].as_s.should eq("fast")
    end

    it "parses CacheMissReason with nil, missing, or numeric cache_missed_input_tokens" do
      missing = Anthropic::CacheMissReason.from_json(%({"type":"unavailable"}))
      missing.type.should eq("unavailable")
      missing.cache_missed_input_tokens.should be_nil

      explicit_null = Anthropic::CacheMissReason.from_json(%({"type":"model_changed","cache_missed_input_tokens":null}))
      explicit_null.cache_missed_input_tokens.should be_nil

      numeric = Anthropic::CacheMissReason.from_json(%({"type":"tools_changed","cache_missed_input_tokens":512}))
      numeric.cache_missed_input_tokens.should eq(512)
    end

    it "supports ThinkingConfig.between_tools across GA, Beta, and FallbackParam" do
      thinking = Anthropic::ThinkingConfig.between_tools
      thinking.type.should eq("between_tools")
      thinking.to_json.should eq(%({"type":"between_tools"}))

      round_tripped = Anthropic::ThinkingConfig.from_json(thinking.to_json)
      round_tripped.type.should eq("between_tools")

      fallback = Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_SONNET_4_6, thinking: thinking)
      JSON.parse(fallback.to_json)["thinking"]["type"].as_s.should eq("between_tools")

      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 256,
        thinking: thinking,
        messages: [{role: "user", content: "Think between tools"}]
      )
      JSON.parse(capture.body.not_nil!)["thinking"]["type"].as_s.should eq("between_tools")
    end
  end

  describe "3. MessageParam system role enhancements" do
    it "supports directive-only system messages with clear_at and output_config" do
      msg = Anthropic::MessageParam.system(
        clear_at: "next_user_message",
        output_config: Anthropic::BetaSystemMessageOutputConfig.new(effort: "high")
      )

      json = JSON.parse(msg.to_json)
      json["role"].as_s.should eq("system")
      json["clear_at"].as_s.should eq("next_user_message")
      json["output_config"]["effort"].as_s.should eq("high")
      json.as_h.has_key?("content").should be_false

      parsed = Anthropic::MessageParam.from_json(msg.to_json)
      parsed.role.should eq("system")
      parsed.content.should be_nil
      parsed.clear_at.should eq("next_user_message")
      parsed.output_config.not_nil!.effort.should eq("high")
    end

    it "supports empty output_config hash on system messages with content" do
      msg = Anthropic::MessageParam.system(
        content: "Keep answers short.",
        clear_at: "never",
        output_config: Anthropic::BetaSystemMessageOutputConfig.new
      )
      json = JSON.parse(msg.to_json)
      json["content"].as_s.should eq("Keep answers short.")
      json["clear_at"].as_s.should eq("never")
      json["output_config"].as_h.should be_empty
    end
  end

  describe "4. Browser and Computer toolsets wire types" do
    it "serializes BrowserToolset20260801 and ComputerToolset20260801 with member configs and emits helper headers without beta headers" do
      browser = Anthropic::BrowserToolset20260801.new(
        configs: Anthropic::BrowserToolsetConfigs.new(
          navigate: Anthropic::ToolsetMemberConfig.new(enabled: true, defer_loading: false),
          javascript_exec: Anthropic::ToolsetMemberConfig.new(enabled: false),
          zoom: Anthropic::ToolsetMemberConfig.new(enabled: true, defer_loading: true)
        ),
        cache_control: Anthropic::CacheControl.ephemeral
      )
      computer = Anthropic::ComputerToolset20260801.new(
        configs: Anthropic::ComputerToolsetConfigs.new(
          screenshot: Anthropic::ToolsetMemberConfig.new(enabled: true),
          hold_key: Anthropic::ToolsetMemberConfig.new(defer_loading: true)
        )
      )

      browser_json = JSON.parse(browser.to_json)
      browser_json["type"].as_s.should eq("browser_toolset_20260801")
      browser_json["configs"]["navigate"]["enabled"].as_bool.should be_true
      browser_json["configs"]["javascript_exec"]["enabled"].as_bool.should be_false
      browser_json["cache_control"]["type"].as_s.should eq("ephemeral")

      computer_json = JSON.parse(computer.to_json)
      computer_json["type"].as_s.should eq("computer_toolset_20260801")
      computer_json["configs"]["hold_key"]["defer_loading"].as_bool.should be_true

      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        server_tools: [browser],
        messages: [{role: "user", content: "Open example.com"}]
      )
      capture.headers.not_nil!["anthropic-beta"]?.should be_nil
      capture.headers.not_nil!["x-stainless-helper"].should eq("browser-toolset")

      client.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        server_tools: [browser, computer] of Anthropic::ServerTool,
        messages: [{role: "user", content: "Open example.com"}]
      )

      capture.headers.not_nil!["anthropic-beta"]?.should be_nil
      capture.headers.not_nil!["x-stainless-helper"].should eq("browser-toolset,computer-toolset")
    end

    it "parses typed BrowserToolUse and ComputerToolUse inputs from ToolUseContent" do
      nav_use = Anthropic::ToolUseContent.from_json(
        %({"type":"tool_use","id":"tu_1","name":"navigate","toolset_name":"browser","input":{"url":"https://example.com","tab_id":"t1"}})
      )
      nav_use.toolset_name.should eq("browser")
      Anthropic::BrowserToolUse.browser?(nav_use).should be_true
      parsed_nav = Anthropic::BrowserToolUse.parse(nav_use).as(Anthropic::BrowserNavigateInput)
      parsed_nav.url.should eq("https://example.com")
      parsed_nav.tab_id.should eq("t1")

      click_use = Anthropic::ToolUseContent.from_json(
        %({"type":"tool_use","id":"tu_2","name":"left_click","toolset_name":"browser","input":{"target":{"type":"coordinate","x":120,"y":240},"modifiers":"Shift"}})
      )
      parsed_click = Anthropic::BrowserToolUse.parse(click_use).as(Anthropic::BrowserLeftClickInput)
      coord = parsed_click.target.as(Anthropic::BrowserCoordinateTarget)
      coord.x.should eq(120)
      coord.y.should eq(240)
      parsed_click.modifiers.should eq("Shift")

      form_use = Anthropic::ToolUseContent.from_json(
        %({"type":"tool_use","id":"tu_3","name":"form_input","toolset_name":"browser","input":{"target":{"type":"ref","ref":"input_0"},"value":true}})
      )
      parsed_form = Anthropic::BrowserToolUse.parse(form_use).as(Anthropic::BrowserFormInputInput)
      parsed_form.target.ref.should eq("input_0")
      parsed_form.value.should eq(true)

      scroll_use = Anthropic::ToolUseContent.from_json(
        %({"type":"tool_use","id":"tu_4","name":"scroll","toolset_name":"computer","input":{"scroll_amount":3,"scroll_direction":"down","coordinate":[50,60]}})
      )
      Anthropic::ComputerToolUse.computer?(scroll_use).should be_true
      parsed_scroll = Anthropic::ComputerToolUse.parse(scroll_use).as(Anthropic::ComputerScrollInput)
      parsed_scroll.scroll_amount.should eq(3)
      parsed_scroll.scroll_direction.should eq("down")
      parsed_scroll.coordinate.should eq([50, 60])

      expect_raises(ArgumentError) { Anthropic::ComputerToolUse.parse(nav_use) }
    end

    it "round-trips BrowserStateContent with tabs and all 4 state_changes variants inside ToolResultContent" do
      state = Anthropic::BrowserStateContent.new(
        tabs: [Anthropic::BrowserStateTabEntry.new(tab_id: "t1", title: "Home", url: "https://example.com", active: true)],
        state_changes: [
          Anthropic::BrowserStateChangeTabOpened.new(tab_id: "t2"),
          Anthropic::BrowserStateChangeDownloadStarted.new(download_id: "d1", url: "https://example.com/a.pdf"),
          Anthropic::BrowserStateChangeDownloadCompleted.new(download_id: "d1", url: "https://example.com/a.pdf", path: "/tmp/a.pdf", size_bytes: 2048_i64),
          Anthropic::BrowserStateChangeDownloadFailed.new(download_id: "d2", url: "https://example.com/b.pdf", error: "404"),
        ] of Anthropic::BrowserStateChange,
        cache_control: Anthropic::CacheControl.ephemeral
      )

      tool_result = Anthropic::ToolResultContent.new(
        tool_use_id: "tu_nav",
        content: [state.as(Anthropic::ToolResultBlockContent)],
        toolset_name: "browser"
      )

      msg = Anthropic::MessageParam.new(role: Anthropic::Role::User, content: [tool_result.as(Anthropic::ContentBlock)])
      parsed_msg = Anthropic::MessageParam.from_json(msg.to_json)
      blocks = parsed_msg.content.as(Array(Anthropic::ContentBlock))
      parsed_tr = blocks[0].as(Anthropic::ToolResultContent)
      parsed_tr.toolset_name.should eq("browser")
      tr_blocks = parsed_tr.content.as(Array(Anthropic::ToolResultBlockContent))
      parsed_state = tr_blocks[0].as(Anthropic::BrowserStateContent)
      parsed_state.tabs[0].active.should eq(true)
      changes = parsed_state.state_changes.not_nil!
      changes.size.should eq(4)
      changes[0].as(Anthropic::BrowserStateChangeTabOpened).tab_id.should eq("t2")
      changes[2].as(Anthropic::BrowserStateChangeDownloadCompleted).size_bytes.should eq(2048_i64)
      changes[3].as(Anthropic::BrowserStateChangeDownloadFailed).error.should eq("404")
    end

    it "propagates tool_use.toolset_name onto ToolRunner emitted ToolResultContent" do
      bodies = [] of String
      responses = [
        {
          id: "msg_t1", type: "message", role: "assistant",
          content: [{type: "tool_use", id: "tu_browser_1", name: "navigate", toolset_name: "browser", input: {url: "https://example.com"}}],
          model: "claude-sonnet-4-6", stop_reason: "tool_use", stop_sequence: nil,
          usage: {input_tokens: 10, output_tokens: 5},
        }.to_json,
        Fixtures::Responses::MESSAGE_BASIC,
      ]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        HTTP::Client::Response.new(200, body: responses.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      nav_tool = Anthropic.tool(
        name: "navigate",
        description: "Navigate",
        schema: {"url" => Anthropic::Schema.string("URL")},
        required: ["url"]
      ) { |input| "Navigated to #{input["url"].as_s}" }

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("Go")],
        tools: [nav_tool] of Anthropic::Tool
      )
      runner.final_message

      sent_tr = JSON.parse(bodies[1])["messages"][0]["content"][0]
      sent_tr["toolset_name"].as_s.should eq("browser")
    end
  end

  describe "5. Beta Message Threads" do
    it "auto-attaches MESSAGE_THREADS_BETA on direct BetaMessages#create and BetaBatchRequestParams" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [{role: "user", content: "Hi"}],
        thread: Anthropic::BetaThreadCreateParams.new
      )
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MESSAGE_THREADS_BETA)
      JSON.parse(capture.body.not_nil!)["thread"]["type"].as_s.should eq("create")

      batch_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/batches", {
        id: "batch_1", type: "message_batch", processing_status: "in_progress",
        request_counts: {processing: 1, succeeded: 0, errored: 0, canceled: 0, expired: 0},
        ended_at: nil, created_at: "2026-01-01T00:00:00Z", expires_at: "2026-01-02T00:00:00Z",
        cancel_initiated_at: nil, results_url: nil,
      }.to_json)
      client.beta.messages.batches.create([
        Anthropic::BetaBatchRequest.new(
          custom_id: "c1",
          params: Anthropic::BetaBatchRequestParams.new(
            model: Anthropic::Model::CLAUDE_SONNET_4_6,
            max_tokens: 64,
            messages: [Anthropic::MessageParam.user("Hi")],
            thread: Anthropic::BetaThreadContinueParams.new("msg_prev")
          )
        ),
      ])
      batch_capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MESSAGE_THREADS_BETA)
    end

    it "raises NotImplementedError when client.supports_message_threads? is false" do
      client = V012NoThreadsClient.new(api_key: "sk-ant-test")
      expect_raises(::NotImplementedError) do
        client.beta.messages.thread(
          model: Anthropic::Model::CLAUDE_SONNET_4_6,
          max_tokens: 64
        )
      end
    end

    it "handles create -> continue, omits system/tools on continue, adopts container.id, deduplicates append, and forks cleanly" do
      bodies = [] of String
      headers_list = [] of HTTP::Headers
      responses = [
        {
          id: "msg_100", type: "message", role: "assistant",
          content: [{type: "text", text: "First reply"}],
          model: "claude-sonnet-4-6", stop_reason: "end_turn", stop_sequence: nil,
          container: {id: "cntr_abc", expires_at: "2026-12-01T00:00:00Z"},
          usage: {input_tokens: 10, output_tokens: 5},
        }.to_json,
        {
          id: "msg_200", type: "message", role: "assistant",
          content: [{type: "text", text: "Second reply"}],
          model: "claude-sonnet-4-6", stop_reason: "end_turn", stop_sequence: nil,
          usage: {input_tokens: 5, output_tokens: 5},
        }.to_json,
        Fixtures::Responses::MESSAGE_BASIC,
      ]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        headers_list << req.headers
        HTTP::Client::Response.new(200, body: responses.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      calc_tool = Anthropic.tool(
        name: "add",
        description: "Add",
        schema: {"x" => Anthropic::Schema.number("num")},
        required: ["x"]
      ) { |input| input["x"].as_f.to_s }

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        system: "Be concise.",
        tools: [calc_tool] of Anthropic::Tool,
        messages: [Anthropic::MessageParam.user("Turn 1")]
      )

      r1 = thread.send
      r1.id.should eq("msg_100")
      thread.previous_message_id.should eq("msg_100")
      headers_list[0]["x-stainless-helper"].should contain(Anthropic::StainlessHelper::MESSAGE_THREAD)
      headers_list[0]["anthropic-beta"].should contain(Anthropic::MESSAGE_THREADS_BETA)
      b1 = JSON.parse(bodies[0])
      b1["thread"]["type"].as_s.should eq("create")
      b1["system"].as_s.should eq("Be concise.")
      b1["tools"].as_a.size.should eq(1)

      # Deduplicates repeating the already-committed reply
      thread.append(r1)
      thread.messages.size.should eq(2)

      # Rejects modifying system/tools while Continue
      expect_raises(ArgumentError, /system/) { thread.update(system: "Different") }
      expect_raises(ArgumentError, /tools/) { thread.update(tools: nil) }
      thread.update(speed: "fast")

      r2 = thread.create(Anthropic::MessageParam.user("Turn 2"))
      r2.id.should eq("msg_200")
      thread.previous_message_id.should eq("msg_200")
      b2 = JSON.parse(bodies[1])
      b2["thread"]["type"].as_s.should eq("continue")
      b2["thread"]["previous_message_id"].as_s.should eq("msg_100")
      b2["messages"].as_a.size.should eq(1)
      b2["messages"][0]["content"].as_s.should eq("Turn 2")
      b2.as_h.has_key?("system").should be_false
      b2.as_h.has_key?("tools").should be_false
      b2["container"].as_s.should eq("cntr_abc")
      b2["speed"].as_s.should eq("fast")

      # Fork starts an independent create thread carrying history
      forked = thread.fork
      forked.previous_message_id.should be_nil
      forked.messages.size.should eq(4)
      forked.send("Turn 3 in fork")
      b3 = JSON.parse(bodies[2])
      b3["thread"]["type"].as_s.should eq("create")
      b3["messages"].as_a.size.should eq(5)
      thread.previous_message_id.should eq("msg_200")
    end

    it "recovers from ThreadNotFoundError, ThreadAlreadyContinuedError, ThreadContinueInFlightError stripping old cache_control" do
      bodies = [] of String
      turn1 = {
        id: "msg_1", type: "message", role: "assistant",
        content: [{type: "text", text: "A1"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil, usage: {input_tokens: 1, output_tokens: 1},
      }.to_json
      turn2 = {
        id: "msg_2", type: "message", role: "assistant",
        content: [{type: "text", text: "A2"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil, usage: {input_tokens: 1, output_tokens: 1},
      }.to_json
      turn3 = {
        id: "msg_3", type: "message", role: "assistant",
        content: [{type: "text", text: "A3"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil, usage: {input_tokens: 1, output_tokens: 1},
      }.to_json

      step = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        step += 1
        case step
        when 1
          HTTP::Client::Response.new(200, body: turn1, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 2
          HTTP::Client::Response.new(404, body: %({"type":"error","error":{"type":"not_found_error","message":"Expired","details":{"error_code":"thread_not_found"}}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 3
          HTTP::Client::Response.new(200, body: turn2, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 4
          HTTP::Client::Response.new(400, body: %({"type":"error","error":{"type":"invalid_request_error","message":"Already","details":{"error_code":"thread_already_continued"}}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 5
          HTTP::Client::Response.new(200, body: turn3, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 6
          HTTP::Client::Response.new(400, body: %({"type":"error","error":{"type":"invalid_request_error","message":"In flight","details":{"error_code":"thread_continue_in_flight"}}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        else
          HTTP::Client::Response.new(200, body: turn3, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      cached_block = Anthropic::TextContent.new(text: "Turn 1", cache_control: Anthropic::CacheControl.ephemeral)
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.new(role: Anthropic::Role::User, content: [cached_block.as(Anthropic::ContentBlock)])]
      )
      thread.send

      cached_turn2 = Anthropic::TextContent.new(text: "Turn 2", cache_control: Anthropic::CacheControl.ephemeral)
      r2 = thread.send(Anthropic::MessageParam.new(role: Anthropic::Role::User, content: [cached_turn2.as(Anthropic::ContentBlock)]))
      r2.id.should eq("msg_2")

      replay_b = JSON.parse(bodies[2])
      replay_b["thread"]["type"].as_s.should eq("create")
      replay_b["messages"].as_a.size.should eq(3)
      # Cache control stripped on old history, preserved on new turn
      replay_b["messages"][0]["content"][0].as_h.has_key?("cache_control").should be_false
      replay_b["messages"][2]["content"][0]["cache_control"]["type"].as_s.should eq("ephemeral")

      r3 = thread.send("Turn 3")
      r3.id.should eq("msg_3")
      JSON.parse(bodies[4])["thread"]["type"].as_s.should eq("create")

      r4 = thread.send("Turn 4")
      r4.id.should eq("msg_3")
      JSON.parse(bodies[6])["thread"]["type"].as_s.should eq("create")
    end

    it "resets thread to create on refusal and fallback_message responses, and supports continue_unthreaded" do
      bodies = [] of String
      turn1 = {
        id: "msg_1", type: "message", role: "assistant",
        content: [{type: "text", text: "Ok"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil, usage: {input_tokens: 1, output_tokens: 1},
      }.to_json
      refusal = {
        id: "msg_ref", type: "message", role: "assistant",
        content: [] of JSON::Any, model: "claude-sonnet-4-6",
        stop_reason: "refusal", stop_sequence: nil, usage: {input_tokens: 1, output_tokens: 1},
      }.to_json
      fallback_reply = {
        id: "msg_fb", type: "message", role: "assistant",
        content: [{type: "text", text: "Recovered"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil,
        usage: {
          input_tokens: 1, output_tokens: 1,
          iterations: [{type: "fallback_message", input_tokens: 1, output_tokens: 1, model: "claude-sonnet-4-6"}],
        },
      }.to_json

      step = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        step += 1
        case step
        when 1
          HTTP::Client::Response.new(200, body: turn1, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 2
          HTTP::Client::Response.new(200, body: refusal, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 3
          HTTP::Client::Response.new(200, body: fallback_reply, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 4
          HTTP::Client::Response.new(400, body: %({"type":"error","error":{"type":"invalid_request_error","message":"Unsupported","details":{"error_code":"thread_unsupported_request"}}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        else
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("T1")],
        unsupported_request_behavior: "continue_unthreaded"
      )
      thread.send
      ref_msg = thread.send("Refused prompt")
      ref_msg.stop_reason.should eq("refusal")
      thread.previous_message_id.should be_nil
      thread.messages.size.should eq(2)

      fb_msg = thread.send("After refusal")
      fb_msg.id.should eq("msg_fb")
      JSON.parse(bodies[2])["thread"]["type"].as_s.should eq("create")
      # Fallback response forces next turn to replay with create
      thread.previous_message_id.should be_nil

      # Unsupported request retries without thread when continue_unthreaded
      thread.send("Trigger unthreaded")
      JSON.parse(bodies[4]).as_h.has_key?("thread").should be_false
    end

    it "supports parse and incomplete stream partial recovery on BetaMessageThread" do
      bodies = [] of String
      partial_sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_part","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Half"}}),
      ].join("\n\n")
      structured_json = {
        id: "msg_json", type: "message", role: "assistant",
        content: [{type: "text", text: %({"city":"Tokyo"})}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil, usage: {input_tokens: 5, output_tokens: 5},
      }.to_json

      step = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        step += 1
        if step == 1
          HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "text/event-stream"}, body_io: IO::Memory.new(partial_sse))
        else
          HTTP::Client::Response.new(200, body: structured_json, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      thread = client.beta.messages.thread(model: Anthropic::Model::CLAUDE_SONNET_4_6, max_tokens: 64)

      observed_types = [] of String
      thread.stream("Start") { |event| observed_types << event.type }
      observed_types.should eq(["message_start", "content_block_start", "content_block_delta"])
      thread.previous_message_id.should be_nil
      thread.messages.size.should eq(2)
      thread.messages[1].content.as(Array(Anthropic::ContentBlock))[0].as(Anthropic::TextContent).text.should eq("Half")

      schema = Anthropic.output_schema(type: V012StructuredCity, name: "city")
      parsed = thread.parse("Finish with JSON", output_schema: schema)
      parsed.parsed_output.city.should eq("Tokyo")
      JSON.parse(bodies[1])["thread"]["type"].as_s.should eq("create")
      JSON.parse(bodies[1])["messages"].as_a.size.should eq(3)
    end
  end

  describe "6. ToolRunner threading, sanitization, deep-copy, helpers, and extra tool fields" do
    it "defaults BetaMessages#tool_runner to BetaMessageThread, allows opt-out with thread: false, and rejects invalid thread:" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tool = Anthropic.tool(name: "ping", description: "Ping", schema: {} of String => Anthropic::Schema::Property) { |_| "pong" }

      expect_raises(ArgumentError) do
        client.beta.messages.tool_runner(
          model: Anthropic::Model::CLAUDE_SONNET_4_6,
          max_tokens: 64,
          messages: [Anthropic::MessageParam.user("hi")],
          tools: [tool],
          thread: true
        )
      end

      opted_out = client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [tool],
        thread: false
      )
      opted_out.thread.should be_nil

      no_thread_client = V012NoThreadsClient.new(api_key: "sk-ant-test")
      fallback_runner = no_thread_client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [tool]
      )
      fallback_runner.thread.should be_nil
    end

    it "drives pause_turn resume, deferred compaction, and tool changes over default BetaMessageThread" do
      paused = %({"id":"msg_pause_t1","type":"message","role":"assistant","content":[{"type":"text","text":"partial..."}],"model":"claude-sonnet-4-6","stop_reason":"pause_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":5}})
      bodies = [] of String
      queue = [paused, Fixtures::Responses::MESSAGE_BASIC, Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION, Fixtures::Responses::MESSAGE_BASIC]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        bodies << request.body.to_s
        HTTP::Client::Response.new(200, body: queue.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      ping = Anthropic.tool(name: "ping", description: "Ping", schema: {} of String => Anthropic::Schema::Property) { |_| "pong" }
      extra = Anthropic.tool(name: "extra", description: "Extra", schema: {} of String => Anthropic::Schema::Property) { |_| "ok" }

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        system: "Be brief",
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: [ping]
      )
      runner.thread.should_not be_nil

      runner.next_message
      runner.current_messages.map(&.role).should eq(["user", "assistant"])
      runner.compact_before_next_turn
      runner.add_tools(extra)

      # Paused turn resumes via thread continuation without compaction or tool changes
      runner.next_message
      resume = JSON.parse(bodies[1])
      resume["thread"]["type"].as_s.should eq("continue")
      resume["thread"]["previous_message_id"].as_s.should eq("msg_pause_t1")
      resume["messages"].as_a.should be_empty
      resume.as_h.has_key?("compaction").should be_false
      resume.as_h.has_key?("system").should be_false
      resume.as_h.has_key?("tools").should be_false
      runner.current_messages.map(&.role).should eq(["user", "assistant", "assistant"])

      # Following turn runs deferred compaction before queued tool_addition
      runner.feed_messages([Anthropic::MessageParam.user("next")])
      runner.next_message
      JSON.parse(bodies[2]).as_h.has_key?("compaction").should be_true
    end

    it "preserves Array(TextContent) system prompt across thread.tool_runner, count_tokens, and runner.params" do
      captured_bodies = [] of String
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        captured_bodies << req.body.to_s
        HTTP::Client::Response.new(200, body: Fixtures::Responses::MESSAGE_BASIC, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end
      count_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages/count_tokens", Fixtures::Responses::TOKEN_COUNT_WITH_CACHE)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      sys_blocks = [Anthropic::TextContent.new(text: "Cached sys", cache_control: Anthropic::CacheControl.ephemeral)]
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        system: sys_blocks,
        messages: [Anthropic::MessageParam.user("Hi")]
      )
      runner = thread.tool_runner
      runner.params[:system].should be_a(Array(Anthropic::TextContent))

      runner.next_message
      JSON.parse(captured_bodies[0])["system"][0]["text"].as_s.should eq("Cached sys")

      runner.count_tokens
      JSON.parse(count_capture.body.not_nil!)["system"][0]["text"].as_s.should eq("Cached sys")
    end

    it "omits output_config.format and retains inline-tools beta during compaction_turn with tool-change history" do
      # 1) Threaded runner initialized from a thread with output_schema + effort
      bodies = [] of String
      headers_list = [] of HTTP::Headers
      tool_turn = {
        id: "msg_tu", type: "message", role: "assistant",
        content: [{type: "tool_use", id: "tu_1", name: "ping", input: {} of String => JSON::Any}],
        model: "claude-sonnet-4-6", stop_reason: "tool_use", stop_sequence: nil,
        usage: {input_tokens: 5, output_tokens: 5},
      }.to_json
      queue = [tool_turn, Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION, Fixtures::Responses::MESSAGE_BASIC]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        headers_list << req.headers
        HTTP::Client::Response.new(200, body: queue.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      ping = Anthropic.tool(name: "ping", description: "Ping", schema: {} of String => Anthropic::Schema::Property) { |_| "pong" }
      extra = Anthropic.tool(name: "extra", description: "Extra", schema: {} of String => Anthropic::Schema::Property) { |_| "ok" }
      schema = Anthropic.output_schema(type: V012StructuredCity, name: "city")

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        output_schema: schema,
        effort: "high",
        tools: [ping],
        messages: [Anthropic::MessageParam.user("hi")]
      )
      runner = thread.tool_runner
      runner.add_tools(extra)
      runner.next_message
      runner.compact_before_next_turn
      runner.next_message

      comp_body = JSON.parse(bodies[1])
      comp_body["compaction"]["type"].as_s.should eq("summarize")
      comp_body["output_config"]["effort"].as_s.should eq("high")
      comp_body["output_config"].as_h.has_key?("format").should be_false
      headers_list[1]["anthropic-beta"].should contain(Anthropic::INLINE_TOOLS_2026_09_15_BETA)

      # 2) Unthreaded runner compaction_turn also retains inline-tools beta
      WebMock.reset
      bodies2 = [] of String
      headers2 = [] of HTTP::Headers
      queue2 = [tool_turn, Fixtures::Responses::MESSAGE_WITH_SIGNED_COMPACTION]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies2 << req.body.to_s
        headers2 << req.headers
        HTTP::Client::Response.new(200, body: queue2.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end
      unthreaded = client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("hi")],
        tools: [ping],
        thread: false
      )
      unthreaded.add_tools(extra)
      unthreaded.next_message
      unthreaded.compact_before_next_turn
      unthreaded.next_message
      headers2[1]["anthropic-beta"].should contain(Anthropic::INLINE_TOOLS_2026_09_15_BETA)
    end

    it "preserves non-empty caller-pinned container strings while adopting non-empty container IDs when unset or empty" do
      bodies = [] of String
      reply_with_empty = {
        id: "msg_c1", type: "message", role: "assistant",
        content: [{type: "text", text: "One"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil,
        container: {id: "", expires_at: "2026-12-01T00:00:00Z"},
        usage: {input_tokens: 1, output_tokens: 1},
      }.to_json
      reply_with_server = {
        id: "msg_c2", type: "message", role: "assistant",
        content: [{type: "text", text: "Two"}], model: "claude-sonnet-4-6",
        stop_reason: "end_turn", stop_sequence: nil,
        container: {id: "cntr_server_99", expires_at: "2026-12-01T00:00:00Z"},
        usage: {input_tokens: 1, output_tokens: 1},
      }.to_json

      queue = [reply_with_empty, reply_with_server, Fixtures::Responses::MESSAGE_BASIC]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        HTTP::Client::Response.new(200, body: queue.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      # 1) Pinned string is preserved even when server returns empty or another ID
      pinned = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        container: "cntr_pinned",
        messages: [Anthropic::MessageParam.user("First")]
      )
      pinned.send
      pinned.params[:container].should eq("cntr_pinned")
      pinned.send("Second")
      pinned.params[:container].should eq("cntr_pinned")
      JSON.parse(bodies[1])["container"].as_s.should eq("cntr_pinned")

      # 2) Unset container ignores empty "" and adopts non-empty ID once
      bodies.clear
      queue = [reply_with_empty, reply_with_server, Fixtures::Responses::MESSAGE_BASIC]
      unpinned = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: [Anthropic::MessageParam.user("First")]
      )
      unpinned.send
      unpinned.params[:container].should be_nil
      unpinned.send("Second")
      unpinned.params[:container].should eq("cntr_server_99")
      unpinned.send("Third")
      JSON.parse(bodies[2])["container"].as_s.should eq("cntr_server_99")
    end

    it "sanitizes unpaired UTF-16 surrogate sequences, deep-copies initial messages, and supports push_messages & set_messages_params" do
      bodies = [] of String
      responses = [
        {
          id: "msg_1", type: "message", role: "assistant",
          content: [{type: "tool_use", id: "tu_1", name: "dirty", input: {} of String => JSON::Any}],
          model: "claude-sonnet-4-6", stop_reason: "tool_use", stop_sequence: nil,
          usage: {input_tokens: 5, output_tokens: 5},
        }.to_json,
        Fixtures::Responses::MESSAGE_BASIC,
      ]
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        bodies << req.body.to_s
        HTTP::Client::Response.new(200, body: responses.shift, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      bad_str = "before-" + String.new(Bytes[0xED, 0xA0, 0x80]) + "-after"
      dirty_tool = Anthropic.tool(name: "dirty", description: "Dirty", schema: {} of String => Anthropic::Schema::Property) { |_| bad_str }

      initial = [Anthropic::MessageParam.user("run")]
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64,
        messages: initial,
        tools: [dirty_tool] of Anthropic::Tool
      )
      initial << Anthropic::MessageParam.user("mutated outside")
      runner.params[:messages].size.should eq(1)

      runner.push_messages(Anthropic::MessageParam.user("extra context"))
      runner.set_messages_params(speed: "fast", model: Anthropic::Model::CLAUDE_OPUS_4_6)

      runner.final_message
      JSON.parse(bodies[0])["speed"].as_s.should eq("fast")
      JSON.parse(bodies[0])["model"].as_s.should eq(Anthropic::Model::CLAUDE_OPUS_4_6)
      result_text = JSON.parse(bodies[1])["messages"][0]["content"][0]["content"].as_s
      result_text.valid_encoding?.should be_true
      result_text.should contain("before-")
      result_text.should contain("-after")
      result_text.should contain("\u{FFFD}")
    end

    it "supports extra tool definition fields on InlineTool, TypedTool, and Anthropic.tool" do
      examples = [JSON.parse(%({"query":"crystal"}))]
      inline = Anthropic.tool(
        name: "search",
        description: "Search",
        schema: {"query" => Anthropic::Schema.string("Query")},
        required: ["query"],
        cache_control: Anthropic::CacheControl.ephemeral,
        strict: true,
        defer_loading: true,
        allowed_callers: ["direct"],
        input_examples: examples,
        eager_input_streaming: true
      ) { |input| input["query"].as_s }

      defn = JSON.parse(inline.to_definition.to_json)
      defn["strict"].as_bool.should be_true
      defn["defer_loading"].as_bool.should be_true
      defn["allowed_callers"].as_a.map(&.as_s).should eq(["direct"])
      defn["input_examples"].as_a.size.should eq(1)
      defn["eager_input_streaming"].as_bool.should be_true
      defn["cache_control"]["type"].as_s.should eq("ephemeral")

      typed = Anthropic.tool(
        name: "typed_search",
        description: "Typed search",
        input: V012MacroToolInput,
        strict: true,
        defer_loading: true
      ) { |input| input.query }

      typed_defn = JSON.parse(typed.to_definition.to_json)
      typed_defn["strict"].as_bool.should be_true
      typed_defn["defer_loading"].as_bool.should be_true
    end
  end

  describe "7. Streaming robustness & BetaRefusalFallbackMiddleware" do
    it "passes through unknown SSE events and safely ignores pre-message_start deltas while preserving toolset_name" do
      sse = [
        %(event: future_notice\ndata: {"type":"future_notice","note":"hello"}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"orphan"}}),
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_st","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}}}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"tu_b","name":"navigate","toolset_name":"browser","input":{}}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"url\\":\\"https://a.test\\"}"}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":0}),
        %(event: content_block_start\ndata: {"type":"content_block_start","index":1,"content_block":{"type":"compaction","content":null}}),
        %(event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"compaction_delta","content":null,"encrypted_content":null}}),
        %(event: content_block_stop\ndata: {"type":"content_block_stop","index":1}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":8}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        body_io: IO::Memory.new(sse),
        headers: HTTP::Headers{"Content-Type" => "text/event-stream"}
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      events = [] of Anthropic::AnyStreamEvent
      final : Anthropic::Message? = nil

      client.messages.open_stream(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        messages: [{role: "user", content: "Browse"}]
      ) do |stream|
        stream.each { |event| events << event }
        final = stream.final_message
      end

      unknown = events[0].as(Anthropic::UnknownStreamEvent)
      unknown.type.should eq("future_notice")
      unknown.data["note"].as_s.should eq("hello")

      msg = final.not_nil!
      tu = msg.content[0].as(Anthropic::ToolUseContent)
      tu.toolset_name.should eq("browser")
      tu.input["url"].as_s.should eq("https://a.test")

      comp = msg.content[1].as(Anthropic::CompactionContent)
      comp.content.should be_nil
      comp.encrypted_content.should be_nil
    end

    it "degrades between_tools thinking, preserves system directives in strip_fallback_blocks, and retries once without inherited speed: fast on 429/529" do
      captured_bodies = [] of JSON::Any
      call_num = 0
      refusal = {
        id: "msg_r", type: "message", role: "assistant",
        content: [] of JSON::Any, model: "claude-sonnet-4-6",
        stop_reason: "refusal", stop_sequence: nil,
        usage: {input_tokens: 5, output_tokens: 1},
      }.to_json
      ok_body = Fixtures::Responses::MESSAGE_BASIC

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        call_num += 1
        captured_bodies << JSON.parse(req.body.to_s)
        case call_num
        when 1
          HTTP::Client::Response.new(200, body: refusal, headers: HTTP::Headers{"Content-Type" => "application/json"})
        when 2
          HTTP::Client::Response.new(429, body: %({"type":"error","error":{"type":"rate_limit_error","message":"Slow down"}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        else
          HTTP::Client::Response.new(200, body: ok_body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      mw = Anthropic::BetaRefusalFallbackMiddleware.new([
        Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_6),
      ])
      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0, middleware: [mw])

      result = client.beta.messages.create(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 128,
        speed: "fast",
        thinking: Anthropic::ThinkingConfig.between_tools,
        messages: [
          Anthropic::MessageParam.user("Hello"),
          Anthropic::MessageParam.new(role: Anthropic::Role::Assistant, content: [
            Anthropic::FallbackContent.new(
              from: Anthropic::FallbackInfo.new(model: "old-model"),
              to: Anthropic::FallbackInfo.new(model: "new-model")
            ).as(Anthropic::ContentBlock),
          ]),
          Anthropic::MessageParam.system(
            clear_at: "next_user_message",
            output_config: Anthropic::BetaSystemMessageOutputConfig.new(effort: "high")
          ),
          Anthropic::MessageParam.user("Continue"),
        ]
      )
      result.stop_reason.should eq("end_turn")

      captured_bodies.size.should eq(3)
      # Emptied fallback-only assistant turn dropped, empty system directive preserved
      msgs0 = captured_bodies[0]["messages"].as_a
      msgs0.size.should eq(3)
      msgs0[1]["role"].as_s.should eq("system")
      msgs0[1]["clear_at"].as_s.should eq("next_user_message")

      # Hop 1 inherited speed: fast and degraded between_tools -> disabled
      hop1 = captured_bodies[1]
      hop1["speed"].as_s.should eq("fast")
      hop1["thinking"]["type"].as_s.should eq("disabled")

      # Retried once on 429 without inherited speed: fast
      hop1_retry = captured_bodies[2]
      hop1_retry.as_h.has_key?("speed").should be_false
      hop1_retry["thinking"]["type"].as_s.should eq("disabled")
    end

    it "does not strip speed: fast on 429/529 when fallback entry explicitly sets speed" do
      captured_bodies = [] of JSON::Any
      call_num = 0
      refusal = {
        id: "msg_r", type: "message", role: "assistant",
        content: [] of JSON::Any, model: "claude-sonnet-4-6",
        stop_reason: "refusal", stop_sequence: nil,
        usage: {input_tokens: 5, output_tokens: 1},
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        call_num += 1
        captured_bodies << JSON.parse(req.body.to_s)
        case call_num
        when 1
          HTTP::Client::Response.new(200, body: refusal, headers: HTTP::Headers{"Content-Type" => "application/json"})
        else
          HTTP::Client::Response.new(529, body: %({"type":"error","error":{"type":"overloaded_error","message":"Busy"}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      mw = Anthropic::BetaRefusalFallbackMiddleware.new([
        Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_6, speed: "fast"),
      ])
      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0, middleware: [mw])

      expect_raises(Anthropic::OverloadedError) do
        client.beta.messages.create(
          model: Anthropic::Model::CLAUDE_SONNET_4_6,
          max_tokens: 64,
          messages: [Anthropic::MessageParam.user("Hello")]
        )
      end

      captured_bodies.size.should eq(2)
      captured_bodies[1]["speed"].as_s.should eq("fast")
    end

    it "propagates ThreadUnsupportedRequestError when unsupported_request_behavior is error and sets stream method header on open_stream" do
      sse = [
        %(event: message_start\ndata: {"type":"message_start","message":{"id":"msg_os","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}}}),
        %(event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":2}}),
        %(event: message_stop\ndata: {"type":"message_stop"}),
      ].join("\n\n")
      captured_headers = [] of HTTP::Headers
      step = 0

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |req|
        captured_headers << req.headers
        step += 1
        if step == 1
          HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "text/event-stream"}, body_io: IO::Memory.new(sse))
        else
          HTTP::Client::Response.new(400, body: %({"type":"error","error":{"type":"invalid_request_error","message":"Unsupported","details":{"error_code":"thread_unsupported_request"}}}), headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
      thread = client.beta.messages.thread(
        model: Anthropic::Model::CLAUDE_SONNET_4_6,
        max_tokens: 64
      )

      thread.open_stream("Hello") do |stream|
        stream.each { |_| }
      end
      thread.previous_message_id.should eq("msg_os")
      captured_headers[0]["x-stainless-helper"].should contain(Anthropic::StainlessHelper::MESSAGE_THREAD)
      captured_headers[0]["x-stainless-helper-method"].should eq("stream")

      expect_raises(Anthropic::ThreadUnsupportedRequestError) do
        thread.send("Unsupported next")
      end
    end
  end
end
