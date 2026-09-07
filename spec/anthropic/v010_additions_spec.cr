require "../spec_helper"

# Coverage for the v0.10.0 API-parity additions: thinking display modes,
# workspace headers, user-profile fields, dream output behavior, session
# budgets, new model IDs, and error workspace helpers.
describe "v0.10.0 parity additions" do
  message_json = Fixtures::Responses::MESSAGE_BASIC

  it "attaches the thinking-display beta when display is set" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", message_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 64,
      thinking: Anthropic::ThinkingConfig.enabled(1600, display: Anthropic::ThinkingDisplay::UPDATES),
      messages: [{role: "user", content: "hi"}]
    )

    headers = capture.headers.not_nil!
    headers["anthropic-beta"].should contain("thinking-display-updates-2026-08-18")

    body = JSON.parse(capture.body.not_nil!)
    body["thinking"]["display"].as_s.should eq("updates")
  end

  it "omits the thinking-display beta when display is unset" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", message_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 64,
      thinking: Anthropic::ThinkingConfig.enabled(1600),
      messages: [{role: "user", content: "hi"}]
    )

    beta = capture.headers.not_nil!["anthropic-beta"]?
    (beta.nil? || !beta.includes?("thinking-display")).should be_true
  end

  it "sends the workspace header on GA message calls" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", message_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 16,
      workspace_id: "ws_123",
      messages: [{role: "user", content: "hi"}]
    )
    capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_123")
  end

  it "sends the workspace header on beta message calls" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", message_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.beta.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 16,
      workspace_id: "ws_456",
      messages: [{role: "user", content: "hi"}]
    )
    capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_456")
  end

  it "creates user profiles with access_type, name, and onboarding timestamp" do
    profile = %({"id":"uprof_1","type":"user_profile","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","metadata":{},"trust_grants":{},"external_id":"ext-1","access_type":"application","name":"Acme User","external_user_onboarded_at":"2026-01-02T00:00:00Z"})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles?beta=true", profile)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.user_profiles.create(
      external_id: "ext-1",
      access_type: Anthropic::UserProfileAccessType::APPLICATION,
      name: "Acme User",
      external_user_onboarded_at: "2026-01-02T00:00:00Z"
    )

    created.access_type.should eq("application")
    created.name.should eq("Acme User")
    created.external_user_onboarded_at.should eq("2026-01-02T00:00:00Z")

    sent = JSON.parse(capture.body.not_nil!)
    sent["access_type"].as_s.should eq("application")
  end

  it "lists user profiles with order_by" do
    list = %({"data":[],"has_more":false,"first_id":null,"last_id":null})
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/user_profiles?beta=true&limit=20&order_by=name", list)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    client.beta.user_profiles.list(order_by: "name")

    capture.path.not_nil!.should contain("order_by=name")
  end

  it "sends dream output_behavior on create and parses it back" do
    dream = %({"id":"dream_1","archived_at":null,"created_at":"2026-01-01T00:00:00Z","ended_at":null,"error":null,"inputs":[{"type":"memory_store","memory_store_id":"ms_1"}],"instructions":null,"model":{"id":"claude-opus-4-7"},"output_behavior":{"type":"update_existing","memory_store_id":"ms_out"},"outputs":[],"session_id":null,"status":"pending","type":"dream","usage":{"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"input_tokens":0,"output_tokens":0}})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/dreams?beta=true", dream)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.dreams.create(
      inputs: [Anthropic::BetaDreamMemoryStoreInput.new("ms_1")],
      model: "claude-opus-4-7",
      output_behavior: Anthropic::BetaDreamOutputBehaviorUpdateExisting.new("ms_out")
    )

    behavior = created.output_behavior
    behavior.should be_a(Anthropic::BetaDreamOutputBehaviorUpdateExisting)
    behavior.as(Anthropic::BetaDreamOutputBehaviorUpdateExisting).memory_store_id.should eq("ms_out")

    sent = JSON.parse(capture.body.not_nil!)
    sent["output_behavior"]["type"].as_s.should eq("update_existing")
    sent["output_behavior"]["memory_store_id"].as_s.should eq("ms_out")
  end

  it "sends session budgets on create" do
    session = %({"id":"sess_1","agent":{},"stats":{},"usage":{},"type":"session","status":"running","title":null,"environment_id":"env_1","vault_ids":[],"outcome_evaluations":[],"resources":[],"metadata":{},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","archived_at":null,"budget":{"max_list_cost":{"amount":"2500","currency":"USD"},"type":"limit"}})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions?beta=true", session)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.sessions.create(
      environment_id: "env_1",
      agent: "agent_1",
      budget: Anthropic::BetaManagedAgentsBudgetLimit.new(
        Anthropic::BetaMonetaryAmount.new("2500", "USD")
      )
    )

    budget = created.budget
    budget.should_not be_nil
    budget.not_nil!.max_list_cost.amount.should eq("2500")

    sent = JSON.parse(capture.body.not_nil!)
    sent["budget"]["max_list_cost"]["currency"].as_s.should eq("USD")
  end

  it "exposes the new model IDs" do
    Anthropic::Model::CLAUDE_FABLE_5_1.should eq("claude-fable-5-1")
    Anthropic::Model::CLAUDE_MYTHOS_5_1.should eq("claude-mythos-5-1")
    Anthropic.model_name(:fable_5_1).should eq("claude-fable-5-1")
    Anthropic.model_name(:mythos_5_1).should eq("claude-mythos-5-1")
  end

  it "exposes new beta header constants" do
    Anthropic::THINKING_DISPLAY_UPDATES_BETA.should eq("thinking-display-updates-2026-08-18")
    Anthropic::MID_CONVERSATION_TOOL_CHANGES_BETA.should eq("mid-conversation-tool-changes-2026-07-01")
    Anthropic::TASK_BUDGETS_BETA.should eq("task-budgets-2026-03-13")
    Anthropic::COMPACT_BETA.should eq("compact-2026-01-12")
    Anthropic::CE_USER_MANAGEMENT_BETA.should eq("ce-user-management-2026-07-13")
  end

  it "reads the workspace ID from API errors" do
    error = Anthropic::BadRequestError.new(
      "bad",
      400,
      "{}",
      HTTP::Headers{"anthropic-workspace-id" => "ws_9"}
    )
    error.workspace_id.should eq("ws_9")

    plain = Anthropic::BadRequestError.new("bad")
    plain.workspace_id.should be_nil
  end

  it "merges workspace headers centrally" do
    Anthropic.merge_workspace_header(nil, nil).should be_nil
    Anthropic.merge_workspace_header(nil, "ws_1").should eq({"anthropic-workspace-id" => "ws_1"})
    merged = Anthropic.merge_workspace_header({"a" => "b"}, "ws_1")
    merged.should eq({"a" => "b", "anthropic-workspace-id" => "ws_1"})
  end
end
