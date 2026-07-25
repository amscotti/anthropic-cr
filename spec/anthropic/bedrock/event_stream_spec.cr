require "../../spec_helper"

describe Anthropic::Bedrock::EventStream do
  describe ".encode_message / Decoder" do
    it "round-trips a chunk event into SSE" do
      inner = %({"type":"message_stop"})
      frame = Anthropic::Bedrock::EventStream.encode_chunk_event(inner)

      sse = Anthropic::Bedrock::EventStream.to_sse(frame)
      sse.should eq("event: message_stop\ndata: #{inner}\n\n")
    end

    it "decodes multiple frames and preserves order" do
      e1 = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"ping"}))
      e2 = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"message_stop"}))
      combined = Bytes.new(e1.size + e2.size)
      e1.copy_to(combined)
      e2.copy_to(combined + e1.size)

      sse = Anthropic::Bedrock::EventStream.to_sse(combined)
      sse.should contain("event: ping\n")
      sse.should contain("event: message_stop\n")
      sse.index!("event: ping").should be < sse.index!("event: message_stop")
    end

    it "decodes incrementally across chunk boundaries" do
      frame = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"message_stop"}))
      decoder = Anthropic::Bedrock::EventStream::Decoder.new
      parts = [] of String

      # Feed one byte at a time
      frame.each_with_index do |byte, _i|
        decoder.feed(Bytes[byte]) { |sse| parts << sse }
      end

      parts.size.should eq(1)
      parts[0].should eq("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n")
    end

    it "emits SSE error events for exception frames" do
      frame = Anthropic::Bedrock::EventStream.encode_exception(
        "validationException",
        %({"message":"bad request"})
      )
      sse = Anthropic::Bedrock::EventStream.to_sse(frame)
      sse.should start_with("event: error\n")
      data_line = sse.lines.find!(&.starts_with?("data: "))
      payload = JSON.parse(data_line[6..])
      payload["type"].as_s.should eq("error")
      payload["error"]["type"].as_s.should eq("validationException")
      payload["error"]["message"].as_s.should contain("bad request")
    end

    it "emits SSE error events for unmodeled error frames" do
      frame = Anthropic::Bedrock::EventStream.encode_error("InternalError", "boom")
      sse = Anthropic::Bedrock::EventStream.to_sse(frame)
      payload = JSON.parse(sse.lines.find!(&.starts_with?("data: "))[6..])
      payload["error"]["type"].as_s.should eq("InternalError")
      payload["error"]["message"].as_s.should eq("boom")
    end

    it "rejects frames with bad prelude CRC" do
      frame = Anthropic::Bedrock::EventStream.encode_chunk_event(%({"type":"ping"}))
      corrupted = frame.dup
      # Flip a byte inside the prelude CRC field (bytes 8-11)
      corrupted[8] = corrupted[8] ^ 0xFF

      expect_raises(Anthropic::Bedrock::EventStream::DecodeError, /prelude CRC/) do
        Anthropic::Bedrock::EventStream.to_sse(corrupted)
      end
    end

    it "detects AWS event-stream content types" do
      Anthropic::Bedrock::EventStream.eventstream?("application/vnd.amazon.eventstream").should be_true
      Anthropic::Bedrock::EventStream.eventstream?("application/vnd.amazon.eventstream; charset=utf-8").should be_true
      Anthropic::Bedrock::EventStream.eventstream?("text/event-stream").should be_false
      Anthropic::Bedrock::EventStream.eventstream?(nil).should be_false
    end
  end
end
