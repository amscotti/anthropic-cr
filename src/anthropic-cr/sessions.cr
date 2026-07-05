module Anthropic
  # Helpers for Managed Agents session event streams.
  module Sessions
    # Delta type values that may be passed to `event_deltas:`.
    #
    # `"agent.message"` streams live preview deltas of the agent's message;
    # `"agent.thinking"` streams thinking previews (start-only, no deltas).
    module DeltaType
      AGENT_MESSAGE  = "agent.message"
      AGENT_THINKING = "agent.thinking"
    end

    # A text block carried inside a managed-agents `event_delta`.
    struct ManagedAgentsTextBlock
      include JSON::Serializable

      getter text : String
      getter type : String = "text"

      def initialize(@text : String, @type : String = "text")
      end
    end

    # The `delta` payload of an `event_delta` event.
    struct ManagedAgentsDeltaContent
      include JSON::Serializable

      getter content : ManagedAgentsTextBlock

      @[JSON::Field(key: "type")]
      getter type : String = "content_delta"

      @[JSON::Field(emit_null: false)]
      getter index : Int32?

      def initialize(@content : ManagedAgentsTextBlock, @type : String = "content_delta", @index : Int32? = nil)
      end
    end

    # Fold Managed Agents session/preview streaming events into a buffered
    # `agent.message` snapshot (returned as a `JSON::Any` object).
    #
    # Mirrors the TypeScript/Python `accumulate_managed_agents_event` helper.
    # Pass the previously accumulated snapshot (or `nil`) plus the latest event,
    # and receive the updated snapshot (or `nil` for non-agent.message events
    # that don't affect the accumulator).
    #
    # - `event_start` with `event.type == "agent.message"` opens a fresh snapshot
    #   `{id, type: "agent.message", content: [], processed_at: ""}`.
    # - `event_delta` folds `delta.content` into `content[delta.index ?? 0]`.
    # - `agent.message` (buffered final) replaces the snapshot.
    # - All other event types are no-ops returning `accumulated` unchanged.
    #
    # Returns `nil` if a delta arrives before its `event_start` (the caller
    # should drop stray deltas), per the official manual-deltas example.
    def self.accumulate_managed_agents_event(accumulated : JSON::Any?, event : JSON::Any) : JSON::Any?
      event_type = event["type"]?.try(&.to_s) || ""

      case event_type
      when "event_start"
        preview = event["event"]?
        return accumulated unless preview && preview["type"]?.try(&.to_s) == "agent.message"

        id = preview["id"]?.try(&.to_s) || ""
        open_snapshot(id)
      when "event_delta"
        return nil if accumulated.nil?

        delta = event["delta"]?
        return accumulated unless delta

        index = delta["index"]?.try(&.as_i?) || 0
        fragment = delta["content"]?
        return accumulated unless fragment

        fold_fragment(accumulated, index, fragment)
      when "agent.message"
        # Buffered final supersedes the preview.
        event.dup
      else
        accumulated
      end
    end

    # Opens a fresh agent.message snapshot with empty content.
    private def self.open_snapshot(id : String) : JSON::Any
      JSON.parse(%({"id":#{id.to_json},"type":"agent.message","content":[],"processed_at":""}))
    end

    # Folds a single text fragment into the snapshot at the given index.
    # Returns a fresh snapshot; the input snapshot is not mutated.
    private def self.fold_fragment(snapshot : JSON::Any, index : Int32, fragment : JSON::Any) : JSON::Any
      content = snapshot["content"].as_a.dup

      # Pad the content array up to the target index.
      while content.size <= index
        content << JSON.parse(%({"type":"text","text":""}))
      end

      existing = content[index]
      fragment_text = fragment["text"]?.try(&.to_s) || ""

      new_text =
        if existing["type"]?.try(&.to_s) == "text"
          (existing["text"]?.try(&.to_s) || "") + fragment_text
        else
          fragment_text
        end

      content[index] = JSON.parse(%({"type":"text","text":#{new_text.to_json}}))

      # Rebuild the snapshot with updated content.
      hash = snapshot.as_h.dup
      hash["content"] = JSON::Any.new(content)
      JSON::Any.new(hash)
    end
  end
end
