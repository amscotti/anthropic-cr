require "base64"
require "digest/crc32"
require "json"

module Anthropic
  module Bedrock
    # Bedrock's `invoke-with-response-stream` returns
    # `application/vnd.amazon.eventstream` (AWS binary event-stream framing),
    # not SSE. The SDK's `MessageStream` consumer parses SSE only — without
    # this transcoder a Bedrock stream would yield zero events.
    #
    # Each `:message-type: event` frame carries a JSON payload
    # `{"bytes":"<base64>"}` wrapping a standard Anthropic event JSON; this
    # re-emits those as `event:`/`data:` SSE bytes so existing stream helpers
    # work unchanged. Exception frames become SSE `error` events.
    #
    # Wire format (Smithy Amazon Event Stream / botocore):
    #   prelude: total_len(u32 BE) | headers_len(u32 BE) | prelude_crc(u32 BE)
    #   headers + payload
    #   message_crc(u32 BE)
    module EventStream
      extend self

      AWS_CONTENT_TYPE   = "application/vnd.amazon.eventstream"
      PRELUDE_LENGTH     = 12
      MAX_HEADERS_LENGTH = 128 * 1024
      MAX_PAYLOAD_LENGTH = 24 * 1024 * 1024

      # True when the response is AWS event-stream framed (not SSE).
      def eventstream?(content_type : String?) : Bool
        return false unless ct = content_type
        ct.starts_with?(AWS_CONTENT_TYPE) || ct.includes?("amazon.eventstream")
      end

      # Transcode an entire AWS event-stream body into SSE text.
      def to_sse(io : IO) : String
        decoder = Decoder.new
        String.build do |builder|
          buf = Bytes.new(16_384)
          while (n = io.read(buf)) > 0
            decoder.feed(buf[0, n]) do |sse|
              builder << sse
            end
          end
        end
      end

      def to_sse(data : Bytes) : String
        to_sse(IO::Memory.new(data))
      end

      def to_sse(data : String) : String
        to_sse(data.to_slice)
      end

      # --- encoder (tests / tooling) ----------------------------------------

      # Encode a complete AWS event-stream message with string headers.
      def encode_message(headers : Hash(String, String), payload : Bytes | String) : Bytes
        payload_bytes = payload.is_a?(String) ? payload.to_slice : payload
        headers_bytes = encode_headers(headers)
        headers_length = headers_bytes.size
        total_length = headers_length + payload_bytes.size + 16

        prelude = IO::Memory.new
        write_u32(prelude, total_length.to_u32)
        write_u32(prelude, headers_length.to_u32)
        prelude_bytes = prelude.to_slice
        prelude_crc = Digest::CRC32.checksum(prelude_bytes)

        msg = IO::Memory.new
        msg.write(prelude_bytes)
        write_u32(msg, prelude_crc)
        msg.write(headers_bytes)
        msg.write(payload_bytes)

        without_crc = msg.to_slice
        message_crc = Digest::CRC32.checksum(without_crc)
        write_u32(msg, message_crc)
        msg.to_slice
      end

      # Encode a Bedrock "chunk" event wrapping Anthropic SSE event JSON.
      def encode_chunk_event(anthropic_event_json : String) : Bytes
        outer = {"bytes" => Base64.strict_encode(anthropic_event_json)}.to_json
        encode_message(
          {
            ":message-type" => "event",
            ":event-type"   => "chunk",
            ":content-type" => "application/json",
          },
          outer
        )
      end

      # Encode an exception frame (Bedrock model/stream errors).
      def encode_exception(exception_type : String, message : String) : Bytes
        encode_message(
          {
            ":message-type"   => "exception",
            ":exception-type" => exception_type,
            ":content-type"   => "application/json",
          },
          message
        )
      end

      # Encode an unmodeled error frame.
      def encode_error(error_code : String, error_message : String) : Bytes
        encode_message(
          {
            ":message-type"  => "error",
            ":error-code"    => error_code,
            ":error-message" => error_message,
          },
          Bytes.empty
        )
      end

      private def encode_headers(headers : Hash(String, String)) : Bytes
        io = IO::Memory.new
        headers.each do |name, value|
          name_b = name.to_slice
          io.write_byte(name_b.size.to_u8)
          io.write(name_b)
          io.write_byte(7_u8) # string type
          value_b = value.to_slice
          write_u16(io, value_b.size.to_u16)
          io.write(value_b)
        end
        io.to_slice
      end

      private def write_u16(io : IO, value : UInt16) : Nil
        IO::ByteFormat::BigEndian.encode(value, io)
      end

      private def write_u32(io : IO, value : UInt32) : Nil
        IO::ByteFormat::BigEndian.encode(value, io)
      end

      # Incremental decoder: feed raw bytes, yield complete SSE frames.
      class Decoder
        @data = Bytes.empty
        @prelude_total : UInt32? = nil
        @prelude_headers_len : UInt32? = nil
        @prelude_crc : UInt32? = nil

        def feed(chunk : Bytes, & : String ->) : Nil
          append(chunk)
          while sse = next_sse
            yield sse
          end
        end

        private def next_sse : String?
          msg = next_message || return nil
          emit(msg)
        end

        private def next_message : Message?
          if @prelude_total.nil?
            return nil if @data.size < PRELUDE_LENGTH
            total = read_u32(@data, 0)
            headers_len = read_u32(@data, 4)
            prelude_crc = read_u32(@data, 8)

            if headers_len > MAX_HEADERS_LENGTH
              raise DecodeError.new("Event stream headers length #{headers_len} exceeds maximum #{MAX_HEADERS_LENGTH}")
            end

            payload_len = total.to_i64 - headers_len.to_i64 - PRELUDE_LENGTH - 4
            if payload_len < 0 || payload_len > MAX_PAYLOAD_LENGTH
              raise DecodeError.new("Event stream payload length invalid or exceeds maximum")
            end

            computed = Digest::CRC32.checksum(@data[0, 8])
            if computed != prelude_crc
              raise DecodeError.new(
                "Event stream prelude CRC mismatch: expected 0x#{prelude_crc.to_s(16)}, got 0x#{computed.to_s(16)}"
              )
            end

            @prelude_total = total
            @prelude_headers_len = headers_len
            @prelude_crc = prelude_crc
          end

          total = @prelude_total
          headers_len = @prelude_headers_len
          return nil unless total && headers_len
          return nil if @data.size < total

          message_crc = read_u32(@data, (total - 4).to_i)
          computed_msg = Digest::CRC32.checksum(@data[0, (total - 4).to_i])
          if computed_msg != message_crc
            raise DecodeError.new(
              "Event stream message CRC mismatch: expected 0x#{message_crc.to_s(16)}, got 0x#{computed_msg.to_s(16)}"
            )
          end

          headers_start = PRELUDE_LENGTH
          headers_end = PRELUDE_LENGTH + headers_len.to_i
          payload_end = total.to_i - 4
          headers = parse_headers(@data[headers_start, headers_len.to_i])
          payload = @data[headers_end, payload_end - headers_end].dup

          # Advance buffer past this message
          remaining = @data[total.to_i..]
          @data = remaining.size == 0 ? Bytes.empty : remaining.dup
          @prelude_total = nil
          @prelude_headers_len = nil
          @prelude_crc = nil

          Message.new(headers, payload)
        end

        private def emit(msg : Message) : String?
          message_type = msg.headers[":message-type"]?

          case message_type
          when "event"
            emit_event(msg.payload)
          when "exception"
            exc_type = msg.headers[":exception-type"]? || "exception"
            body = String.new(msg.payload)
            data = {
              "type"  => "error",
              "error" => {
                "type"    => exc_type,
                "message" => body,
              },
            }.to_json
            "event: error\ndata: #{data}\n\n"
          when "error"
            err_type = msg.headers[":error-code"]? || "error"
            err_msg = msg.headers[":error-message"]? || String.new(msg.payload)
            data = {
              "type"  => "error",
              "error" => {
                "type"    => err_type,
                "message" => err_msg,
              },
            }.to_json
            "event: error\ndata: #{data}\n\n"
          else
            # Unknown / prelude / metadata frames — drop.
            nil
          end
        end

        private def emit_event(payload : Bytes) : String?
          return nil if payload.empty?

          outer = JSON.parse(String.new(payload))
          bytes_b64 = outer["bytes"]?.try(&.as_s?)
          return nil unless bytes_b64

          inner = String.new(Base64.decode(bytes_b64))
          event_type = JSON.parse(inner)["type"]?.try(&.as_s?)
          return nil unless event_type

          "event: #{event_type}\ndata: #{inner}\n\n"
        rescue JSON::ParseException | Base64::Error
          nil
        end

        private def parse_headers(data : Bytes) : Hash(String, String)
          headers = {} of String => String
          offset = 0
          while offset < data.size
            name_len = data[offset].to_i
            offset += 1
            name = String.new(data[offset, name_len])
            offset += name_len

            type = data[offset]
            offset += 1

            value, consumed = decode_header_value(type, data, offset)
            offset += consumed
            headers[name] = value
          end
          headers
        end

        private def decode_header_value(type : UInt8, data : Bytes, offset : Int32) : {String, Int32}
          case type
          when 0 then {"true", 0}
          when 1 then {"false", 0}
          when 2
            {data[offset].to_i8!.to_s, 1}
          when 3
            {read_i16(data, offset).to_s, 2}
          when 4
            {read_i32(data, offset).to_s, 4}
          when 5
            {read_i64(data, offset).to_s, 8}
          when 6 # byte_array
            len = read_u16(data, offset).to_i
            {Base64.strict_encode(data[offset + 2, len]), 2 + len}
          when 7 # string
            len = read_u16(data, offset).to_i
            {String.new(data[offset + 2, len]), 2 + len}
          when 8 # timestamp (ms)
            {read_i64(data, offset).to_s, 8}
          when 9 # uuid
            {data[offset, 16].hexstring, 16}
          else
            raise DecodeError.new("Unknown event stream header type: #{type}")
          end
        end

        private def append(chunk : Bytes) : Nil
          return if chunk.empty?
          if @data.empty?
            @data = chunk.dup
          else
            combined = Bytes.new(@data.size + chunk.size)
            @data.copy_to(combined)
            chunk.copy_to(combined + @data.size)
            @data = combined
          end
        end

        private def read_u16(data : Bytes, offset : Int32) : UInt16
          IO::ByteFormat::BigEndian.decode(UInt16, data[offset, 2])
        end

        private def read_u32(data : Bytes, offset : Int32) : UInt32
          IO::ByteFormat::BigEndian.decode(UInt32, data[offset, 4])
        end

        private def read_i16(data : Bytes, offset : Int32) : Int16
          IO::ByteFormat::BigEndian.decode(Int16, data[offset, 2])
        end

        private def read_i32(data : Bytes, offset : Int32) : Int32
          IO::ByteFormat::BigEndian.decode(Int32, data[offset, 4])
        end

        private def read_i64(data : Bytes, offset : Int32) : Int64
          IO::ByteFormat::BigEndian.decode(Int64, data[offset, 8])
        end
      end

      struct Message
        getter headers : Hash(String, String)
        getter payload : Bytes

        def initialize(@headers : Hash(String, String), @payload : Bytes)
        end
      end

      class DecodeError < Exception
      end
    end
  end
end
