module Anthropic
  # Runs local tools for a managed-agents session until it ends.
  #
  # A synchronous port of the TypeScript SDK's `SessionToolRunner`: it
  # streams session events, executes matching local tools for
  # `agent.tool_use` / `agent.custom_tool_use` events, sends the results
  # back, and returns when the session terminates or goes idle.
  #
  # - **Reconnect:** stream disconnects (and clean EOFs) reconnect with
  #   jittered exponential backoff (500ms start, 10s cap, reset on every
  #   received event). Permanent 4xx failures (any 4xx except 408/409/429)
  #   abort the run instead of reconnecting. `max_reconnects` bounds the
  #   loop (`nil` reconnects forever, like TypeScript).
  # - **Reconcile:** after each (re)connect the runner re-reads recent
  #   history so tool calls emitted while disconnected still dispatch
  #   (already-answered calls and already-seen tool uses are skipped). A
  #   failed history read is non-fatal — the live stream carries on. A
  #   terminal event in history ends the run immediately, and a trailing
  #   `end_turn` idle re-arms the idle countdown.
  # - **Confirmation gating:** calls the server gated (`evaluated_permission
  #   == "ask"`, or an unrecognized permission) are held until a matching
  #   `user.tool_confirmation` verdict arrives. Only an explicit `allow`
  #   runs the tool; anything else (including server-side `deny`, which
  #   overrides any recorded verdict) resolves the call without executing
  #   or posting, exactly like TypeScript.
  # - **Idle stop:** after a `session.status_idle` event with an `end_turn`
  #   stop reason, the run ends once `max_idle` elapses with no further
  #   activity (any other event disarms the countdown; held confirmations
  #   defer it). Defaults to 60 seconds like TypeScript; `nil` disables it.
  #   Note the countdown is only evaluated when events arrive or the
  #   stream errors, so detection latency is bounded by event cadence and
  #   the client's read timeout — and the event that reveals an expired
  #   countdown is swallowed (never routed to `on_event`).
  #
  # Tool calls naming an unregistered tool are skipped without posting a
  # result: the name belongs to another client servicing the session,
  # and claiming it would corrupt the conversation.
  #
  # Divergences from TypeScript: the runner is synchronous (no async
  # iterator of outcomes — use `on_call` for per-call observability, and
  # `on_event` for live-stream events, which does not refire for
  # reconciled history), sends rely on the client's retry policy rather
  # than a dedicated send-retry loop, and a failed send aborts the run
  # instead of reconnecting (reconnecting would re-execute the tool).
  # Skipped unregistered calls are marked answered locally (TypeScript
  # leaves them pending for their owner; here that would re-surface them
  # on every reconnect), and tools have no execution timeout (TypeScript
  # aborts tools after 120s) — a hung tool blocks `run`.
  #
  # ```
  # runner = Anthropic::SessionRunner.new(
  #   client: client,
  #   session_id: "sess_123",
  #   tools: [my_tool],
  #   on_call: ->(call : Anthropic::SessionRunner::ToolCall) {
  #     puts "#{call.name}: executed=#{call.executed?}"
  #     nil
  #   }
  # )
  # terminal = runner.run
  # ```
  class SessionRunner
    Log = ::Log.for("anthropic-cr.session_runner")

    # Session event types that end a run.
    TERMINAL_EVENT_TYPES = [
      "session.status_terminated",
      "session.deleted",
    ]

    # Reconnect backoff: 500ms start, doubling to a 10s cap (jittered).
    STREAM_BACKOFF_START = 500.milliseconds
    STREAM_BACKOFF_CAP   = 10.seconds

    # Default idle stop after an `end_turn` idle.
    DEFAULT_MAX_IDLE = 60.seconds

    # History window re-read after each (re)connect.
    RECONCILE_LIMIT = 1000

    @idle_armed_at : Time?

    # Outcome of one tool call the runner disposed of.
    #
    # `confirmation` is the verdict that gated the call (`"allow"` when a
    # held call was approved, `"deny"` when it was denied, `nil` when the
    # call needed no confirmation). A denied call never executes and posts
    # nothing; a call for an unregistered tool likewise reports
    # `executed: false, posted: false`. A call whose result post failed
    # reports `executed: true, posted: false` before the run aborts.
    struct ToolCall
      getter id : String
      getter name : String
      getter confirmation : String?
      getter? executed : Bool
      getter? posted : Bool
      getter? is_error : Bool

      def initialize(
        @id : String,
        @name : String,
        @confirmation : String? = nil,
        @executed : Bool = false,
        @posted : Bool = false,
        @is_error : Bool = false,
      )
      end
    end

    def initialize(
      @client : Client,
      @session_id : String,
      @tools : Array(Tool) = [] of Tool,
      @max_events : Int32? = nil,
      @betas : Array(String) = [] of String,
      @workspace_id : String? = nil,
      @on_event : Proc(JSON::Any, Nil)? = nil,
      @on_call : Proc(ToolCall, Nil)? = nil,
      @max_idle : Time::Span? = DEFAULT_MAX_IDLE,
      @max_reconnects : Int32? = nil,
    )
      @seen = Set(String).new
      @answered = Set(String).new
      @verdicts = {} of String => String
      @held = {} of String => JSON::Any
      @count = 0
      @backoff = STREAM_BACKOFF_START
      @reconnects = 0
      @idle_armed_at = nil
      @dispatching = false
    end

    # Stream session events and execute local tools until the session
    # reaches a terminal event. Returns the terminal event, or `nil`
    # when the run stops another way (`max_events` / idle / reconnect
    # limit interplay aside, the reconnect limit raises).
    def run : JSON::Any?
      reset_run_state

      loop do
        cause : Exception? = nil
        outcome : JSON::Any | Symbol = begin
          if terminal = reconcile
            return terminal
          end
          consume_stream
        rescue ex : APIError | JSON::ParseException
          dispatching = @dispatching
          @dispatching = false
          # A failed send aborts the run: the tool already executed, so
          # reconnecting would run it a second time.
          raise ex if ex.is_a?(APIError) && (fatal_4xx?(ex) || dispatching)
          cause = ex
          :reconnect
        end

        case outcome
        when JSON::Any
          return outcome
        when :max_events, :idle
          return nil
        else
          return nil unless reconnect_or_stop(cause)
        end
      end
    end

    private def reset_run_state : Nil
      @seen = Set(String).new
      @answered = Set(String).new
      @verdicts = {} of String => String
      @held = {} of String => JSON::Any
      @count = 0
      @backoff = STREAM_BACKOFF_START
      @reconnects = 0
      @idle_armed_at = nil
      @dispatching = false
    end

    # Consume one stream attachment. Returns the terminal event, or
    # `:max_events` / `:idle` when a stop condition trips, `:eof` when
    # the stream ends cleanly (the caller reconnects).
    #
    # Only tool-use events are deduplicated: confirmations, results, and
    # terminal events always apply (matching TypeScript), so a terminal
    # whose id is already known — e.g. from the reconcile pass — still
    # ends the run instead of spinning on EOF reconnects.
    private def consume_stream : JSON::Any | Symbol
      outcome : JSON::Any | Symbol = :eof

      @client.beta.sessions.events.stream(
        @session_id,
        betas: @betas,
        workspace_id: @workspace_id
      ) do |event|
        @backoff = STREAM_BACKOFF_START
        next unless event.as_h?

        # Checked before tracking: the event that would disarm the
        # countdown must not suppress a countdown that already elapsed
        # (the timer would have fired during the quiet period).
        if idle_expired?
          outcome = :idle
          break
        end
        track_idle(event)

        @on_event.try(&.call(event))
        @count += 1

        if terminal_event?(event)
          outcome = event
          break
        end

        case event["type"]?.try(&.as_s?)
        when "agent.tool_use", "agent.custom_tool_use"
          id = event["id"]?.try(&.as_s?)
          if id.nil? || !@seen.includes?(id)
            @seen << id if id
            route_tool_event(event)
          end
        when "user.tool_confirmation"
          note_confirmation(event)
        when "user.tool_result"
          if tid = event["tool_use_id"]?.try(&.as_s?)
            @answered << tid
          end
        when "user.custom_tool_result"
          if tid = event["custom_tool_use_id"]?.try(&.as_s?)
            @answered << tid
          end
        end

        if max = @max_events
          if @count >= max
            outcome = :max_events
            break
          end
        end
      end

      outcome
    end

    # Sleep with backoff and report whether the run continues. Returns
    # `false` when the idle countdown tripped while disconnected, and
    # raises once `max_reconnects` is exceeded.
    private def reconnect_or_stop(cause : Exception?) : Bool
      if idle_expired?
        Log.info { "Session idle timeout reached, stopping run" }
        return false
      end

      @reconnects += 1
      if max = @max_reconnects
        if @reconnects > max
          message = "Session stream reconnect limit (#{max}) exceeded"
          raise cause ? APIConnectionError.new(message, cause: cause) : APIConnectionError.new(message)
        end
      end

      if cause
        Log.warn { "Session event stream disconnected (#{cause.message}), reconnecting" }
      else
        Log.info { "Session event stream ended, reconnecting" }
      end
      sleep(jittered(@backoff))
      @backoff = Math.min(@backoff * 2, STREAM_BACKOFF_CAP)
      true
    end

    # Re-read recent history so tool calls emitted while disconnected
    # still dispatch. Already-answered calls are skipped; verdicts and
    # results in the window populate local state. Returns the history's
    # terminal event when the session already ended (nothing further can
    # happen, so the run ends without routing). A failed read is
    # non-fatal: speculative `seen` entries are undone and the live
    # stream carries on.
    private def reconcile : JSON::Any?
      pending = [] of JSON::Any
      terminal : JSON::Any? = nil
      last_end_turn = false

      begin
        page = @client.beta.sessions.events.list(
          @session_id,
          limit: RECONCILE_LIMIT,
          betas: @betas,
          workspace_id: @workspace_id
        )
        events = page["data"]?.try(&.as_a?) || [] of JSON::Any
        events.each do |event|
          next unless event.as_h?
          terminal = event if terminal_event?(event)
          last_end_turn = end_turn_idle?(event)
          ingest_history(event, pending)
        end
      rescue ex : Exception
        Log.warn { "Session history reconcile failed (#{ex.message}); continuing with live stream" }
        pending.each do |event|
          if id = event["id"]?.try(&.as_s?)
            @seen.delete(id)
          end
        end
        return nil
      end

      return terminal if terminal

      @idle_armed_at = nil
      pending.each do |event|
        id = event["id"]?.try(&.as_s?)
        next unless id
        next if @answered.includes?(id)
        route_tool_event(event)
      end

      # A held call whose tool_use fell outside the listed window never
      # routes above; apply any verdict recorded since it was held.
      releasable = @held.compact_map do |id, event|
        verdict = @verdicts[id]?
        next nil unless verdict
        held_id = event["id"]?.try(&.as_s?)
        held_name = event["name"]?.try(&.as_s?)
        held_id && held_name ? {event, held_id, held_name, verdict} : nil
      end
      releasable.each do |(event, id, name, verdict)|
        apply_verdict(event, id, name, verdict)
      end

      # Re-arm when history trails an `end_turn` idle: routing above
      # either answered or held every pending call, and held calls defer
      # the countdown via `idle_expired?` (matching TypeScript, where a
      # held call blocks an armed clock).
      @idle_armed_at = Time.utc if last_end_turn && @max_idle
      nil
    end

    private def terminal_event?(event : JSON::Any) : Bool
      type = event["type"]?.try(&.as_s?)
      !type.nil? && TERMINAL_EVENT_TYPES.includes?(type)
    end

    private def ingest_history(ev : JSON::Any, pending : Array(JSON::Any)) : Nil
      if id = ev["id"]?.try(&.as_s?)
        @seen << id
      end

      case ev["type"]?.try(&.as_s?)
      when "agent.tool_use", "agent.custom_tool_use"
        pending << ev if ev["id"]?
      when "user.tool_result"
        if tid = ev["tool_use_id"]?.try(&.as_s?)
          @answered << tid
        end
      when "user.custom_tool_result"
        if tid = ev["custom_tool_use_id"]?.try(&.as_s?)
          @answered << tid
        end
      when "user.tool_confirmation"
        note_confirmation(ev)
      end
    end

    # Dispatch a tool-use event, honoring its evaluated permission. A
    # call the server gated (`"ask"`, or a permission this SDK does not
    # recognize) is held until its `user.tool_confirmation` arrives.
    # Fails closed: only an explicit `allow` verdict releases a gated
    # call, and a server-side `deny` overrides any recorded verdict.
    private def route_tool_event(event : JSON::Any) : Nil
      id = event["id"]?.try(&.as_s?)
      name = event["name"]?.try(&.as_s?)
      unless id && name
        Log.warn { "Skipping malformed tool-use event without id/name" }
        return
      end
      return if @answered.includes?(id)

      permission = event["evaluated_permission"]?.try(&.as_s?)
      verdict = permission == "deny" ? "deny" : @verdicts[id]?

      if verdict.nil?
        if permission.nil? || permission == "allow"
          execute_tool(event, id, name, nil)
        elsif !@held.has_key?(id)
          Log.info { "Tool call #{name} (#{id}) awaiting confirmation; holding" }
          @held[id] = event
        end
        return
      end

      apply_verdict(event, id, name, verdict)
    end

    # Record an allow/deny verdict and release the held call it gates,
    # if any. Verdicts for unseen calls are kept so a later route of
    # the call resolves instantly.
    private def note_confirmation(event : JSON::Any) : Nil
      tool_use_id = event["tool_use_id"]?.try(&.as_s?)
      result = event["result"]?.try(&.as_s?)
      return unless tool_use_id && result

      @verdicts[tool_use_id] = result
      if held = @held.delete(tool_use_id)
        held_id = held["id"]?.try(&.as_s?)
        held_name = held["name"]?.try(&.as_s?)
        apply_verdict(held, held_id, held_name, result) if held_id && held_name
      end
    end

    # Dispatch or resolve a gated call according to its verdict. A
    # denial (or anything but an explicit `"allow"` — fail closed)
    # resolves the call server-side, so it is marked answered with
    # nothing executed and nothing posted.
    private def apply_verdict(event : JSON::Any, id : String, name : String, verdict : String) : Nil
      @held.delete(id)

      unless verdict == "allow"
        @answered << id
        Log.info { "Tool call #{name} (#{id}) denied; not executing" }
        @on_call.try(&.call(ToolCall.new(id, name, confirmation: "deny")))
        return
      end

      Log.info { "Tool call #{name} (#{id}) confirmed" }
      execute_tool(event, id, name, "allow")
    end

    # Execute the tool named by a tool-use event and send the result
    # back to the session. The event id doubles as the result's
    # `tool_use_id` / `custom_tool_use_id`. Tool calls this runner is
    # not registered for are skipped without posting a result.
    #
    # `@dispatching` stays set when the send raises so `run` aborts
    # instead of reconnecting (which would re-execute the tool); it is
    # cleared on success and by `run`'s rescue path.
    private def execute_tool(event : JSON::Any, id : String, name : String, confirmation : String?) : Nil
      raw_input = event["input"]?
      input =
        if raw_input.is_a?(JSON::Any) && raw_input.as_h?
          raw_input
        else
          JSON::Any.new({} of String => JSON::Any)
        end

      tool = @tools.find { |candidate| candidate.name == name }
      unless tool
        @answered << id
        Log.info { "Skipping tool call for unregistered tool #{name} (#{id})" }
        @on_call.try(&.call(ToolCall.new(id, name, confirmation: confirmation)))
        return
      end

      @dispatching = true

      output, is_error = begin
        {tool.call(input), false}
      rescue ex
        {ex.message || "tool failed", true}
      end

      custom = event["type"]?.try(&.as_s?) == "agent.custom_tool_use"
      content = [BetaSessionTextBlock.new(output)] of BetaSessionEventContent
      result : BetaSessionInputEvent = if custom
        BetaSessionUserCustomToolResultEvent.new(
          custom_tool_use_id: id,
          content: content,
          is_error: is_error
        )
      else
        BetaSessionUserToolResultEvent.new(
          tool_use_id: id,
          content: content,
          is_error: is_error
        )
      end

      begin
        @client.beta.sessions.events.send(
          @session_id,
          [result] of BetaSessionInputEvent,
          betas: @betas,
          workspace_id: @workspace_id
        )
      rescue ex : APIError
        # The tool ran but its result never posted; surface that before
        # the abort so the call is observable like any other outcome.
        @on_call.try(&.call(ToolCall.new(id, name, confirmation: confirmation, executed: true, posted: false, is_error: is_error)))
        raise ex
      end
      @answered << id
      @on_call.try(&.call(ToolCall.new(id, name, confirmation: confirmation, executed: true, posted: true, is_error: is_error)))
      @dispatching = false
    end

    # Arm the idle countdown on `end_turn` idles, disarm on any other
    # activity. Confirmations are neutral: they signal neither agent
    # activity nor a fresh idle.
    private def track_idle(event : JSON::Any) : Nil
      return unless @max_idle
      return if event["type"]?.try(&.as_s?) == "user.tool_confirmation"

      @idle_armed_at = end_turn_idle?(event) ? Time.utc : nil
    end

    private def end_turn_idle?(event : JSON::Any) : Bool
      return false unless event["type"]?.try(&.as_s?) == "session.status_idle"
      reason = event["stop_reason"]?.try(&.as_h?)
      return false unless reason
      reason["type"]?.try(&.as_s?) == "end_turn"
    end

    private def idle_expired? : Bool
      max = @max_idle
      armed = @idle_armed_at
      return false unless max && armed
      # The countdown defers while confirmation-gated work is held.
      return false unless @held.empty?
      Time.utc - armed >= max
    end

    # A 4xx the client's retry policy would not retry (i.e. anything
    # but 408/409/429): a permanent failure, so the run aborts.
    private def fatal_4xx?(ex : APIError) : Bool
      status = ex.status
      return false unless status && status >= 400 && status < 500
      !status.in?(408, 409, 429)
    end

    # Trim up to 25% off a backoff so a fleet of clients backing off
    # after a shared outage does not retry in lockstep.
    private def jittered(backoff : Time::Span) : Time::Span
      (backoff.total_milliseconds * (1.0 - rand * 0.25)).milliseconds
    end
  end
end
