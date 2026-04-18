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
      model.id.should eq("claude-sonnet-4-6")
      model.type.should eq("model")
      model.display_name.should eq("Claude Sonnet 4.6")
      model.max_input_tokens.should eq(200_000)
      model.max_tokens.should eq(64_000)
      model.capabilities.should_not be_nil
      model.capabilities.not_nil!.thinking.supported?.should be_true
      model.capabilities.not_nil!.thinking.types.adaptive.supported?.should be_true
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
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6")
        .to_return(body: Fixtures::Responses::MODEL_INFO)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      model = client.models.retrieve("claude-sonnet-4-6")

      model.id.should eq("claude-sonnet-4-6")
      model.display_name.should eq("Claude Sonnet 4.6")
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
  it "has rolling alias constants for current default models" do
    Anthropic::Model::CLAUDE_OPUS.should eq("claude-opus-4-7")
    Anthropic::Model::CLAUDE_SONNET.should eq("claude-sonnet-4-6")
    Anthropic::Model::CLAUDE_HAIKU.should eq("claude-haiku-4-5")
  end

  it "has precise versioned model constants" do
    Anthropic::Model::CLAUDE_OPUS_4_7.should eq("claude-opus-4-7")
    Anthropic::Model::CLAUDE_MYTHOS_PREVIEW.should eq("claude-mythos-preview")
    Anthropic::Model::CLAUDE_OPUS_4_6.should eq("claude-opus-4-6")
    Anthropic::Model::CLAUDE_SONNET_4_6.should eq("claude-sonnet-4-6")
    Anthropic::Model::CLAUDE_OPUS_4_5.should eq("claude-opus-4-5-20251101")
    Anthropic::Model::CLAUDE_SONNET_4_5.should eq("claude-sonnet-4-5-20250929")
    Anthropic::Model::CLAUDE_OPUS_4_1.should eq("claude-opus-4-1-20250805")
    Anthropic::Model::CLAUDE_HAIKU_4_5.should eq("claude-haiku-4-5-20251001")
    Anthropic::Model::CLAUDE_OPUS_4.should eq("claude-opus-4-20250514")
    Anthropic::Model::CLAUDE_SONNET_4.should eq("claude-sonnet-4-20250514")
  end

  it "maps rolling aliases to the current precise defaults where applicable" do
    Anthropic::Model::CLAUDE_OPUS.should eq(Anthropic::Model::CLAUDE_OPUS_4_7)
    Anthropic::Model::CLAUDE_SONNET.should eq(Anthropic::Model::CLAUDE_SONNET_4_6)
  end

  it "maps :opus shorthand to Opus 4.7" do
    Anthropic.model_name(:opus).should eq("claude-opus-4-7")
  end

  it "maps :opus_4_7 shorthand to the precise 4.7 model id" do
    Anthropic.model_name(:opus_4_7).should eq("claude-opus-4-7")
  end

  it "maps :mythos shorthand to the mythos preview model id" do
    Anthropic.model_name(:mythos).should eq("claude-mythos-preview")
  end

  it "maps :opus_4_5 shorthand to Opus 4.5" do
    Anthropic.model_name(:opus_4_5).should eq("claude-opus-4-5-20251101")
  end
end
