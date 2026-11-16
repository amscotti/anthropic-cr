module Anthropic
  # Shared helper module for cursor-paginated responses (`next_page` token).
  #
  # Per the 2026-10-21 SDK pagination semantics, pagination continues whenever
  # `next_page` is a non-nil, non-empty string even if the current page's `data`
  # array is empty.
  module PageCursorMethods
    # Returns `true` when there is a non-empty `next_page` cursor token,
    # regardless of whether `data` is empty.
    def has_next_page? : Bool
      cursor = next_page
      !cursor.nil? && !cursor.empty?
    end
  end

  # Generic page-cursor response wrapper with `data` and `next_page`.
  struct PageCursor(T)
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(T) = [] of T

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?

    def initialize(
      @data : Array(T) = [] of T,
      @next_page : String? = nil,
    )
    end
  end

  # Page-cursor response for analytics/report endpoints with explicit
  # `has_more` flag and optional `data_refreshed_at` timestamp.
  #
  # Unlike standard `PageCursor`, `has_next_page?` returns `false` immediately
  # when `has_more` is `false` even if `next_page` is present.
  struct ReportPageCursor(T)
    include JSON::Serializable

    getter data : Array(T) = [] of T

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool = false

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?

    @[JSON::Field(key: "data_refreshed_at", emit_null: false)]
    getter data_refreshed_at : String?

    def initialize(
      @data : Array(T) = [] of T,
      @next_page : String? = nil,
      @has_more : Bool = false,
      @data_refreshed_at : String? = nil,
    )
    end

    def has_more? : Bool
      @has_more
    end

    def has_next_page? : Bool
      return false unless @has_more

      cursor = @next_page
      !cursor.nil? && !cursor.empty?
    end
  end
end
