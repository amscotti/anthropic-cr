require "../../spec_helper"

describe Anthropic::WebSearchTool do
  it "creates with default values" do
    tool = Anthropic::WebSearchTool.new
    tool.type.should eq("web_search_20250305")
    tool.name.should eq("web_search")
    tool.allowed_domains.should be_nil
    tool.blocked_domains.should be_nil
  end

  it "creates with allowed domains" do
    tool = Anthropic::WebSearchTool.new(allowed_domains: ["example.com", "test.org"])
    tool.allowed_domains.should eq(["example.com", "test.org"])
  end

  it "creates with blocked domains" do
    tool = Anthropic::WebSearchTool.new(blocked_domains: ["spam.com"])
    tool.blocked_domains.should eq(["spam.com"])
  end

  it "creates with max_uses" do
    tool = Anthropic::WebSearchTool.new(max_uses: 5)
    tool.max_uses.should eq(5)
  end

  it "creates with user location" do
    location = Anthropic::UserLocation.new(city: "San Francisco", country: "US")
    tool = Anthropic::WebSearchTool.new(user_location: location)
    tool.user_location.should_not be_nil
    tool.user_location.not_nil!.city.should eq("San Francisco")
  end

  describe ".limited_to" do
    it "creates tool with allowed domains" do
      tool = Anthropic::WebSearchTool.limited_to("docs.example.com", "api.example.com")
      tool.allowed_domains.should eq(["docs.example.com", "api.example.com"])
    end
  end

  describe ".excluding" do
    it "creates tool with blocked domains" do
      tool = Anthropic::WebSearchTool.excluding("spam.com", "ads.com")
      tool.blocked_domains.should eq(["spam.com", "ads.com"])
    end
  end

  describe ".beta_header" do
    it "returns correct beta header" do
      Anthropic::WebSearchTool.beta_header.should eq("web-search-2025-03-05")
    end
  end

  it "serializes to JSON correctly" do
    tool = Anthropic::WebSearchTool.new(allowed_domains: ["example.com"])
    json = tool.to_json
    json.should contain("web_search_20250305")
    json.should contain("allowed_domains")
    json.should contain("example.com")
  end
end

describe Anthropic::UserLocation do
  it "creates with all fields" do
    location = Anthropic::UserLocation.new(
      city: "New York",
      region: "NY",
      country: "US",
      timezone: "America/New_York"
    )
    location.type.should eq("approximate")
    location.city.should eq("New York")
    location.region.should eq("NY")
    location.country.should eq("US")
    location.timezone.should eq("America/New_York")
  end

  it "serializes to JSON" do
    location = Anthropic::UserLocation.new(city: "London", country: "UK")
    json = location.to_json
    json.should contain("approximate")
    json.should contain("London")
  end
end

describe Anthropic::CodeExecutionTool do
  it "creates with correct type" do
    tool = Anthropic::CodeExecutionTool.new
    tool.type.should eq("code_execution_20250825")
  end

  it "serializes to JSON" do
    tool = Anthropic::CodeExecutionTool.new
    json = tool.to_json
    json.should contain("code_execution_20250825")
  end
end

describe Anthropic::BashTool do
  it "creates with correct type and name" do
    tool = Anthropic::BashTool.new
    tool.type.should eq("bash_20250124")
    tool.name.should eq("bash")
  end

  it "serializes to JSON" do
    tool = Anthropic::BashTool.new
    json = tool.to_json
    json.should contain("bash_20250124")
    json.should contain("bash")
  end
end

describe Anthropic::TextEditorTool do
  it "creates with correct type and name" do
    tool = Anthropic::TextEditorTool.new
    tool.type.should eq("text_editor_20250728")
    tool.name.should eq("str_replace_based_edit_tool")
  end

  it "creates with max_characters" do
    tool = Anthropic::TextEditorTool.new(max_characters: 100_000)
    tool.max_characters.should eq(100_000)
  end

  it "serializes to JSON" do
    tool = Anthropic::TextEditorTool.new(max_characters: 50_000)
    json = tool.to_json
    json.should contain("text_editor_20250728")
    json.should contain("str_replace_based_edit_tool")
    json.should contain("max_characters")
    json.should contain("50000")
  end

  it "omits max_characters when nil" do
    tool = Anthropic::TextEditorTool.new
    json = tool.to_json
    json.should_not contain("max_characters")
  end
end

describe Anthropic::ComputerUseTool do
  it "creates with required fields" do
    tool = Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080)
    tool.type.should eq("computer_20250124")
    tool.name.should eq("computer")
    tool.display_width_px.should eq(1920)
    tool.display_height_px.should eq(1080)
  end

  it "creates with optional fields" do
    tool = Anthropic::ComputerUseTool.new(
      display_width_px: 1920,
      display_height_px: 1080,
      display_number: 1,
      enable_zoom: true
    )
    tool.display_number.should eq(1)
    tool.enable_zoom.should eq(true)
  end

  it "serializes to JSON" do
    tool = Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080)
    json = tool.to_json
    json.should contain("computer_20250124")
    json.should contain("computer")
    json.should contain("display_width_px")
    json.should contain("1920")
    json.should contain("display_height_px")
    json.should contain("1080")
  end

  it "omits optional fields when nil" do
    tool = Anthropic::ComputerUseTool.new(display_width_px: 1920, display_height_px: 1080)
    json = tool.to_json
    json.should_not contain("display_number")
    json.should_not contain("enable_zoom")
  end
end

describe Anthropic::WebFetchTool do
  it "creates with default values" do
    tool = Anthropic::WebFetchTool.new
    tool.type.should eq("web_fetch_20250910")
    tool.name.should eq("web_fetch")
    tool.allowed_domains.should be_nil
    tool.blocked_domains.should be_nil
    tool.max_uses.should be_nil
    tool.max_content_tokens.should be_nil
  end

  it "creates with all options" do
    tool = Anthropic::WebFetchTool.new(
      max_uses: 5,
      allowed_domains: ["example.com"],
      blocked_domains: ["spam.com"],
      max_content_tokens: 10_000
    )
    tool.max_uses.should eq(5)
    tool.allowed_domains.should eq(["example.com"])
    tool.blocked_domains.should eq(["spam.com"])
    tool.max_content_tokens.should eq(10_000)
  end

  describe ".limited_to" do
    it "creates tool with allowed domains" do
      tool = Anthropic::WebFetchTool.limited_to("docs.example.com", "api.example.com")
      tool.allowed_domains.should eq(["docs.example.com", "api.example.com"])
    end
  end

  describe ".excluding" do
    it "creates tool with blocked domains" do
      tool = Anthropic::WebFetchTool.excluding("spam.com", "ads.com")
      tool.blocked_domains.should eq(["spam.com", "ads.com"])
    end
  end

  it "creates with citations" do
    tool = Anthropic::WebFetchTool.new(citations: Anthropic::CitationConfig.enable)
    tool.citations.should_not be_nil
    tool.citations.not_nil!.enabled?.should be_true
  end

  it "serializes citations to JSON" do
    tool = Anthropic::WebFetchTool.new(citations: Anthropic::CitationConfig.enable)
    json = tool.to_json
    json.should contain("citations")
    json.should contain("enabled")
  end

  it "serializes to JSON" do
    tool = Anthropic::WebFetchTool.new(allowed_domains: ["example.com"])
    json = tool.to_json
    json.should contain("web_fetch_20250910")
    json.should contain("web_fetch")
    json.should contain("allowed_domains")
    json.should contain("example.com")
  end

  it "omits nil fields" do
    tool = Anthropic::WebFetchTool.new
    json = tool.to_json
    json.should_not contain("max_uses")
    json.should_not contain("allowed_domains")
    json.should_not contain("blocked_domains")
    json.should_not contain("max_content_tokens")
    json.should_not contain("citations")
  end
end

describe Anthropic::MemoryTool do
  it "creates with correct type and name" do
    tool = Anthropic::MemoryTool.new
    tool.type.should eq("memory_20250818")
    tool.name.should eq("memory")
  end

  it "serializes to JSON" do
    tool = Anthropic::MemoryTool.new
    json = tool.to_json
    json.should contain("memory_20250818")
    json.should contain("memory")
  end
end

describe Anthropic::MCPTool do
  it "creates with required fields" do
    tool = Anthropic::MCPTool.new(
      name: "my_mcp",
      server_label: "My Server",
      server_url: "https://mcp.example.com"
    )
    tool.type.should eq("mcp_20250501")
    tool.name.should eq("my_mcp")
    tool.server_label.should eq("My Server")
    tool.server_url.should eq("https://mcp.example.com")
  end

  it "creates with allowed tools" do
    tool = Anthropic::MCPTool.new(
      name: "restricted_mcp",
      server_label: "Server",
      server_url: "https://mcp.example.com",
      allowed_tools: ["tool1", "tool2"]
    )
    tool.allowed_tools.should eq(["tool1", "tool2"])
  end

  it "serializes to JSON" do
    tool = Anthropic::MCPTool.new(
      name: "test",
      server_label: "Test",
      server_url: "https://test.com"
    )
    json = tool.to_json
    json.should contain("mcp_20250501")
    json.should contain("server_label")
    json.should contain("server_url")
  end
end

describe Anthropic::WebSearchResult do
  it "parses from JSON" do
    json = %({"url":"https://example.com","title":"Example","snippet":"A snippet","page_age":"2024-01-15"})
    result = Anthropic::WebSearchResult.from_json(json)

    result.url.should eq("https://example.com")
    result.title.should eq("Example")
    result.snippet.should eq("A snippet")
    result.page_age.should eq("2024-01-15")
  end

  it "handles optional fields" do
    json = %({"url":"https://example.com","title":"Example"})
    result = Anthropic::WebSearchResult.from_json(json)

    result.url.should eq("https://example.com")
    result.title.should eq("Example")
    result.snippet.should be_nil
    result.encrypted_content.should be_nil
  end
end

describe Anthropic::ServerToolUseContent do
  it "parses from JSON" do
    json = %({"type":"server_tool_use","id":"stu_123","name":"web_search","input":{"query":"test"}})
    content = Anthropic::ServerToolUseContent.from_json(json)

    content.type.should eq("server_tool_use")
    content.id.should eq("stu_123")
    content.name.should eq("web_search")
    content.input["query"].as_s.should eq("test")
    content.caller.should be_nil
  end

  it "parses caller field" do
    json = %({"type":"server_tool_use","id":"stu_123","name":"code_execution","input":{"code":"1+1"},"caller":"code_execution_20250825"})
    content = Anthropic::ServerToolUseContent.from_json(json)

    content.caller.should eq("code_execution_20250825")
  end

  describe "#input_as" do
    it "parses input into typed struct" do
      json = %({"type":"server_tool_use","id":"stu_123","name":"search","input":{"query":"crystal lang"}})
      content = Anthropic::ServerToolUseContent.from_json(json)

      typed = content.input_as(SearchQueryInput)
      typed.query.should eq("crystal lang")
    end
  end
end

describe Anthropic::WebSearchToolResultContent do
  it "parses from JSON" do
    json = %({"type":"web_search_tool_result","tool_use_id":"stu_123","content":[{"url":"https://example.com","title":"Result"}]})
    content = Anthropic::WebSearchToolResultContent.from_json(json)

    content.type.should eq("web_search_tool_result")
    content.tool_use_id.should eq("stu_123")
    content.content.size.should eq(1)
    content.content[0].url.should eq("https://example.com")
    content.content[0].title.should eq("Result")
  end
end

describe Anthropic::CodeExecutionToolResultContent do
  it "parses from JSON" do
    json = %({"type":"code_execution_tool_result","tool_use_id":"stu_ce_01","content":{"stdout":"2\\n","stderr":"","return_code":0}})
    content = Anthropic::CodeExecutionToolResultContent.from_json(json)

    content.type.should eq("code_execution_tool_result")
    content.tool_use_id.should eq("stu_ce_01")
    content.content["stdout"].as_s.should eq("2\n")
    content.content["return_code"].as_i.should eq(0)
  end
end

describe Anthropic::WebFetchToolResultContent do
  it "parses from JSON" do
    json = %({"type":"web_fetch_tool_result","tool_use_id":"stu_wf_01","content":{"html":"<p>Hello</p>"}})
    content = Anthropic::WebFetchToolResultContent.from_json(json)

    content.type.should eq("web_fetch_tool_result")
    content.tool_use_id.should eq("stu_wf_01")
    content.content["html"].as_s.should eq("<p>Hello</p>")
  end
end

describe Anthropic::MCPToolUseContent do
  it "parses from JSON" do
    json = %({"type":"mcp_tool_use","id":"mcp_tu_01","name":"get_data","server_name":"my_server","input":{"query":"test"}})
    content = Anthropic::MCPToolUseContent.from_json(json)

    content.type.should eq("mcp_tool_use")
    content.id.should eq("mcp_tu_01")
    content.name.should eq("get_data")
    content.server_name.should eq("my_server")
    content.input["query"].as_s.should eq("test")
  end

  describe "#input_as" do
    it "parses input into typed struct" do
      json = %({"type":"mcp_tool_use","id":"mcp_01","name":"search","server_name":"srv","input":{"query":"crystal"}})
      content = Anthropic::MCPToolUseContent.from_json(json)

      typed = content.input_as(SearchQueryInput)
      typed.query.should eq("crystal")
    end
  end
end

describe Anthropic::MCPToolResultContent do
  it "parses from JSON" do
    json = %({"type":"mcp_tool_result","tool_use_id":"mcp_tu_01","content":{"result":"data"},"is_error":false})
    content = Anthropic::MCPToolResultContent.from_json(json)

    content.type.should eq("mcp_tool_result")
    content.tool_use_id.should eq("mcp_tu_01")
    content.content["result"].as_s.should eq("data")
    content.is_error?.should be_false
  end

  it "parses error result" do
    json = %({"type":"mcp_tool_result","tool_use_id":"mcp_tu_02","content":{"error":"failed"},"is_error":true})
    content = Anthropic::MCPToolResultContent.from_json(json)

    content.is_error?.should be_true
  end
end

describe Anthropic::ToolSearchBM25Tool do
  it "creates with correct type and name" do
    tool = Anthropic::ToolSearchBM25Tool.new
    tool.type.should eq("tool_search_tool_bm25_20251119")
    tool.name.should eq("tool_search_tool_bm25")
  end

  it "serializes to JSON" do
    tool = Anthropic::ToolSearchBM25Tool.new
    json = tool.to_json
    json.should contain("tool_search_tool_bm25_20251119")
    json.should contain("tool_search_tool_bm25")
  end
end

describe Anthropic::ToolSearchRegexTool do
  it "creates with correct type and name" do
    tool = Anthropic::ToolSearchRegexTool.new
    tool.type.should eq("tool_search_tool_regex_20251119")
    tool.name.should eq("tool_search_tool_regex")
  end

  it "serializes to JSON" do
    tool = Anthropic::ToolSearchRegexTool.new
    json = tool.to_json
    json.should contain("tool_search_tool_regex_20251119")
    json.should contain("tool_search_tool_regex")
  end
end

describe Anthropic::MCPToolsetConfig do
  it "creates with default values" do
    config = Anthropic::MCPToolsetConfig.new
    config.enabled.should be_nil
    config.defer_loading.should be_nil
  end

  it "creates with all fields" do
    config = Anthropic::MCPToolsetConfig.new(enabled: true, defer_loading: false)
    config.enabled.should eq(true)
    config.defer_loading.should eq(false)
  end

  it "serializes to JSON" do
    config = Anthropic::MCPToolsetConfig.new(enabled: true)
    json = config.to_json
    json.should contain("enabled")
    json.should contain("true")
  end

  it "omits nil fields" do
    config = Anthropic::MCPToolsetConfig.new
    json = config.to_json
    json.should_not contain("enabled")
    json.should_not contain("defer_loading")
  end
end

describe Anthropic::MCPToolset do
  it "creates with required fields" do
    tool = Anthropic::MCPToolset.new(mcp_server_name: "my-server")
    tool.type.should eq("mcp_toolset")
    tool.mcp_server_name.should eq("my-server")
  end

  it "creates with all fields" do
    default_config = Anthropic::MCPToolsetConfig.new(enabled: true)
    configs = {"search_tool" => Anthropic::MCPToolsetConfig.new(defer_loading: true)}
    cache = Anthropic::CacheControl.ephemeral

    tool = Anthropic::MCPToolset.new(
      mcp_server_name: "data-server",
      default_config: default_config,
      configs: configs,
      cache_control: cache
    )

    tool.mcp_server_name.should eq("data-server")
    tool.default_config.not_nil!.enabled.should eq(true)
    tool.configs.not_nil!["search_tool"].defer_loading.should eq(true)
    tool.cache_control.not_nil!.type.should eq("ephemeral")
  end

  it "serializes to JSON correctly" do
    tool = Anthropic::MCPToolset.new(
      mcp_server_name: "my-server",
      default_config: Anthropic::MCPToolsetConfig.new(enabled: true)
    )
    json = tool.to_json
    parsed = JSON.parse(json)

    parsed["type"].as_s.should eq("mcp_toolset")
    parsed["mcp_server_name"].as_s.should eq("my-server")
    parsed["default_config"]["enabled"].as_bool.should eq(true)
  end

  it "omits nil optional fields" do
    tool = Anthropic::MCPToolset.new(mcp_server_name: "srv")
    json = tool.to_json
    json.should_not contain("default_config")
    json.should_not contain("configs")
    json.should_not contain("cache_control")
  end

  it "deserializes from JSON" do
    json = %({"type":"mcp_toolset","mcp_server_name":"deepwiki","default_config":{"enabled":true,"defer_loading":false}})
    tool = Anthropic::MCPToolset.from_json(json)
    tool.type.should eq("mcp_toolset")
    tool.mcp_server_name.should eq("deepwiki")
    tool.default_config.not_nil!.enabled.should eq(true)
    tool.default_config.not_nil!.defer_loading.should eq(false)
  end
end

describe Anthropic::BashToolLegacy do
  it "creates with correct type and name" do
    tool = Anthropic::BashToolLegacy.new
    tool.type.should eq("bash_20241022")
    tool.name.should eq("bash")
  end

  it "serializes to JSON" do
    tool = Anthropic::BashToolLegacy.new
    json = tool.to_json
    json.should contain("bash_20241022")
    json.should contain("bash")
  end
end

describe Anthropic::TextEditorToolLegacy do
  it "creates with correct type and name" do
    tool = Anthropic::TextEditorToolLegacy.new
    tool.type.should eq("text_editor_20241022")
    tool.name.should eq("str_replace_editor")
  end

  it "serializes to JSON" do
    tool = Anthropic::TextEditorToolLegacy.new
    json = tool.to_json
    json.should contain("text_editor_20241022")
    json.should contain("str_replace_editor")
  end
end

describe Anthropic::ComputerUseToolLegacy do
  it "creates with required fields" do
    tool = Anthropic::ComputerUseToolLegacy.new(display_width_px: 1024, display_height_px: 768)
    tool.type.should eq("computer_20241022")
    tool.name.should eq("computer")
    tool.display_width_px.should eq(1024)
    tool.display_height_px.should eq(768)
  end

  it "creates with optional display_number" do
    tool = Anthropic::ComputerUseToolLegacy.new(
      display_width_px: 1024,
      display_height_px: 768,
      display_number: 1
    )
    tool.display_number.should eq(1)
  end

  it "serializes to JSON" do
    tool = Anthropic::ComputerUseToolLegacy.new(display_width_px: 1024, display_height_px: 768)
    json = tool.to_json
    json.should contain("computer_20241022")
    json.should contain("computer")
    json.should contain("1024")
    json.should contain("768")
  end

  it "omits display_number when nil" do
    tool = Anthropic::ComputerUseToolLegacy.new(display_width_px: 1024, display_height_px: 768)
    json = tool.to_json
    json.should_not contain("display_number")
  end
end

# Helper struct for input_as test
struct SearchQueryInput
  include JSON::Serializable
  getter query : String
end
