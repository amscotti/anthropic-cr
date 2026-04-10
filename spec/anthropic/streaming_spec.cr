require "../spec_helper"

private def sse_event(event_type : String, data : String) : String
  sse_event(event_type, [data])
end

private def sse_event(event_type : String, data_lines : Array(String)) : String
  (["event: #{event_type}"] + data_lines.map { |line| "data: #{line}" }).join("\n")
end

private def sse_response(body : String) : HTTP::Client::Response
  HTTP::Client::Response.new(
    200,
    headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
    body_io: IO::Memory.new(body)
  )
end

describe "Streaming Events" do
  describe "event parsing" do
    it "parses message_start event" do
      json = %({"type":"message_start","message":{"id":"msg_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})

      event = Anthropic::MessageStartEvent.from_json(json)
      event.type.should eq("message_start")
      event.message.id.should eq("msg_01")
    end

    it "parses content_block_start event" do
      json = %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})

      event = Anthropic::ContentBlockStartEvent.from_json(json)
      event.type.should eq("content_block_start")
      event.index.should eq(0)
    end

    it "parses content_block_delta event with text" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}})

      event = Anthropic::ContentBlockDeltaEvent.from_json(json)
      event.index.should eq(0)
      event.text.should eq("Hello")
    end

    it "parses content_block_delta event with thinking" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me think..."}})

      event = Anthropic::ContentBlockDeltaEvent.from_json(json)
      event.thinking.should eq("Let me think...")
    end

    it "parses content_block_delta event with input_json" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"loc"}})

      event = Anthropic::ContentBlockDeltaEvent.from_json(json)
      event.partial_json.should eq("{\"loc")
    end

    it "parses content_block_stop event" do
      json = %({"type":"content_block_stop","index":0})

      event = Anthropic::ContentBlockStopEvent.from_json(json)
      event.type.should eq("content_block_stop")
      event.index.should eq(0)
    end

    it "parses message_delta event" do
      json = %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}})

      event = Anthropic::MessageDeltaEvent.from_json(json)
      event.delta.stop_reason.should eq("end_turn")
      event.usage.not_nil!.output_tokens.should eq(15)
    end

    it "parses message_delta refusal stop details" do
      json = %({"type":"message_delta","delta":{"stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber","explanation":"This request would meaningfully facilitate cyber abuse."},"stop_sequence":null},"usage":{"output_tokens":15}})

      event = Anthropic::MessageDeltaEvent.from_json(json)
      event.delta.stop_reason.should eq("refusal")
      event.delta.stop_details.should_not be_nil
      event.delta.stop_details.not_nil!.category.should eq("cyber")
    end

    it "parses message_stop event" do
      json = %({"type":"message_stop"})

      event = Anthropic::MessageStopEvent.from_json(json)
      event.type.should eq("message_stop")
    end

    it "parses ping event" do
      json = %({"type":"ping"})

      event = Anthropic::PingEvent.from_json(json)
      event.type.should eq("ping")
    end
  end
end

describe Anthropic::ContentBlockDeltaEvent do
  describe "#text" do
    it "returns text for text_delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello world"}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.text.should eq("Hello world")
    end

    it "returns nil for non-text delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.text.should be_nil
    end
  end

  describe "#thinking" do
    it "returns thinking for thinking_delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Processing..."}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.thinking.should eq("Processing...")
    end

    it "returns nil for non-thinking delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.thinking.should be_nil
    end
  end

  describe "#partial_json" do
    it "returns json for input_json_delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"key\\":"}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.partial_json.should eq("{\"key\":")
    end

    it "returns nil for non-json delta" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}})
      event = Anthropic::ContentBlockDeltaEvent.from_json(json)

      event.partial_json.should be_nil
    end
  end
end

describe Anthropic::MessageStream do
  describe "wire parsing" do
    it "parses an SSE stream and collects text" do
      body = [
        sse_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
        sse_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}})),
        sse_event("content_block_stop", %({"type":"content_block_stop","index":0})),
        sse_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}})),
        sse_event("message_stop", %({"type":"message_stop"})),
      ].join("\n\n")

      stream = Anthropic::MessageStream.new(sse_response(body))
      events = stream.to_a

      events.size.should eq(7)
      events[0].should be_a(Anthropic::MessageStartEvent)
      events[2].as(Anthropic::ContentBlockDeltaEvent).text.should eq("Hello")

      Anthropic::MessageStream.new(sse_response(body)).collect_text.should eq("Hello world")
    end

    it "parses multiline data payloads as one event" do
      body = [
        sse_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_02","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
        sse_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})),
        sse_event("content_block_delta", [
          %({"type":"content_block_delta","index":0,),
          %("delta":{"type":"text_delta","text":"Hello multiline"}}),
        ]),
        sse_event("content_block_stop", %({"type":"content_block_stop","index":0})),
      ].join("\n\n")

      stream = Anthropic::MessageStream.new(sse_response(body))
      stream.collect_text.should eq("Hello multiline")
    end
  end

  describe "#final_message" do
    it "reconstructs text content and final usage from deltas" do
      body = [
        sse_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_03","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
        sse_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}})),
        sse_event("content_block_stop", %({"type":"content_block_stop","index":0})),
        sse_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}})),
        sse_event("message_stop", %({"type":"message_stop"})),
      ].join("\n\n")

      message = Anthropic::MessageStream.new(sse_response(body)).final_message

      message.should_not be_nil
      message = message.not_nil!
      message.text.should eq("Hello world")
      message.stop_reason.should eq("end_turn")
      message.usage.output_tokens.should eq(15)
    end

    it "reconstructs refusal stop details from message deltas" do
      body = [
        sse_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_03b","type":"message","role":"assistant","content":[{"type":"text","text":"I can\u2019t help with that."}],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
        sse_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber","explanation":"This request would meaningfully facilitate cyber abuse."},"stop_sequence":null},"usage":{"output_tokens":15}})),
        sse_event("message_stop", %({"type":"message_stop"})),
      ].join("\n\n")

      message = Anthropic::MessageStream.new(sse_response(body)).final_message

      message.should_not be_nil
      message = message.not_nil!
      message.stop_reason.should eq("refusal")
      message.stop_details.should_not be_nil
      message.stop_details.not_nil!.category.should eq("cyber")
    end
  end

  describe "#tool_use_deltas" do
    it "tracks tool names by block index" do
      body = [
        sse_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_04","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
        sse_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01","name":"first_tool","input":{}}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"fragment-a"}})),
        sse_event("content_block_stop", %({"type":"content_block_stop","index":0})),
        sse_event("content_block_start", %({"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_02","name":"second_tool","input":{}}})),
        sse_event("content_block_delta", %({"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"fragment-b"}})),
        sse_event("content_block_stop", %({"type":"content_block_stop","index":1})),
      ].join("\n\n")

      deltas = Anthropic::MessageStream.new(sse_response(body)).tool_use_deltas.to_a

      deltas.size.should eq(2)
      deltas[0][:name].should eq("first_tool")
      deltas[1][:name].should eq("second_tool")
    end
  end
end
