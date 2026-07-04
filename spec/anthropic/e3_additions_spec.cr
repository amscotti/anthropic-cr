require "../spec_helper"

# Specs for Phase E3: vault credential injection scoping, networking, and
# webhook event classification helpers.
describe "Phase E3 additions" do
  describe Anthropic::InjectionLocation do
    it "serializes body/header scopes" do
      loc = Anthropic::InjectionLocation.new(body: true, header: false)
      parsed = JSON.parse(loc.to_json)
      parsed["body"].as_bool.should be_true
      parsed["header"].as_bool.should be_false
    end

    it "omits nil scopes" do
      parsed = JSON.parse(Anthropic::InjectionLocation.new(header: true).to_json)
      parsed.as_h.has_key?("body").should be_false
      parsed["header"].as_bool.should be_true
    end
  end

  describe Anthropic::CredentialNetworking do
    it "builds an unrestricted networking config" do
      net = Anthropic::CredentialNetworking.unrestricted
      parsed = JSON.parse(net.to_json)
      parsed["type"].as_s.should eq("unrestricted")
    end

    it "builds a limited networking config with allowed_hosts" do
      net = Anthropic::CredentialNetworking.limited(["api.example.com", "*.internal.io"])
      parsed = JSON.parse(net.to_json)
      parsed["type"].as_s.should eq("limited")
      parsed["allowed_hosts"].as_a.map(&.as_s).should eq(["api.example.com", "*.internal.io"])
    end
  end

  describe "BetaVaultsCredentials injection scoping wiring" do
    it "posts injection_location and networking on credential create" do
      cred_json = %({"id":"cred_1","vault_id":"vault_1","auth":{"type":"environment_variable","name":"API_KEY"},"display_name":"key","metadata":{},"created_at":"","updated_at":""})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/vaults/vault_1/credentials?beta=true", cred_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.vaults.credentials.create(
        vault_id: "vault_1",
        auth: JSON.parse(%({"type":"environment_variable","name":"API_KEY"})),
        display_name: "key",
        injection_location: Anthropic::InjectionLocation.new(header: true),
        networking: Anthropic::CredentialNetworking.limited(["api.example.com"]),
      )

      body = JSON.parse(capture.body.not_nil!)
      body["injection_location"]["header"].as_bool.should be_true
      body["networking"]["type"].as_s.should eq("limited")
      body["networking"]["allowed_hosts"][0].as_s.should eq("api.example.com")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
    end
  end

  describe "BetaWebhookEvent classification" do
    it "parses a deployment webhook event and classifies it" do
      json = %({"id":"wh_1","created_at":"2026-07-01T00:00:00Z","type":"deployment.created","data":{"id":"dep_1","organization_id":"org","workspace_id":"ws","type":"deployment"}})
      event = Anthropic::BetaWebhookEvent.from_json(json)

      event.type.should eq("deployment.created")
      event.deployment_event?.should be_true
      event.deployment_run_event?.should be_false
      event.agent_event?.should be_false
      event.data["id"].as_s.should eq("dep_1")
    end

    it "classifies agent and deployment_run events" do
      agent_event = Anthropic::BetaWebhookEvent.from_json(%({"id":"wh_2","created_at":"","type":"agent.created","data":{}}))
      run_event = Anthropic::BetaWebhookEvent.from_json(%({"id":"wh_3","created_at":"","type":"deployment_run.failed","data":{}}))

      agent_event.agent_event?.should be_true
      run_event.deployment_run_event?.should be_true
    end

    it "exposes the EventType vocabulary" do
      Anthropic::BetaWebhookEvent::EventType::AGENT_CREATED.should eq("agent.created")
      Anthropic::BetaWebhookEvent::EventType::DEPLOYMENT_RUN_SUCCEEDED.should eq("deployment_run.succeeded")
    end
  end
end
