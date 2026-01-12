require "../../spec_helper"

describe Anthropic::Models do
  describe "#list" do
    it "returns model list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=20")
        .to_return(body: Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.models.list

      result.should be_a(Anthropic::ModelListResponse)
      result.data.size.should eq(2)
    end

    it "parses model info correctly" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=20")
        .to_return(body: Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.models.list

      model = result.data[0]
      model.id.should eq("claude-sonnet-4-5-20250929")
      model.type.should eq("model")
      model.display_name.should eq("Claude Sonnet 4.5")
    end

    it "passes limit parameter" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=5")
        .to_return(body: Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.models.list(limit: 5)

      result.should be_a(Anthropic::ModelListResponse)
    end
  end

  describe "#retrieve" do
    it "returns specific model info" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-5-20250929")
        .to_return(body: Fixtures::Responses::MODEL_INFO)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      model = client.models.retrieve("claude-sonnet-4-5-20250929")

      model.id.should eq("claude-sonnet-4-5-20250929")
      model.display_name.should eq("Claude Sonnet 4.5")
    end
  end
end

describe Anthropic::ModelListResponse do
  describe "#auto_paging_all" do
    it "returns all models when no pagination" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=20")
        .to_return(body: Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      list = client.models.list
      all = list.auto_paging_all(client)

      all.should be_a(Array(Anthropic::ModelInfo))
      all.size.should eq(2)
    end
  end
end

describe Anthropic::Model do
  it "has model constants" do
    Anthropic::Model::CLAUDE_SONNET_4_5.should eq("claude-sonnet-4-5-20250929")
    Anthropic::Model::CLAUDE_OPUS_4_5.should eq("claude-opus-4-5-20251101")
    Anthropic::Model::CLAUDE_HAIKU_4_5.should eq("claude-haiku-4-5-20251001")
  end
end
