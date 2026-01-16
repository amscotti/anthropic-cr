module Anthropic
  # Base ToolChoice type
  abstract struct ToolChoice
    include JSON::Serializable
  end

  # Auto: Model decides whether to use tools
  struct ToolChoiceAuto < ToolChoice
    getter type : String = "auto"

    @[JSON::Field(key: "disable_parallel_tool_use")]
    getter disable_parallel_tool_use : Bool?

    def initialize(@disable_parallel_tool_use : Bool? = nil)
    end
  end

  # Any: Model must use any available tool
  struct ToolChoiceAny < ToolChoice
    getter type : String = "any"

    @[JSON::Field(key: "disable_parallel_tool_use")]
    getter disable_parallel_tool_use : Bool?

    def initialize(@disable_parallel_tool_use : Bool? = nil)
    end
  end

  # Tool: Model must use the specified tool
  struct ToolChoiceTool < ToolChoice
    getter type : String = "tool"
    getter name : String

    @[JSON::Field(key: "disable_parallel_tool_use")]
    getter disable_parallel_tool_use : Bool?

    def initialize(@name : String, @disable_parallel_tool_use : Bool? = nil)
    end
  end

  # None: Model must not use tools
  struct ToolChoiceNone < ToolChoice
    getter type : String = "none"

    def initialize
    end
  end
end
