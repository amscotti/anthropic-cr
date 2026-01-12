require "../spec_helper"

describe "Streaming Events" do
  describe "event parsing" do
    it "parses message_start event" do
      json = %({"type":"message_start","message":{"id":"msg_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})

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
