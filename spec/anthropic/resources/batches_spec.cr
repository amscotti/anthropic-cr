require "../../spec_helper"

describe Anthropic::Batches do
  describe "#create" do
    it "creates a batch" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
        .to_return(body: Fixtures::Responses::BATCH_CREATED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      batch = client.messages.batches.create(
        requests: [
          Anthropic::BatchRequest.new(
            custom_id: "req-1",
            params: Anthropic::BatchRequestParams.new(
              model: "claude-haiku-4-5-20251001",
              max_tokens: 100,
              messages: [Anthropic::MessageParam.user("2+2=?")],
            )
          ),
        ]
      )

      batch.id.should eq("msgbatch_01abc")
      batch.processing_status.should eq("in_progress")
    end
  end

  describe "#retrieve" do
    it "retrieves batch status" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/msgbatch_01abc")
        .to_return(body: Fixtures::Responses::BATCH_COMPLETED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      batch = client.messages.batches.retrieve("msgbatch_01abc")

      batch.id.should eq("msgbatch_01abc")
      batch.processing_status.should eq("ended")
      batch.request_counts.succeeded.should eq(2)
    end
  end

  describe "#list" do
    it "lists batches" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?limit=20")
        .to_return(body: Fixtures::Responses::BATCH_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.messages.batches.list

      result.data.size.should eq(1)
      result.data[0].id.should eq("msgbatch_01abc")
    end

    it "passes limit parameter" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?limit=5")
        .to_return(body: Fixtures::Responses::BATCH_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.messages.batches.list(limit: 5)

      result.should be_a(Anthropic::BatchListResponse)
    end
  end

  describe "#cancel" do
    it "cancels a batch" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches/msgbatch_01abc/cancel")
        .to_return(body: Fixtures::Responses::BATCH_CREATED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      batch = client.messages.batches.cancel("msgbatch_01abc")

      batch.id.should eq("msgbatch_01abc")
    end
  end

  describe "#delete" do
    it "deletes a batch" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/msgbatch_01abc")
        .to_return(body: %({"id":"msgbatch_01abc","type":"message_batch_deleted"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.messages.batches.delete("msgbatch_01abc")

      result.id.should eq("msgbatch_01abc")
      result.type.should eq("message_batch_deleted")
    end
  end
end

describe Anthropic::BatchResponse do
  it "parses batch response" do
    batch = Anthropic::BatchResponse.from_json(Fixtures::Responses::BATCH_COMPLETED)

    batch.id.should eq("msgbatch_01abc")
    batch.type.should eq("message_batch")
    batch.processing_status.should eq("ended")
    batch.request_counts.succeeded.should eq(2)
    batch.request_counts.errored.should eq(0)
    batch.results_url.should_not be_nil
  end

  describe "processing_status" do
    it "is 'ended' for completed batch" do
      batch = Anthropic::BatchResponse.from_json(Fixtures::Responses::BATCH_COMPLETED)
      batch.processing_status.should eq("ended")
    end

    it "is 'in_progress' for new batch" do
      batch = Anthropic::BatchResponse.from_json(Fixtures::Responses::BATCH_CREATED)
      batch.processing_status.should eq("in_progress")
    end
  end
end

describe Anthropic::BatchRequest do
  it "creates batch request with params" do
    request = Anthropic::BatchRequest.new(
      custom_id: "my-request",
      params: Anthropic::BatchRequestParams.new(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hello")],
      )
    )

    request.custom_id.should eq("my-request")
    json = request.to_json
    json.should contain("my-request")
  end
end
