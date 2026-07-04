module Anthropic
  # Single source of truth for the `x-stainless-helper` telemetry header.
  #
  # The Anthropic backend uses this header to attribute requests to specific
  # SDK helpers (tool runners, middleware, MCP helpers, etc.). This module
  # centralizes the header key and a closed vocabulary of tag values so call
  # sites can't typo them, and provides append semantics so multiple helpers
  # composing on one request combine into a single comma-separated value rather
  # than clobbering each other.
  module StainlessHelper
    HEADER = "x-stainless-helper"

    # Closed vocabulary of helper tag values.
    BETA_TOOL_RUNNER            = "BetaToolRunner"
    COMPACTION                  = "compaction"
    FALLBACK_REFUSAL_MIDDLEWARE = "fallback-refusal-middleware"
    SESSION_TOOL_RUNNER         = "session-tool-runner"

    # Merge a helper tag into an existing headers hash with append semantics.
    #
    # If the header is already present, the new value is appended (preserving
    # order, dropping duplicates); otherwise it is set. Returns a new hash.
    def self.merge_helper_header(headers : Hash(String, String)?, value : String) : Hash(String, String)
      result = headers ? headers.dup : {} of String => String

      if existing = result[HEADER]?
        parts = existing.split(',').map(&.strip)
        parts << value unless parts.includes?(value)
        result[HEADER] = parts.join(",")
      else
        result[HEADER] = value
      end

      result
    end

    # Merge a helper tag into an `HTTP::Headers` (mutates and returns it).
    def self.merge_helper_header(headers : HTTP::Headers, value : String) : HTTP::Headers
      if existing = headers[HEADER]?
        parts = existing.split(',').map(&.strip)
        parts << value unless parts.includes?(value)
        headers[HEADER] = parts.join(",")
      else
        headers[HEADER] = value
      end
      headers
    end

    # Convenience: build a single-entry header hash for one helper tag.
    def self.header(value : String) : Hash(String, String)
      {HEADER => value}
    end
  end
end
