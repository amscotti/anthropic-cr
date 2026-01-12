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
    tool.type.should eq("code_execution_20250522")
  end

  it "serializes to JSON" do
    tool = Anthropic::CodeExecutionTool.new
    json = tool.to_json
    json.should contain("code_execution_20250522")
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

# Helper struct for input_as test
struct SearchQueryInput
  include JSON::Serializable
  getter query : String
end
