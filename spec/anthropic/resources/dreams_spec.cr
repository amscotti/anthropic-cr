require "../../spec_helper"

describe Anthropic::BetaDreams do
  dream_json = %({
    "id":"dream_01abc",
    "archived_at":null,
    "created_at":"2026-04-21T12:00:00Z",
    "ended_at":null,
    "error":null,
    "inputs":[
      {"type":"memory_store","memory_store_id":"memstore_1"},
      {"type":"sessions","session_ids":["sess_1","sess_2"]}
    ],
    "instructions":"Consolidate project facts",
    "model":{"id":"claude-opus-4-7","speed":null},
    "outputs":[{"type":"memory_store","memory_store_id":"memstore_out"}],
    "session_id":"sess_dream_1",
    "status":"pending",
    "type":"dream",
    "usage":{
      "cache_creation_input_tokens":0,
      "cache_read_input_tokens":0,
      "input_tokens":0,
      "output_tokens":0
    }
  }).gsub(/\s+/, "")

  it "creates a dream with inputs, model string, and dreaming beta header" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams?beta=true", dream_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    dream = client.beta.dreams.create(
      inputs: [
        Anthropic::BetaDreamMemoryStoreInput.new("memstore_1"),
        Anthropic::BetaDreamSessionsInput.new(["sess_1", "sess_2"]),
      ],
      model: "claude-opus-4-7",
      instructions: "Consolidate project facts",
    )

    dream.id.should eq("dream_01abc")
    dream.status.should eq("pending")
    dream.pending?.should be_true
    dream.model.id.should eq("claude-opus-4-7")
    dream.inputs.size.should eq(2)
    dream.inputs[0].should be_a(Anthropic::BetaDreamMemoryStoreInput)
    dream.inputs[1].should be_a(Anthropic::BetaDreamSessionsInput)
    dream.outputs.first.memory_store_id.should eq("memstore_out")
    dream.usage.input_tokens.should eq(0)

    body = JSON.parse(capture.body.not_nil!)
    body["model"].as_s.should eq("claude-opus-4-7")
    body["instructions"].as_s.should eq("Consolidate project facts")
    body["inputs"].as_a.size.should eq(2)
    body["inputs"][0]["type"].as_s.should eq("memory_store")
    body["inputs"][0]["memory_store_id"].as_s.should eq("memstore_1")
    body["inputs"][1]["type"].as_s.should eq("sessions")
    body["inputs"][1]["session_ids"].as_a.map(&.as_s).should eq(["sess_1", "sess_2"])
    beta_header = capture.headers.not_nil!["anthropic-beta"]
    beta_header.should contain(Anthropic::DREAMING_BETA)
    beta_header.should contain("dreaming-2026-04-21")
    beta_header.should contain(Anthropic::MANAGED_AGENTS_BETA)
    beta_header.should contain("managed-agents-2026-04-01")
  end

  it "creates a dream with BetaDreamModelConfig model object" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams?beta=true", dream_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.beta.dreams.create(
      inputs: [Anthropic::BetaDreamMemoryStoreInput.new("memstore_1")],
      model: Anthropic::BetaDreamModelConfig.new("claude-opus-4-7", speed: "fast"),
    )

    body = JSON.parse(capture.body.not_nil!)
    body["model"]["id"].as_s.should eq("claude-opus-4-7")
    body["model"]["speed"].as_s.should eq("fast")
  end

  it "retrieves a dream by id" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/dreams/dream_01abc?beta=true")
      .to_return(body: dream_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    dream = client.beta.dreams.retrieve("dream_01abc")
    dream.id.should eq("dream_01abc")
    dream.session_id.should eq("sess_dream_1")
  end

  it "lists dreams with query params including statuses" do
    list_json = %({"data":[#{dream_json}],"next_page":null})
    capture = RequestCapture.new
    WebMock.stub(:get, /https:\/\/api\.anthropic\.com\/v1\/dreams\?beta=true/)
      .to_return do |request|
        capture.headers = request.headers
        capture.path = request.resource
        capture.method = request.method
        HTTP::Client::Response.new(200, body: list_json, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    response = client.beta.dreams.list(
      limit: 10,
      created_at_gt: "2026-01-01T00:00:00Z",
      statuses: ["pending", "running"],
    )

    response.data.size.should eq(1)
    response.data.first.id.should eq("dream_01abc")
    response.next_page.should be_nil
    capture.path.not_nil!.should contain("limit=10")
    capture.path.not_nil!.should contain("created_at%5Bgt%5D=")
    capture.path.not_nil!.should contain("statuses=pending")
    capture.path.not_nil!.should contain("statuses=running")
    capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::DREAMING_BETA)
  end

  it "archives a dream" do
    archived = dream_json.sub(%("archived_at":null), %("archived_at":"2026-04-22T00:00:00Z"))
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams/dream_01abc/archive?beta=true", archived)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    dream = client.beta.dreams.archive("dream_01abc")
    dream.archived_at.should eq("2026-04-22T00:00:00Z")
    capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::DREAMING_BETA)
  end

  it "cancels a dream" do
    canceled = dream_json.sub(%("status":"pending"), %("status":"canceled"))
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams/dream_01abc/cancel?beta=true", canceled)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    dream = client.beta.dreams.cancel("dream_01abc")
    dream.canceled?.should be_true
    capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::DREAMING_BETA)
  end

  it "merges extra betas with dreaming beta" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams?beta=true", dream_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.beta.dreams.create(
      inputs: [Anthropic::BetaDreamMemoryStoreInput.new("m1")],
      model: "claude-opus-4-7",
      betas: ["some-other-beta"],
    )

    header = capture.headers.not_nil!["anthropic-beta"]
    header.should contain("some-other-beta")
    header.should contain(Anthropic::DREAMING_BETA)
  end

  it "parses failed dream error detail" do
    failed_json = dream_json
      .sub(%("status":"pending"), %("status":"failed"))
      .sub(%("error":null), %("error":{"message":"upstream timeout","type":"api_error"}))
    WebMock.stub(:get, "https://api.anthropic.com/v1/dreams/dream_fail?beta=true")
      .to_return(body: failed_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    dream = client.beta.dreams.retrieve("dream_fail")
    dream.failed?.should be_true
    dream.error.not_nil!.message.should eq("upstream timeout")
    dream.error.not_nil!.type.should eq("api_error")
  end
end
