module Anthropic
  # Per-member enable/defer configuration for toolset server tools
  # (`browser_toolset_20260801` and `computer_toolset_20260801`).
  struct ToolsetMemberConfig
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter enabled : Bool?

    @[JSON::Field(key: "defer_loading", emit_null: false)]
    getter defer_loading : Bool?

    def initialize(@enabled : Bool? = nil, @defer_loading : Bool? = nil)
    end
  end

  # Per-member configuration for `browser_toolset_20260801`: one optional field
  # per built-in browser tool name.
  struct BrowserToolsetConfigs
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter close_tab : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter double_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter file_upload : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter find : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter form_input : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter get_page_text : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter hold_key : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter hover : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter javascript_exec : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter key : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_click_drag : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_mouse_down : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_mouse_up : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter list_tabs : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter middle_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter mouse_move : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter navigate : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter new_tab : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter read_console : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter read_network : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter read_page : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter right_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter screenshot : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter scroll : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter scroll_to : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter switch_tab : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter triple_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter type : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter wait : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter zoom : ToolsetMemberConfig?

    def initialize(
      @close_tab : ToolsetMemberConfig? = nil,
      @double_click : ToolsetMemberConfig? = nil,
      @file_upload : ToolsetMemberConfig? = nil,
      @find : ToolsetMemberConfig? = nil,
      @form_input : ToolsetMemberConfig? = nil,
      @get_page_text : ToolsetMemberConfig? = nil,
      @hold_key : ToolsetMemberConfig? = nil,
      @hover : ToolsetMemberConfig? = nil,
      @javascript_exec : ToolsetMemberConfig? = nil,
      @key : ToolsetMemberConfig? = nil,
      @left_click : ToolsetMemberConfig? = nil,
      @left_click_drag : ToolsetMemberConfig? = nil,
      @left_mouse_down : ToolsetMemberConfig? = nil,
      @left_mouse_up : ToolsetMemberConfig? = nil,
      @list_tabs : ToolsetMemberConfig? = nil,
      @middle_click : ToolsetMemberConfig? = nil,
      @mouse_move : ToolsetMemberConfig? = nil,
      @navigate : ToolsetMemberConfig? = nil,
      @new_tab : ToolsetMemberConfig? = nil,
      @read_console : ToolsetMemberConfig? = nil,
      @read_network : ToolsetMemberConfig? = nil,
      @read_page : ToolsetMemberConfig? = nil,
      @right_click : ToolsetMemberConfig? = nil,
      @screenshot : ToolsetMemberConfig? = nil,
      @scroll : ToolsetMemberConfig? = nil,
      @scroll_to : ToolsetMemberConfig? = nil,
      @switch_tab : ToolsetMemberConfig? = nil,
      @triple_click : ToolsetMemberConfig? = nil,
      @type : ToolsetMemberConfig? = nil,
      @wait : ToolsetMemberConfig? = nil,
      @zoom : ToolsetMemberConfig? = nil,
    )
    end
  end

  # Browser toolset server tool definition (`browser_toolset_20260801`).
  #
  # Does not require any `anthropic-beta` header; when included in a request's
  # `server_tools`, the SDK attaches `x-stainless-helper: browser-toolset`.
  struct BrowserToolset20260801 < ServerTool
    include JSON::Serializable

    getter type : String = "browser_toolset_20260801"

    @[JSON::Field(emit_null: false)]
    getter configs : BrowserToolsetConfigs?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    def initialize(
      @configs : BrowserToolsetConfigs? = nil,
      @cache_control : CacheControl? = nil,
    )
    end
  end

  # Per-member configuration for `computer_toolset_20260801`: one optional field
  # per built-in computer tool name.
  struct ComputerToolsetConfigs
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter cursor_position : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter double_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter hold_key : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter key : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_click_drag : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_mouse_down : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter left_mouse_up : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter middle_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter mouse_move : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter right_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter screenshot : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter scroll : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter triple_click : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter type : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter wait : ToolsetMemberConfig?
    @[JSON::Field(emit_null: false)]
    getter zoom : ToolsetMemberConfig?

    def initialize(
      @cursor_position : ToolsetMemberConfig? = nil,
      @double_click : ToolsetMemberConfig? = nil,
      @hold_key : ToolsetMemberConfig? = nil,
      @key : ToolsetMemberConfig? = nil,
      @left_click : ToolsetMemberConfig? = nil,
      @left_click_drag : ToolsetMemberConfig? = nil,
      @left_mouse_down : ToolsetMemberConfig? = nil,
      @left_mouse_up : ToolsetMemberConfig? = nil,
      @middle_click : ToolsetMemberConfig? = nil,
      @mouse_move : ToolsetMemberConfig? = nil,
      @right_click : ToolsetMemberConfig? = nil,
      @screenshot : ToolsetMemberConfig? = nil,
      @scroll : ToolsetMemberConfig? = nil,
      @triple_click : ToolsetMemberConfig? = nil,
      @type : ToolsetMemberConfig? = nil,
      @wait : ToolsetMemberConfig? = nil,
      @zoom : ToolsetMemberConfig? = nil,
    )
    end
  end

  # Computer toolset server tool definition (`computer_toolset_20260801`).
  #
  # Does not require any `anthropic-beta` header; when included in a request's
  # `server_tools`, the SDK attaches `x-stainless-helper: computer-toolset`.
  struct ComputerToolset20260801 < ServerTool
    include JSON::Serializable

    getter type : String = "computer_toolset_20260801"

    @[JSON::Field(emit_null: false)]
    getter configs : ComputerToolsetConfigs?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    def initialize(
      @configs : ComputerToolsetConfigs? = nil,
      @cache_control : CacheControl? = nil,
    )
    end
  end

  # Merge `x-stainless-helper` tags for any toolset server tools included in a request.
  def self.merge_toolset_helper_headers(
    headers : Hash(String, String)?,
    server_tools : Enumerable(ServerTool | ToolDefinition)?,
  ) : Hash(String, String)?
    return headers unless server_tools

    result = headers
    has_browser = server_tools.any?(BrowserToolset20260801)
    has_computer = server_tools.any?(ComputerToolset20260801)
    result = StainlessHelper.merge_helper_header(result, StainlessHelper::BROWSER_TOOLSET) if has_browser
    result = StainlessHelper.merge_helper_header(result, StainlessHelper::COMPUTER_TOOLSET) if has_computer
    result
  end

  # Open tab snapshot in a `browser_state` tool result content block.
  struct BrowserStateTabEntry
    include JSON::Serializable

    @[JSON::Field(key: "tab_id")]
    getter tab_id : String

    getter title : String
    getter url : String

    @[JSON::Field(emit_null: false)]
    getter active : Bool?

    def initialize(
      @tab_id : String,
      @title : String,
      @url : String,
      @active : Bool? = nil,
    )
    end
  end

  # State change: a browser tab was opened.
  struct BrowserStateChangeTabOpened
    include JSON::Serializable

    getter type : String = "tab_opened"

    @[JSON::Field(key: "tab_id")]
    getter tab_id : String

    def initialize(@tab_id : String)
      @type = "tab_opened"
    end
  end

  # State change: a browser file download started.
  struct BrowserStateChangeDownloadStarted
    include JSON::Serializable

    getter type : String = "download_started"

    @[JSON::Field(key: "download_id")]
    getter download_id : String

    getter url : String

    def initialize(@download_id : String, @url : String)
      @type = "download_started"
    end
  end

  # State change: a browser file download completed.
  struct BrowserStateChangeDownloadCompleted
    include JSON::Serializable

    getter type : String = "download_completed"

    @[JSON::Field(key: "download_id")]
    getter download_id : String

    getter url : String

    @[JSON::Field(emit_null: false)]
    getter path : String?

    @[JSON::Field(key: "size_bytes", emit_null: false)]
    getter size_bytes : Int64?

    def initialize(
      @download_id : String,
      @url : String,
      @path : String? = nil,
      @size_bytes : Int64? = nil,
    )
      @type = "download_completed"
    end
  end

  # State change: a browser file download failed.
  struct BrowserStateChangeDownloadFailed
    include JSON::Serializable

    getter type : String = "download_failed"

    @[JSON::Field(key: "download_id")]
    getter download_id : String

    getter url : String

    @[JSON::Field(emit_null: false)]
    getter error : String?

    def initialize(@download_id : String, @url : String, @error : String? = nil)
      @type = "download_failed"
    end
  end

  alias BrowserStateChange = BrowserStateChangeTabOpened |
                             BrowserStateChangeDownloadStarted |
                             BrowserStateChangeDownloadCompleted |
                             BrowserStateChangeDownloadFailed

  module BrowserStateChangeConverter
    def self.from_json(pull : JSON::PullParser) : BrowserStateChange
      json = JSON::Any.new(pull)
      raw = json.to_json

      case json["type"]?.try(&.as_s?)
      when "tab_opened"
        BrowserStateChangeTabOpened.from_json(raw)
      when "download_started"
        BrowserStateChangeDownloadStarted.from_json(raw)
      when "download_completed"
        BrowserStateChangeDownloadCompleted.from_json(raw)
      when "download_failed"
        BrowserStateChangeDownloadFailed.from_json(raw)
      else
        raise JSON::ParseException.new("Unknown browser state change type: #{json["type"]?}", 0, 0)
      end
    end

    def self.to_json(value : BrowserStateChange, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  module BrowserStateChangeArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(BrowserStateChange)
      result = [] of BrowserStateChange
      pull.read_array do
        result << BrowserStateChangeConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(BrowserStateChange), builder : JSON::Builder) : Nil
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end

  # Browser state snapshot included inside `ToolResultContent#content`.
  struct BrowserStateContent
    include JSON::Serializable

    getter type : String = "browser_state"
    getter tabs : Array(BrowserStateTabEntry)

    @[JSON::Field(key: "state_changes", converter: Anthropic::BrowserStateChangeArrayConverter, emit_null: false)]
    getter state_changes : Array(BrowserStateChange)?

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    def initialize(
      @tabs : Array(BrowserStateTabEntry),
      @state_changes : Array(BrowserStateChange)? = nil,
      @cache_control : CacheControl? = nil,
    )
      @type = "browser_state"
    end
  end

  # Filter constants for `BrowserReadPageInput#filter`.
  module BrowserReadPageFilter
    ALL         = "all"
    INTERACTIVE = "interactive"
  end

  # Scroll direction constants for `BrowserScrollInput` and `ComputerScrollInput`.
  module ToolsetScrollDirection
    UP    = "up"
    DOWN  = "down"
    LEFT  = "left"
    RIGHT = "right"
  end

  alias BrowserScrollDirection = ToolsetScrollDirection
  alias ComputerScrollDirection = ToolsetScrollDirection

  # Coordinate target for browser pointer actions.
  struct BrowserCoordinateTarget
    include JSON::Serializable

    getter type : String = "coordinate"
    getter x : Int32
    getter y : Int32

    def initialize(@x : Int32, @y : Int32)
      @type = "coordinate"
    end
  end

  # Element reference target for browser actions.
  struct BrowserRefTarget
    include JSON::Serializable

    getter type : String = "ref"
    getter ref : String

    def initialize(@ref : String)
      @type = "ref"
    end
  end

  alias BrowserClickTarget = BrowserCoordinateTarget | BrowserRefTarget

  module BrowserClickTargetConverter
    def self.from_json(pull : JSON::PullParser) : BrowserClickTarget
      json = JSON::Any.new(pull)
      raw = json.to_json

      case json["type"]?.try(&.as_s?)
      when "coordinate"
        BrowserCoordinateTarget.from_json(raw)
      when "ref"
        BrowserRefTarget.from_json(raw)
      else
        raise JSON::ParseException.new("Unknown browser click target type: #{json["type"]?}", 0, 0)
      end
    end

    def self.to_json(value : BrowserClickTarget, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  alias BrowserFormInputValue = String | Float64 | Bool

  module BrowserFormInputValueConverter
    def self.from_json(pull : JSON::PullParser) : BrowserFormInputValue
      case pull.kind
      when .string?
        pull.read_string
      when .bool?
        pull.read_bool
      when .int?, .float?
        pull.read_float
      else
        raise JSON::ParseException.new("Expected String, Float64, or Bool for BrowserFormInputValue", *pull.location)
      end
    end

    def self.to_json(value : BrowserFormInputValue, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  struct BrowserCloseTabInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id")]
    getter tab_id : String

    def initialize(@tab_id : String)
    end
  end

  struct BrowserDoubleClickInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(emit_null: false)]
    getter modifiers : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @modifiers : String? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserFileUploadInput
    include JSON::Serializable
    getter target : BrowserRefTarget
    @[JSON::Field(key: "document_ids", emit_null: false)]
    getter document_ids : Array(String)?
    @[JSON::Field(emit_null: false)]
    getter paths : Array(String)?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(
      @target : BrowserRefTarget,
      @document_ids : Array(String)? = nil,
      @paths : Array(String)? = nil,
      @tab_id : String? = nil,
    )
    end
  end

  struct BrowserFindInput
    include JSON::Serializable
    getter query : String
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@query : String, @tab_id : String? = nil)
    end
  end

  struct BrowserFormInputInput
    include JSON::Serializable
    getter target : BrowserRefTarget
    @[JSON::Field(converter: Anthropic::BrowserFormInputValueConverter)]
    getter value : BrowserFormInputValue
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserRefTarget, @value : BrowserFormInputValue, @tab_id : String? = nil)
    end
  end

  struct BrowserGetPageTextInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@tab_id : String? = nil)
    end
  end

  struct BrowserHoldKeyInput
    include JSON::Serializable
    getter duration : Float64
    getter text : String
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@duration : Float64, @text : String, @tab_id : String? = nil)
    end
  end

  struct BrowserHoverInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserJavascriptExecInput
    include JSON::Serializable
    getter text : String
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@text : String, @tab_id : String? = nil)
    end
  end

  struct BrowserKeyInput
    include JSON::Serializable
    getter text : String
    @[JSON::Field(emit_null: false)]
    getter repeat : Int32?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@text : String, @repeat : Int32? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserLeftClickDragInput
    include JSON::Serializable
    getter from : BrowserCoordinateTarget
    getter target : BrowserCoordinateTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@from : BrowserCoordinateTarget, @target : BrowserCoordinateTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserLeftClickInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(emit_null: false)]
    getter modifiers : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @modifiers : String? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserLeftMouseDownInput
    include JSON::Serializable
    getter target : BrowserCoordinateTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserCoordinateTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserLeftMouseUpInput
    include JSON::Serializable
    getter target : BrowserCoordinateTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserCoordinateTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserListTabsInput
    include JSON::Serializable

    def initialize
    end
  end

  struct BrowserMiddleClickInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(emit_null: false)]
    getter modifiers : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @modifiers : String? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserMouseMoveInput
    include JSON::Serializable
    getter target : BrowserCoordinateTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserCoordinateTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserNavigateInput
    include JSON::Serializable
    getter url : String
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@url : String, @tab_id : String? = nil)
    end
  end

  struct BrowserNewTabInput
    include JSON::Serializable

    def initialize
    end
  end

  struct BrowserReadConsoleInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@tab_id : String? = nil)
    end
  end

  struct BrowserReadNetworkInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@tab_id : String? = nil)
    end
  end

  struct BrowserReadPageInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter depth : Int32?
    @[JSON::Field(emit_null: false)]
    getter filter : String?
    @[JSON::Field(emit_null: false)]
    getter ref : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(
      @depth : Int32? = nil,
      @filter : String? = nil,
      @ref : String? = nil,
      @tab_id : String? = nil,
    )
    end
  end

  struct BrowserRightClickInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(emit_null: false)]
    getter modifiers : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @modifiers : String? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserScreenshotInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@tab_id : String? = nil)
    end
  end

  struct BrowserScrollInput
    include JSON::Serializable
    @[JSON::Field(key: "scroll_direction")]
    getter scroll_direction : String
    getter target : BrowserCoordinateTarget
    @[JSON::Field(key: "scroll_amount", emit_null: false)]
    getter scroll_amount : Int32?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(
      @scroll_direction : String,
      @target : BrowserCoordinateTarget,
      @scroll_amount : Int32? = nil,
      @tab_id : String? = nil,
    )
    end
  end

  struct BrowserScrollToInput
    include JSON::Serializable
    getter target : BrowserRefTarget
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserRefTarget, @tab_id : String? = nil)
    end
  end

  struct BrowserSwitchTabInput
    include JSON::Serializable
    @[JSON::Field(key: "tab_id")]
    getter tab_id : String

    def initialize(@tab_id : String)
    end
  end

  struct BrowserTripleClickInput
    include JSON::Serializable
    @[JSON::Field(converter: Anthropic::BrowserClickTargetConverter)]
    getter target : BrowserClickTarget
    @[JSON::Field(emit_null: false)]
    getter modifiers : String?
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@target : BrowserClickTarget, @modifiers : String? = nil, @tab_id : String? = nil)
    end
  end

  struct BrowserTypeInput
    include JSON::Serializable
    getter text : String
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@text : String, @tab_id : String? = nil)
    end
  end

  struct BrowserWaitInput
    include JSON::Serializable
    getter duration : Float64
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@duration : Float64, @tab_id : String? = nil)
    end
  end

  struct BrowserZoomInput
    include JSON::Serializable
    getter region : Array(Int32)
    @[JSON::Field(key: "tab_id", emit_null: false)]
    getter tab_id : String?

    def initialize(@region : Array(Int32), @tab_id : String? = nil)
    end
  end

  alias BrowserActionInput = BrowserCloseTabInput |
                             BrowserDoubleClickInput |
                             BrowserFileUploadInput |
                             BrowserFindInput |
                             BrowserFormInputInput |
                             BrowserGetPageTextInput |
                             BrowserHoldKeyInput |
                             BrowserHoverInput |
                             BrowserJavascriptExecInput |
                             BrowserKeyInput |
                             BrowserLeftClickDragInput |
                             BrowserLeftClickInput |
                             BrowserLeftMouseDownInput |
                             BrowserLeftMouseUpInput |
                             BrowserListTabsInput |
                             BrowserMiddleClickInput |
                             BrowserMouseMoveInput |
                             BrowserNavigateInput |
                             BrowserNewTabInput |
                             BrowserReadConsoleInput |
                             BrowserReadNetworkInput |
                             BrowserReadPageInput |
                             BrowserRightClickInput |
                             BrowserScreenshotInput |
                             BrowserScrollInput |
                             BrowserScrollToInput |
                             BrowserSwitchTabInput |
                             BrowserTripleClickInput |
                             BrowserTypeInput |
                             BrowserWaitInput |
                             BrowserZoomInput

  struct ComputerCursorPositionInput
    include JSON::Serializable

    def initialize
    end
  end

  struct ComputerDoubleClickInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32)? = nil, @text : String? = nil)
    end
  end

  struct ComputerHoldKeyInput
    include JSON::Serializable
    getter duration : Int32
    getter text : String

    def initialize(@duration : Int32, @text : String)
    end
  end

  struct ComputerKeyInput
    include JSON::Serializable
    getter text : String
    @[JSON::Field(emit_null: false)]
    getter repeat : Int32?

    def initialize(@text : String, @repeat : Int32? = nil)
    end
  end

  struct ComputerLeftClickDragInput
    include JSON::Serializable
    getter coordinate : Array(Int32)
    @[JSON::Field(key: "start_coordinate")]
    getter start_coordinate : Array(Int32)
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32), @start_coordinate : Array(Int32), @text : String? = nil)
    end
  end

  struct ComputerLeftClickInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32)? = nil, @text : String? = nil)
    end
  end

  struct ComputerLeftMouseDownInput
    include JSON::Serializable

    def initialize
    end
  end

  struct ComputerLeftMouseUpInput
    include JSON::Serializable

    def initialize
    end
  end

  struct ComputerMiddleClickInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32)? = nil, @text : String? = nil)
    end
  end

  struct ComputerMouseMoveInput
    include JSON::Serializable
    getter coordinate : Array(Int32)

    def initialize(@coordinate : Array(Int32))
    end
  end

  struct ComputerRightClickInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32)? = nil, @text : String? = nil)
    end
  end

  struct ComputerScreenshotInput
    include JSON::Serializable

    def initialize
    end
  end

  struct ComputerScrollInput
    include JSON::Serializable
    @[JSON::Field(key: "scroll_amount")]
    getter scroll_amount : Int32
    @[JSON::Field(key: "scroll_direction")]
    getter scroll_direction : String
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(
      @scroll_amount : Int32,
      @scroll_direction : String,
      @coordinate : Array(Int32)? = nil,
      @text : String? = nil,
    )
    end
  end

  struct ComputerTripleClickInput
    include JSON::Serializable
    @[JSON::Field(emit_null: false)]
    getter coordinate : Array(Int32)?
    @[JSON::Field(emit_null: false)]
    getter text : String?

    def initialize(@coordinate : Array(Int32)? = nil, @text : String? = nil)
    end
  end

  struct ComputerTypeInput
    include JSON::Serializable
    getter text : String

    def initialize(@text : String)
    end
  end

  struct ComputerWaitInput
    include JSON::Serializable
    getter duration : Int32

    def initialize(@duration : Int32)
    end
  end

  struct ComputerZoomInput
    include JSON::Serializable
    getter region : Array(Int32)

    def initialize(@region : Array(Int32))
    end
  end

  alias ComputerActionInput = ComputerCursorPositionInput |
                              ComputerDoubleClickInput |
                              ComputerHoldKeyInput |
                              ComputerKeyInput |
                              ComputerLeftClickDragInput |
                              ComputerLeftClickInput |
                              ComputerLeftMouseDownInput |
                              ComputerLeftMouseUpInput |
                              ComputerMiddleClickInput |
                              ComputerMouseMoveInput |
                              ComputerRightClickInput |
                              ComputerScreenshotInput |
                              ComputerScrollInput |
                              ComputerTripleClickInput |
                              ComputerTypeInput |
                              ComputerWaitInput |
                              ComputerZoomInput

  # Helper for inspecting `ToolUseContent` calls emitted by `browser_toolset_20260801`.
  module BrowserToolUse
    alias CoordinateTarget = BrowserCoordinateTarget
    alias RefTarget = BrowserRefTarget
    alias ClickTarget = BrowserClickTarget
    alias ReadPageFilter = BrowserReadPageFilter
    alias ScrollDirection = ToolsetScrollDirection
    alias FormInputValue = BrowserFormInputValue

    alias CloseTabInput = BrowserCloseTabInput
    alias DoubleClickInput = BrowserDoubleClickInput
    alias FileUploadInput = BrowserFileUploadInput
    alias FindInput = BrowserFindInput
    alias FormInputInput = BrowserFormInputInput
    alias GetPageTextInput = BrowserGetPageTextInput
    alias HoldKeyInput = BrowserHoldKeyInput
    alias HoverInput = BrowserHoverInput
    alias JavascriptExecInput = BrowserJavascriptExecInput
    alias KeyInput = BrowserKeyInput
    alias LeftClickDragInput = BrowserLeftClickDragInput
    alias LeftClickInput = BrowserLeftClickInput
    alias LeftMouseDownInput = BrowserLeftMouseDownInput
    alias LeftMouseUpInput = BrowserLeftMouseUpInput
    alias ListTabsInput = BrowserListTabsInput
    alias MiddleClickInput = BrowserMiddleClickInput
    alias MouseMoveInput = BrowserMouseMoveInput
    alias NavigateInput = BrowserNavigateInput
    alias NewTabInput = BrowserNewTabInput
    alias ReadConsoleInput = BrowserReadConsoleInput
    alias ReadNetworkInput = BrowserReadNetworkInput
    alias ReadPageInput = BrowserReadPageInput
    alias RightClickInput = BrowserRightClickInput
    alias ScreenshotInput = BrowserScreenshotInput
    alias ScrollInput = BrowserScrollInput
    alias ScrollToInput = BrowserScrollToInput
    alias SwitchTabInput = BrowserSwitchTabInput
    alias TripleClickInput = BrowserTripleClickInput
    alias TypeInput = BrowserTypeInput
    alias WaitInput = BrowserWaitInput
    alias ZoomInput = BrowserZoomInput

    PARSERS = {
      "close_tab"       => ->(raw : String) { BrowserCloseTabInput.from_json(raw).as(BrowserActionInput) },
      "double_click"    => ->(raw : String) { BrowserDoubleClickInput.from_json(raw).as(BrowserActionInput) },
      "file_upload"     => ->(raw : String) { BrowserFileUploadInput.from_json(raw).as(BrowserActionInput) },
      "find"            => ->(raw : String) { BrowserFindInput.from_json(raw).as(BrowserActionInput) },
      "form_input"      => ->(raw : String) { BrowserFormInputInput.from_json(raw).as(BrowserActionInput) },
      "get_page_text"   => ->(raw : String) { BrowserGetPageTextInput.from_json(raw).as(BrowserActionInput) },
      "hold_key"        => ->(raw : String) { BrowserHoldKeyInput.from_json(raw).as(BrowserActionInput) },
      "hover"           => ->(raw : String) { BrowserHoverInput.from_json(raw).as(BrowserActionInput) },
      "javascript_exec" => ->(raw : String) { BrowserJavascriptExecInput.from_json(raw).as(BrowserActionInput) },
      "key"             => ->(raw : String) { BrowserKeyInput.from_json(raw).as(BrowserActionInput) },
      "left_click_drag" => ->(raw : String) { BrowserLeftClickDragInput.from_json(raw).as(BrowserActionInput) },
      "left_click"      => ->(raw : String) { BrowserLeftClickInput.from_json(raw).as(BrowserActionInput) },
      "left_mouse_down" => ->(raw : String) { BrowserLeftMouseDownInput.from_json(raw).as(BrowserActionInput) },
      "left_mouse_up"   => ->(raw : String) { BrowserLeftMouseUpInput.from_json(raw).as(BrowserActionInput) },
      "list_tabs"       => ->(raw : String) { BrowserListTabsInput.from_json(raw).as(BrowserActionInput) },
      "middle_click"    => ->(raw : String) { BrowserMiddleClickInput.from_json(raw).as(BrowserActionInput) },
      "mouse_move"      => ->(raw : String) { BrowserMouseMoveInput.from_json(raw).as(BrowserActionInput) },
      "navigate"        => ->(raw : String) { BrowserNavigateInput.from_json(raw).as(BrowserActionInput) },
      "new_tab"         => ->(raw : String) { BrowserNewTabInput.from_json(raw).as(BrowserActionInput) },
      "read_console"    => ->(raw : String) { BrowserReadConsoleInput.from_json(raw).as(BrowserActionInput) },
      "read_network"    => ->(raw : String) { BrowserReadNetworkInput.from_json(raw).as(BrowserActionInput) },
      "read_page"       => ->(raw : String) { BrowserReadPageInput.from_json(raw).as(BrowserActionInput) },
      "right_click"     => ->(raw : String) { BrowserRightClickInput.from_json(raw).as(BrowserActionInput) },
      "screenshot"      => ->(raw : String) { BrowserScreenshotInput.from_json(raw).as(BrowserActionInput) },
      "scroll"          => ->(raw : String) { BrowserScrollInput.from_json(raw).as(BrowserActionInput) },
      "scroll_to"       => ->(raw : String) { BrowserScrollToInput.from_json(raw).as(BrowserActionInput) },
      "switch_tab"      => ->(raw : String) { BrowserSwitchTabInput.from_json(raw).as(BrowserActionInput) },
      "triple_click"    => ->(raw : String) { BrowserTripleClickInput.from_json(raw).as(BrowserActionInput) },
      "type"            => ->(raw : String) { BrowserTypeInput.from_json(raw).as(BrowserActionInput) },
      "wait"            => ->(raw : String) { BrowserWaitInput.from_json(raw).as(BrowserActionInput) },
      "zoom"            => ->(raw : String) { BrowserZoomInput.from_json(raw).as(BrowserActionInput) },
    }

    def self.browser?(tool_use : ToolUseContent) : Bool
      tool_use.toolset_name == "browser"
    end

    def self.parse?(tool_use : ToolUseContent) : BrowserActionInput?
      if toolset = tool_use.toolset_name
        return nil unless toolset == "browser"
      end

      parser = PARSERS[tool_use.name]?
      return nil unless parser

      parser.call(tool_use.input.to_json)
    end

    def self.parse(tool_use : ToolUseContent) : BrowserActionInput
      if (toolset = tool_use.toolset_name) && toolset != "browser"
        raise ArgumentError.new("Expected browser toolset tool use, got toolset_name=#{toolset.inspect}")
      end

      parser = PARSERS[tool_use.name]? || raise ArgumentError.new("Unknown browser toolset action: #{tool_use.name.inspect}")
      parser.call(tool_use.input.to_json)
    end
  end

  # Helper for inspecting `ToolUseContent` calls emitted by `computer_toolset_20260801`.
  module ComputerToolUse
    alias ScrollDirection = ToolsetScrollDirection

    alias CursorPositionInput = ComputerCursorPositionInput
    alias DoubleClickInput = ComputerDoubleClickInput
    alias HoldKeyInput = ComputerHoldKeyInput
    alias KeyInput = ComputerKeyInput
    alias LeftClickDragInput = ComputerLeftClickDragInput
    alias LeftClickInput = ComputerLeftClickInput
    alias LeftMouseDownInput = ComputerLeftMouseDownInput
    alias LeftMouseUpInput = ComputerLeftMouseUpInput
    alias MiddleClickInput = ComputerMiddleClickInput
    alias MouseMoveInput = ComputerMouseMoveInput
    alias RightClickInput = ComputerRightClickInput
    alias ScreenshotInput = ComputerScreenshotInput
    alias ScrollInput = ComputerScrollInput
    alias TripleClickInput = ComputerTripleClickInput
    alias TypeInput = ComputerTypeInput
    alias WaitInput = ComputerWaitInput
    alias ZoomInput = ComputerZoomInput

    PARSERS = {
      "cursor_position" => ->(raw : String) { ComputerCursorPositionInput.from_json(raw).as(ComputerActionInput) },
      "double_click"    => ->(raw : String) { ComputerDoubleClickInput.from_json(raw).as(ComputerActionInput) },
      "hold_key"        => ->(raw : String) { ComputerHoldKeyInput.from_json(raw).as(ComputerActionInput) },
      "key"             => ->(raw : String) { ComputerKeyInput.from_json(raw).as(ComputerActionInput) },
      "left_click_drag" => ->(raw : String) { ComputerLeftClickDragInput.from_json(raw).as(ComputerActionInput) },
      "left_click"      => ->(raw : String) { ComputerLeftClickInput.from_json(raw).as(ComputerActionInput) },
      "left_mouse_down" => ->(raw : String) { ComputerLeftMouseDownInput.from_json(raw).as(ComputerActionInput) },
      "left_mouse_up"   => ->(raw : String) { ComputerLeftMouseUpInput.from_json(raw).as(ComputerActionInput) },
      "middle_click"    => ->(raw : String) { ComputerMiddleClickInput.from_json(raw).as(ComputerActionInput) },
      "mouse_move"      => ->(raw : String) { ComputerMouseMoveInput.from_json(raw).as(ComputerActionInput) },
      "right_click"     => ->(raw : String) { ComputerRightClickInput.from_json(raw).as(ComputerActionInput) },
      "screenshot"      => ->(raw : String) { ComputerScreenshotInput.from_json(raw).as(ComputerActionInput) },
      "scroll"          => ->(raw : String) { ComputerScrollInput.from_json(raw).as(ComputerActionInput) },
      "triple_click"    => ->(raw : String) { ComputerTripleClickInput.from_json(raw).as(ComputerActionInput) },
      "type"            => ->(raw : String) { ComputerTypeInput.from_json(raw).as(ComputerActionInput) },
      "wait"            => ->(raw : String) { ComputerWaitInput.from_json(raw).as(ComputerActionInput) },
      "zoom"            => ->(raw : String) { ComputerZoomInput.from_json(raw).as(ComputerActionInput) },
    }

    def self.computer?(tool_use : ToolUseContent) : Bool
      tool_use.toolset_name == "computer"
    end

    def self.parse?(tool_use : ToolUseContent) : ComputerActionInput?
      if toolset = tool_use.toolset_name
        return nil unless toolset == "computer"
      end

      parser = PARSERS[tool_use.name]?
      return nil unless parser

      parser.call(tool_use.input.to_json)
    end

    def self.parse(tool_use : ToolUseContent) : ComputerActionInput
      if (toolset = tool_use.toolset_name) && toolset != "computer"
        raise ArgumentError.new("Expected computer toolset tool use, got toolset_name=#{toolset.inspect}")
      end

      parser = PARSERS[tool_use.name]? || raise ArgumentError.new("Unknown computer toolset action: #{tool_use.name.inspect}")
      parser.call(tool_use.input.to_json)
    end
  end
end
