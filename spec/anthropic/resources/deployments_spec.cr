require "../../spec_helper"

# Specs for Managed Agents Deployments + Deployment Runs (v1.48 / v1.53 parity).
describe "Managed Agents Deployments" do
  describe Anthropic::BetaDeployments do
    it "creates a deployment and posts the expected body + beta header" do
      deployment_json = %({"id":"dep_123","agent":{"id":"agent_123","version":1},"archived_at":null,"created_at":"2026-06-09T00:00:00Z","description":"nightly","environment_id":"env_123","initial_events":[],"metadata":{},"name":"Nightly summary","paused_reason":null,"resources":null,"schedule":null,"status":"active","type":"deployment","updated_at":"2026-06-09T00:00:00Z","vault_ids":["vault_1"]})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/deployments?beta=true", deployment_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      deployment = client.beta.deployments.create(
        agent: "agent_123",
        environment_id: "env_123",
        name: "Nightly summary",
        description: "nightly",
        initial_events: [JSON.parse(%({"type":"user.message","content":[{"type":"text","text":"hi"}]}))],
        vault_ids: ["vault_1"],
      )

      deployment.id.should eq("dep_123")
      deployment.status.should eq("active")
      deployment.active?.should be_true
      deployment.environment_id.should eq("env_123")
      deployment.vault_ids.should eq(["vault_1"])

      body = JSON.parse(capture.body.not_nil!)
      body["agent"].as_s.should eq("agent_123")
      body["environment_id"].as_s.should eq("env_123")
      body["name"].as_s.should eq("Nightly summary")
      body["initial_events"][0]["type"].as_s.should eq("user.message")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
    end

    it "retrieves a deployment by id" do
      deployment_json = %({"id":"dep_123","agent":{"id":"agent_123"},"archived_at":null,"created_at":"","description":null,"environment_id":"env_123","initial_events":[],"metadata":{},"name":"D","paused_reason":null,"resources":null,"schedule":null,"status":"paused","type":"deployment","updated_at":"","vault_ids":[]})
      WebMock.stub(:get, "https://api.anthropic.com/v1/deployments/dep_123?beta=true")
        .to_return(body: deployment_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      deployment = client.beta.deployments.retrieve("dep_123")
      deployment.paused?.should be_true
    end

    it "lists deployments with query params" do
      list_json = %({"data":[],"has_more":false,"first_id":null,"last_id":null})
      WebMock.stub(:get, "https://api.anthropic.com/v1/deployments?beta=true&limit=20&status=active")
        .to_return(body: list_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response = client.beta.deployments.list(status: "active")
      response.data.size.should eq(0)
      response.has_more?.should be_false
    end

    it "archives / pauses / unpauses a deployment" do
      paused_json = %({"id":"dep_1","agent":{"id":"a"},"archived_at":null,"created_at":"","description":null,"environment_id":"e","initial_events":[],"metadata":{},"name":"n","paused_reason":{"type":"manual"},"resources":null,"schedule":null,"status":"paused","type":"deployment","updated_at":"","vault_ids":[]})
      active_json = %({"id":"dep_1","agent":{"id":"a"},"archived_at":null,"created_at":"","description":null,"environment_id":"e","initial_events":[],"metadata":{},"name":"n","paused_reason":null,"resources":null,"schedule":null,"status":"active","type":"deployment","updated_at":"","vault_ids":[]})
      archived_json = %({"id":"dep_1","agent":{"id":"a"},"archived_at":"2026-06-09T00:00:00Z","created_at":"","description":null,"environment_id":"e","initial_events":[],"metadata":{},"name":"n","paused_reason":null,"resources":null,"schedule":null,"status":"active","type":"deployment","updated_at":"","vault_ids":[]})

      WebMock.stub(:post, "https://api.anthropic.com/v1/deployments/dep_1/pause?beta=true").to_return(body: paused_json)
      WebMock.stub(:post, "https://api.anthropic.com/v1/deployments/dep_1/unpause?beta=true").to_return(body: active_json)
      WebMock.stub(:post, "https://api.anthropic.com/v1/deployments/dep_1/archive?beta=true").to_return(body: archived_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.deployments.pause("dep_1").paused?.should be_true
      client.beta.deployments.unpause("dep_1").active?.should be_true
      client.beta.deployments.archive("dep_1").archived_at.should eq("2026-06-09T00:00:00Z")
    end

    it "triggers a deployment run" do
      run_json = %({"id":"drun_1","agent":{"id":"a"},"created_at":"","deployment_id":"dep_1","error":null,"session_id":"sess_1","trigger_context":{"type":"manual"},"type":"deployment_run"})
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/deployments/dep_1/run?beta=true", run_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      run = client.beta.deployments.run("dep_1")
      run.session_id.should eq("sess_1")
      run.failed?.should be_false
      run.trigger_context["type"].as_s.should eq("manual")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
    end
  end

  describe Anthropic::BetaDeploymentRuns do
    it "retrieves a deployment run (with error)" do
      run_json = %({"id":"drun_2","agent":{"id":"a"},"created_at":"","deployment_id":"dep_1","error":{"type":"session_rate_limited"},"session_id":null,"trigger_context":{"type":"schedule"},"type":"deployment_run"})
      WebMock.stub(:get, "https://api.anthropic.com/v1/deployment_runs/drun_2?beta=true")
        .to_return(body: run_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      run = client.beta.deployment_runs.retrieve("drun_2")
      run.failed?.should be_true
      run.error.not_nil!["type"].as_s.should eq("session_rate_limited")
      run.session_id.should be_nil
    end

    it "lists deployment runs filtering by deployment_id" do
      list_json = %({"data":[],"has_more":false,"first_id":null,"last_id":null})
      WebMock.stub(:get, "https://api.anthropic.com/v1/deployment_runs?beta=true&limit=20&deployment_id=dep_1")
        .to_return(body: list_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response = client.beta.deployment_runs.list(deployment_id: "dep_1")
      response.data.size.should eq(0)
    end
  end
end
