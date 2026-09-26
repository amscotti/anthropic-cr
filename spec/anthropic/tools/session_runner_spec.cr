require "../../spec_helper"

private def create_echo_tool : Anthropic::Tool
  Anthropic.tool(
    name: "echo",
    description: "Echoes input",
    schema: {"text" => Anthropic::Schema.string("Text")},
    required: ["text"]
  ) { |input| "echo:#{input["text"]}" }
end

private def create_failing_tool : Anthropic::Tool
  Anthropic.tool(
    name: "boom",
    description: "Always fails",
    schema: {} of String => Anthropic::Schema::Property,
    required: [] of String
  ) { |_| raise "kaput" }
end

private def create_counting_tool(count : Array(Int32)) : Anthropic::Tool
  Anthropic.tool(
    name: "echo",
    description: "Echoes input",
    schema: {"text" => Anthropic::Schema.string("Text")},
    required: ["text"]
  ) { |input| count << 1; "echo:#{input["text"]}" }
end

private def sse_body(*frames : String) : String
  frames.join("\n") + "\n"
end

describe Anthropic::SessionRunner do
  it "executes session tool uses and stops at terminal events" do
    body = [
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_1","name":"echo","input":{"text":"hi"},"processed_at":""}),
      "",
      "event: agent.custom_tool_use",
      %q(data: {"type":"agent.custom_tool_use","id":"ctu_1","name":"echo","input":{"text":"yo"},"processed_at":""}),
      "",
      "event: session.status_terminated",
      %q(data: {"type":"session.status_terminated","id":"evt_end"}),
      "",
    ].join("\n")
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      on_event: ->(event : JSON::Any) { seen << event["type"].as_s; nil }
    )

    terminal = runner.run

    terminal.should_not be_nil
    terminal.not_nil!["type"].as_s.should eq("session.status_terminated")
    seen.should eq(["agent.tool_use", "agent.custom_tool_use", "session.status_terminated"])

    sent.size.should eq(2)
    first = JSON.parse(sent[0])["events"][0]
    first["type"].as_s.should eq("user.tool_result")
    first["tool_use_id"].as_s.should eq("tu_1")
    first["content"][0]["text"].as_s.should eq("echo:hi")
    first["is_error"].as_bool.should be_false

    second = JSON.parse(sent[1])["events"][0]
    second["type"].as_s.should eq("user.custom_tool_result")
    second["custom_tool_use_id"].as_s.should eq("ctu_1")
    second["content"][0]["text"].as_s.should eq("echo:yo")
  end

  it "skips unregistered tools without posting a result" do
    body = [
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_9","name":"missing","input":{},"processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    ].join("\n")
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    calls = [] of Anthropic::SessionRunner::ToolCall
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      on_call: ->(call : Anthropic::SessionRunner::ToolCall) { calls << call; nil }
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
    send_count.should eq(0)
    calls.size.should eq(1)
    calls[0].name.should eq("missing")
    calls[0].executed?.should be_false
    calls[0].posted?.should be_false
  end

  it "answers cross-posted subagent tool uses like any other" do
    body = [
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_x","name":"echo","input":{"text":"hi"},"processed_at":"","session_thread_id":"thread_sub"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    ].join("\n")
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    JSON.parse(sent[0])["events"][0]["tool_use_id"].as_s.should eq("tu_x")
  end

  it "dedupes repeated tool-use event ids" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_dup","name":"echo","input":{"text":"hi"},"processed_at":""}),
      "",
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_dup","name":"echo","input":{"text":"hi"},"processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
  end

  it "honors max_events" do
    body = sse_body(
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_1","content":[]}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_2","content":[]}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_3","content":[]}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_events: 2,
      on_event: ->(event : JSON::Any) { seen << event["id"].as_s; nil }
    )

    runner.run.should be_nil
    seen.should eq(["evt_1", "evt_2"])
  end

  it "ends the run when the live terminal id was already seen" do
    # History already contains the terminal event (e.g. the session was
    # terminated while disconnected); the live replay must still end
    # the run rather than dedupe-skip into an EOF reconnect loop.
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[{"type":"session.deleted","id":"evt_end"}]}))
    body = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_reconnects: 3
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
  end

  it "posts is_error results for failing tools and null input" do
    body = [
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_f","name":"boom","input":null,"processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    ].join("\n")
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    calls = [] of Anthropic::SessionRunner::ToolCall
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_failing_tool] of Anthropic::Tool,
      on_call: ->(call : Anthropic::SessionRunner::ToolCall) { calls << call; nil }
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    result = JSON.parse(sent[0])["events"][0]
    result["is_error"].as_bool.should be_true
    result["content"][0]["text"].as_s.should eq("kaput")
    calls.size.should eq(1)
    calls[0].executed?.should be_true
    calls[0].posted?.should be_true
    calls[0].is_error?.should be_true
  end

  it "skips malformed tool-use events without aborting the run" do
    body = [
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    ].join("\n")
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
  end

  it "holds ask-gated calls until an allow verdict arrives" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_ask","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_ask","result":"allow"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    calls = [] of Anthropic::SessionRunner::ToolCall
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      on_call: ->(call : Anthropic::SessionRunner::ToolCall) { calls << call; nil }
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    JSON.parse(sent[0])["events"][0]["tool_use_id"].as_s.should eq("tu_ask")
    calls.size.should eq(1)
    calls[0].confirmation.should eq("allow")
    calls[0].executed?.should be_true
    calls[0].posted?.should be_true
    calls[0].is_error?.should be_false
  end

  it "resolves denied calls without executing or posting" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_no","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_no","result":"deny"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    calls = [] of Anthropic::SessionRunner::ToolCall
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      on_call: ->(call : Anthropic::SessionRunner::ToolCall) { calls << call; nil }
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
    calls.size.should eq(1)
    calls[0].confirmation.should eq("deny")
    calls[0].executed?.should be_false
    calls[0].posted?.should be_false
  end

  it "lets a server-side deny override a recorded allow verdict" do
    body = sse_body(
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_srv","result":"allow"}),
      "",
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_srv","name":"echo","input":{"text":"hi"},"evaluated_permission":"deny","processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
  end

  it "fails closed on unknown permissions and verdicts" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_odd","name":"echo","input":{"text":"hi"},"evaluated_permission":"maybe","processed_at":""}),
      "",
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_odd","result":"maybe"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
  end

  it "applies a verdict that arrived before the tool use" do
    body = sse_body(
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_early","result":"allow"}),
      "",
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_early","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    JSON.parse(sent[0])["events"][0]["tool_use_id"].as_s.should eq("tu_early")
  end

  it "reconnects after a stream failure and dispatches once" do
    stream_body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_r","name":"echo","input":{"text":"hi"},"processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    attempts = 0
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true").to_return do |_request|
      attempts += 1
      if attempts == 1
        HTTP::Client::Response.new(500, body: "boom")
      else
        HTTP::Client::Response.new(200, body: stream_body, headers: HTTP::Headers{"Content-Type" => "text/event-stream"})
      end
    end
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    attempts.should eq(2)
    sent.size.should eq(1)
  end

  it "raises once max_reconnects is exceeded" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(status: 500, body: "boom")

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_reconnects: 0
    )

    expect_raises(Anthropic::APIConnectionError, /reconnect limit/) do
      runner.run
    end
  end

  it "aborts the run on a permanent 4xx stream failure" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(status: 400, body: %q({"error":{"type":"invalid_request_error","message":"bad"}}))

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_reconnects: 5
    )

    expect_raises(Anthropic::BadRequestError) do
      runner.run
    end
  end

  it "stops the run once max_idle elapses after an end_turn idle" do
    body = sse_body(
      "event: session.status_idle",
      %q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"end_turn"}}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_late","content":[]}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_idle: 0.seconds,
      on_event: ->(event : JSON::Any) { seen << event["type"].as_s; nil }
    )

    runner.run.should be_nil
    seen.should eq(["session.status_idle"])
  end

  it "disarms the idle countdown on intervening activity" do
    body = sse_body(
      "event: session.status_idle",
      %q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"end_turn"}}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_mid","content":[]}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_idle: 60.seconds
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
  end

  it "reconciles unanswered history after connecting" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[{"type":"agent.tool_use","id":"tu_hist","name":"echo","input":{"text":"hi"},"processed_at":""}]}))
    body = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      on_event: ->(event : JSON::Any) { seen << event["type"].as_s; nil }
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    JSON.parse(sent[0])["events"][0]["tool_use_id"].as_s.should eq("tu_hist")
    seen.should eq(["session.deleted"])
  end

  it "skips already-answered history during reconcile" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[
        {"type":"agent.tool_use","id":"tu_done","name":"echo","input":{"text":"hi"},"processed_at":""},
        {"type":"user.tool_result","id":"evt_res","tool_use_id":"tu_done","content":[{"type":"text","text":"echo:hi"}]}
      ]}))
    body = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
  end

  it "aborts the run instead of re-executing when a send fails" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[{"type":"agent.tool_use","id":"tu_send","name":"echo","input":{"text":"hi"},"processed_at":""}]}))
    body = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true")
      .to_return(status: 500, body: "boom")

    client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
    count = [] of Int32
    calls = [] of Anthropic::SessionRunner::ToolCall
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_counting_tool(count)] of Anthropic::Tool,
      max_reconnects: 2,
      on_call: ->(call : Anthropic::SessionRunner::ToolCall) { calls << call; nil }
    )

    expect_raises(Anthropic::InternalServerError) do
      runner.run
    end
    count.size.should eq(1)
    calls.size.should eq(1)
    calls[0].executed?.should be_true
    calls[0].posted?.should be_false
  end

  it "keeps held calls across EOF reconnects until the limit" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_hold","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      max_reconnects: 1
    )

    expect_raises(Anthropic::APIConnectionError, /reconnect limit/) do
      runner.run
    end
    send_count.should eq(0)
  end

  it "reconnects on retryable 4xx stream failures" do
    stream_body = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    attempts = 0
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true").to_return do |_request|
      attempts += 1
      if attempts == 1
        HTTP::Client::Response.new(429, body: %q({"error":{"type":"rate_limit_error","message":"slow"}}))
      else
        HTTP::Client::Response.new(200, body: stream_body, headers: HTTP::Headers{"Content-Type" => "text/event-stream"})
      end
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(client: client, session_id: "sess_1")

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
    attempts.should eq(2)
  end

  it "defers the idle countdown while calls are held" do
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_held","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: session.status_idle",
      %q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"end_turn"}}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_mid","content":[]}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool,
      max_idle: 0.seconds
    )

    # With no hold outstanding, max_idle: 0.seconds would stop at
    # evt_mid; the held call defers the countdown past it.
    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
    send_count.should eq(0)
  end

  it "carries on with the live stream when reconcile fails" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(status: 500, body: "boom")
    body = sse_body(
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_live","name":"echo","input":{"text":"hi"},"processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test", max_retries: 0)
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
  end

  it "treats confirmations as neutral for the idle countdown" do
    body = sse_body(
      "event: session.status_idle",
      %q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"end_turn"}}),
      "",
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_gone","result":"allow"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_idle: 0.seconds
    )

    # A confirmation arriving after expiry does not avoid the stop: it
    # is not activity, and it is not exempt from the countdown check.
    runner.run.should be_nil
  end

  it "disables the idle countdown when max_idle is nil" do
    body = sse_body(
      "event: session.status_idle",
      %q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"end_turn"}}),
      "",
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_mid","content":[]}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_idle: nil
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
  end

  it "denies a held call when the verdict arrived first" do
    body = sse_body(
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"tu_early_deny","result":"deny"}),
      "",
      "event: agent.tool_use",
      %q(data: {"type":"agent.tool_use","id":"tu_early_deny","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    send_count.should eq(0)
  end

  it "gates custom tool calls on confirmation like regular ones" do
    body = sse_body(
      "event: agent.custom_tool_use",
      %q(data: {"type":"agent.custom_tool_use","id":"ctu_g","name":"echo","input":{"text":"hi"},"evaluated_permission":"ask","processed_at":""}),
      "",
      "event: user.tool_confirmation",
      %q(data: {"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"ctu_g","result":"allow"}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    sent = [] of String
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |request|
      sent << request.body.to_s
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    runner.run.should_not be_nil
    sent.size.should eq(1)
    result = JSON.parse(sent[0])["events"][0]
    result["type"].as_s.should eq("user.custom_tool_result")
    result["custom_tool_use_id"].as_s.should eq("ctu_g")
  end

  it "reconnects on a clean EOF and carries on" do
    first = sse_body(
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_1","content":[]}),
      "",
    )
    second = sse_body(
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    attempts = 0
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true").to_return do |_request|
      attempts += 1
      body = attempts == 1 ? first : second
      HTTP::Client::Response.new(200, body: body, headers: HTTP::Headers{"Content-Type" => "text/event-stream"})
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      on_event: ->(event : JSON::Any) { seen << event["type"].as_s; nil }
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
    attempts.should eq(2)
    seen.should eq(["agent.message", "session.deleted"])
  end

  it "ends the run from a terminal already in history" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[
        {"type":"agent.tool_use","id":"tu_dead","name":"echo","input":{"text":"hi"},"processed_at":""},
        {"type":"session.deleted","id":"evt_hist"}
      ]}))
    attempts = 0
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true").to_return do |_request|
      attempts += 1
      HTTP::Client::Response.new(200, body: "", headers: HTTP::Headers{"Content-Type" => "text/event-stream"})
    end
    send_count = 0
    WebMock.stub(:post, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true").to_return do |_request|
      send_count += 1
      HTTP::Client::Response.new(200, body: %({"data":[]}))
    end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      tools: [create_echo_tool] of Anthropic::Tool
    )

    terminal = runner.run
    terminal.not_nil!["id"].as_s.should eq("evt_hist")
    attempts.should eq(0)
    send_count.should eq(0)
  end

  it "re-arms the idle countdown from a trailing history idle" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?beta=true&limit=1000")
      .to_return(body: %q({"data":[{"type":"session.status_idle","id":"evt_h_idle","stop_reason":{"type":"end_turn"}}]}))
    body = sse_body(
      "event: agent.message",
      %q(data: {"type":"agent.message","id":"evt_live","content":[]}),
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_idle: 0.seconds
    )

    # Without the re-arm, evt_live would disarm nothing and the terminal
    # would win; the re-armed countdown stops the run instead.
    runner.run.should be_nil
  end

  it "reconnects when a stream line is not valid JSON" do
    body = sse_body(
      "data: not-json",
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      max_reconnects: 0
    )

    expect_raises(Anthropic::APIConnectionError, /reconnect limit/) do
      runner.run
    end
  end

  it "skips non-object stream payloads" do
    body = sse_body(
      "data: 42",
      "",
      "event: session.deleted",
      %q(data: {"type":"session.deleted","id":"evt_end"}),
      "",
    )
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    seen = [] of String
    runner = Anthropic::SessionRunner.new(
      client: client,
      session_id: "sess_1",
      on_event: ->(event : JSON::Any) { seen << event["type"].as_s; nil }
    )

    terminal = runner.run
    terminal.not_nil!["type"].as_s.should eq("session.deleted")
    seen.should eq(["session.deleted"])
  end
end
