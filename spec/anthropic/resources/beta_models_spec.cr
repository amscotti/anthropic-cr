require "../../spec_helper"

describe Anthropic::BetaModels do
  describe "#list" do
    it "lists beta models with beta headers" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?beta=true&limit=20", Fixtures::Responses::BETA_MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.beta.models.list(betas: ["custom-beta"])

      result.should be_a(Anthropic::BetaModelListResponse)
      result.data.size.should eq(2)
      capture.headers.not_nil!["anthropic-beta"].should eq("custom-beta")
    end
  end

  describe "#retrieve" do
    it "retrieves a beta model" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6?beta=true", Fixtures::Responses::BETA_MODEL_INFO)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      model = client.beta.models.retrieve("claude-sonnet-4-6", betas: ["custom-beta"])

      model.id.should eq("claude-sonnet-4-6")
      capture.headers.not_nil!["anthropic-beta"].should eq("custom-beta")
    end
  end
end

describe Anthropic::BetaModelListResponse do
  describe "#auto_paging_all" do
    it "auto-paginates beta model lists" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?beta=true&limit=20")
        .to_return(body: %({"data":[{"type":"model","id":"model1","display_name":"Model 1","created_at":"2025-01-01T00:00:00Z"}],"has_more":true,"first_id":"model1","last_id":"model1"}))

      WebMock.stub(:get, "https://api.anthropic.com/v1/models?beta=true&limit=20&after_id=model1")
        .to_return(body: %({"data":[{"type":"model","id":"model2","display_name":"Model 2","created_at":"2025-01-02T00:00:00Z"}],"has_more":false,"first_id":"model2","last_id":"model2"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      list = client.beta.models.list
      all = list.auto_paging_all(client)

      all.map(&.id).should eq(["model1", "model2"])
    end
  end
end
