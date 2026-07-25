require "../spec_helper"

describe Anthropic::Sessions do
  describe ".accumulate_managed_agents_event" do
    it "opens a fresh snapshot on event_start with agent.message" do
      event = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(nil, event)

      snapshot.should_not be_nil
      snap = snapshot.not_nil!
      snap["type"].to_s.should eq("agent.message")
      snap["id"].to_s.should eq("evt_1")
      snap["content"].as_a.should be_empty
    end

    it "returns accumulated unchanged for non-agent.message event_start previews" do
      event = JSON.parse(%({"type":"event_start","event":{"id":"evt_2","type":"agent.thinking"}}))
      existing = JSON.parse(%({"type":"agent.message","content":[]}))
      result = Anthropic::Sessions.accumulate_managed_agents_event(existing, event)
      result.should eq(existing)
    end

    it "returns nil for a stray event_delta with no prior event_start" do
      event = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"hi","type":"text"},"type":"content_delta","index":0}}))
      result = Anthropic::Sessions.accumulate_managed_agents_event(nil, event)
      result.should be_nil
    end

    it "folds a text fragment into the snapshot at index 0" do
      start_event = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(nil, start_event).not_nil!

      delta = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"Hello","type":"text"},"type":"content_delta","index":0}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, delta).not_nil!

      snapshot["content"].as_a.size.should eq(1)
      snapshot["content"][0]["text"].to_s.should eq("Hello")
    end

    it "appends successive fragments to the same text block" do
      start_event = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(nil, start_event).not_nil!

      d1 = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"foo","type":"text"},"type":"content_delta","index":0}}))
      d2 = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"bar","type":"text"},"type":"content_delta","index":0}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, d1).not_nil!
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, d2).not_nil!

      snapshot["content"][0]["text"].to_s.should eq("foobar")
    end

    it "creates a new content block when the index advances" do
      start_event = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(nil, start_event).not_nil!

      d0 = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"a","type":"text"},"type":"content_delta","index":0}}))
      d1 = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"content":{"text":"b","type":"text"},"type":"content_delta","index":1}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, d0).not_nil!
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, d1).not_nil!

      snapshot["content"].as_a.size.should eq(2)
      snapshot["content"][0]["text"].to_s.should eq("a")
      snapshot["content"][1]["text"].to_s.should eq("b")
    end

    it "replaces the preview when the buffered agent.message final arrives" do
      start_event = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(nil, start_event).not_nil!

      final = JSON.parse(%({"type":"agent.message","id":"evt_1","content":[{"type":"text","text":"final"}],"processed_at":"2026-07-01T00:00:00Z"}))
      snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, final).not_nil!

      snapshot["type"].to_s.should eq("agent.message")
      snapshot["content"][0]["text"].to_s.should eq("final")
      snapshot["processed_at"].to_s.should eq("2026-07-01T00:00:00Z")
    end

    it "is a no-op for unrelated event types" do
      existing = JSON.parse(%({"type":"agent.message","content":[]}))
      event = JSON.parse(%({"type":"session.status_idle"}))
      result = Anthropic::Sessions.accumulate_managed_agents_event(existing, event)
      result.should eq(existing)
    end
  end

  describe "DeltaType constants" do
    it "exposes the event_deltas vocabulary" do
      Anthropic::Sessions::DeltaType::AGENT_MESSAGE.should eq("agent.message")
      Anthropic::Sessions::DeltaType::AGENT_THINKING.should eq("agent.thinking")
    end
  end
end

describe Anthropic::SessionEventStream do
  it "yields each SSE data payload as JSON::Any" do
    body = "event: session.status_idle\ndata: {\"type\":\"session.status_idle\",\"stop_reason\":{\"type\":\"end_turn\"}}\n\nevent: agent.message\ndata: {\"type\":\"agent.message\",\"id\":\"evt_1\",\"content\":[{\"type\":\"text\",\"text\":\"hi\"}]}\n\n"
    response = HTTP::Client::Response.new(
      200,
      headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
      body_io: IO::Memory.new(body),
    )

    events = [] of JSON::Any
    Anthropic::SessionEventStream.new(response).each { |event| events << event }

    events.size.should eq(2)
    events[0]["type"].to_s.should eq("session.status_idle")
    events[1]["type"].to_s.should eq("agent.message")
    events[1]["content"][0]["text"].to_s.should eq("hi")
  end

  it "ignores the [DONE] sentinel" do
    body = "data: {\"type\":\"ping\"}\n\ndata: [DONE]\n\n"
    response = HTTP::Client::Response.new(
      200,
      headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
      body_io: IO::Memory.new(body),
    )

    events = [] of JSON::Any
    Anthropic::SessionEventStream.new(response).each { |event| events << event }

    events.size.should eq(1)
    events[0]["type"].to_s.should eq("ping")
  end
end

describe "BetaSessionEvents#stream (end-to-end call)" do
  it "yields each session event as JSON::Any through the resource method" do
    body = "event: event_start\ndata: {\"type\":\"event_start\",\"event\":{\"id\":\"evt_1\",\"type\":\"agent.message\"}}\n\nevent: event_delta\ndata: {\"type\":\"event_delta\",\"event_id\":\"evt_1\",\"delta\":{\"content\":{\"text\":\"hi\",\"type\":\"text\"},\"type\":\"content_delta\",\"index\":0}}\n\n"
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream?beta=true&event_deltas=agent.message")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    events = [] of JSON::Any
    client.beta.sessions.events.stream("sess_1", event_deltas: [Anthropic::Sessions::DeltaType::AGENT_MESSAGE]) do |event|
      events << event
    end

    events.size.should eq(2)
    events[0]["type"].to_s.should eq("event_start")
    events[1]["type"].to_s.should eq("event_delta")

    # Fold the preview via the accumulate helper (exercising the full flow).
    snapshot = nil.as(JSON::Any?)
    events.each { |event| snapshot = Anthropic::Sessions.accumulate_managed_agents_event(snapshot, event) }
    snapshot.not_nil!["content"][0]["text"].to_s.should eq("hi")
  end

  it "streams thread events as JSON::Any" do
    body = "event: agent.message\ndata: {\"type\":\"agent.message\",\"id\":\"evt_9\",\"content\":[]}\n\n"
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/threads/thread_1/stream?beta=true")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    events = [] of JSON::Any
    client.beta.sessions.threads.events.stream("sess_1", "thread_1") { |event| events << event }

    events.size.should eq(1)
    events[0]["id"].to_s.should eq("evt_9")
  end

  it "passes event_deltas as repeated query params on thread stream" do
    body = "event: event_start\ndata: {\"type\":\"event_start\",\"event\":{\"id\":\"evt_t\",\"type\":\"agent.message\"}}\n\n"
    WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/threads/thread_1/stream?beta=true&event_deltas=agent.message")
      .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    events = [] of JSON::Any
    client.beta.sessions.threads.events.stream(
      "sess_1",
      "thread_1",
      event_deltas: [Anthropic::Sessions::DeltaType::AGENT_MESSAGE],
    ) { |event| events << event }

    events.size.should eq(1)
    events[0]["type"].to_s.should eq("event_start")
  end
end
