module Anthropic
  # A generic SSE event stream for Managed Agents session/deployment events.
  #
  # Unlike `MessageStream` (which only decodes `/v1/messages` event shapes),
  # this yields each SSE `data:` payload as a `JSON::Any`, so it transparently
  # handles every session event type: `user.*`, `agent.*`, `session.*`,
  # `span.*`, `system.message`, and the opt-in `event_start` / `event_delta`
  # preview events enabled via `event_deltas:`.
  #
  # ```
  # client.beta.sessions.events.stream(session_id, event_deltas: ["agent.message"]) do |event|
  #   case event["type"].to_s
  #   when "event_delta" then print event["delta"]["content"]["text"]
  #   end
  # end
  # ```
  class SessionEventStream
    include Enumerable(JSON::Any)

    @response : HTTP::Client::Response

    def initialize(@response : HTTP::Client::Response)
    end

    def each(& : JSON::Any -> _)
      event_type = ""
      data_lines = [] of String

      # Prefer the live body_io; fall back to a buffered body (e.g. in tests).
      io = @response.body_io? || IO::Memory.new(@response.body)

      begin
        io.each_line do |raw_line|
          line = raw_line.ends_with?('\r') ? raw_line[0...-1] : raw_line

          if line.empty?
            dispatch_event(event_type, data_lines) { |event| yield event }
            event_type = ""
            data_lines.clear
            next
          end

          next if line.starts_with?(":")

          if line.starts_with?("event:")
            event_type = parse_sse_field_value(line, 6)
          elsif line.starts_with?("data:")
            data_lines << parse_sse_field_value(line, 5)
          end
        end
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Stream read timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error | OpenSSL::Error
        raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
      end

      dispatch_event(event_type, data_lines) { |event| yield event }
    end

    private def parse_sse_field_value(line : String, prefix_len : Int32) : String
      rest = line[prefix_len..]
      rest.starts_with?(' ') ? rest[1..] : rest
    end

    private def dispatch_event(event_type : String, data_lines : Array(String), &)
      return if data_lines.empty?

      data = data_lines.join("\n")
      return if data == "[DONE]"

      parsed = JSON.parse(data)
      yield parsed
      raise_sse_error_if_needed(event_type, parsed)
    end

    private def raise_sse_error_if_needed(event_type : String, parsed : JSON::Any) : Nil
      hash = parsed.as_h?
      payload_type = hash.try(&.[]?("type")).try(&.as_s?)
      nested_error = hash.try(&.[]?("error")).try(&.as_h?)
      return unless event_type == "error" || (payload_type == "error" && nested_error)

      err_hash = nested_error || hash
      error_type = err_hash.try(&.[]?("type")).try(&.as_s?)
      api_message = err_hash.try(&.[]?("message")).try(&.as_s?)
      details = err_hash.try(&.[]?("details"))
      raise Anthropic.build_stream_api_error(error_type, api_message, details)
    end
  end
end
