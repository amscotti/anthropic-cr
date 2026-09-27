require "../../spec_helper"

# Every beta resource that accepts workspace_id upstream must send the
# anthropic-workspace-id header. One call per swept resource/class.
describe "workspace_id header sweep" do
  it "sends workspace_id on deployments and deployment runs" do
    dep_json = %({"id":"dep_123","agent":{"id":"agent_123","version":1},"archived_at":null,"created_at":"2026-06-09T00:00:00Z","description":"nightly","environment_id":"env_123","initial_events":[],"metadata":{},"name":"Nightly summary","paused_reason":null,"resources":null,"schedule":null,"status":"active","type":"deployment","updated_at":"2026-06-09T00:00:00Z","vault_ids":["vault_1"]})
    run_json = %({"id":"drun_2","agent":{"id":"a"},"created_at":"","deployment_id":"dep_1","error":null,"session_id":null,"trigger_context":{"type":"schedule"},"type":"deployment_run"})

    dep_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/deployments/dep_123?beta=true", dep_json)
    run_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/deployment_runs/drun_2?beta=true", run_json)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.beta.deployments.retrieve("dep_123", workspace_id: "ws_1")
    client.beta.deployment_runs.retrieve("drun_2", workspace_id: "ws_1")

    dep_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    run_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end

  it "sends workspace_id on memory stores, memories, and versions" do
    store_json = %({"id":"store_123","name":"test-store","created_at":"","updated_at":""})
    mem_json = %({"id":"mem_123","path":"/test","content_sha256":"abc","content_size_bytes":100,"memory_store_id":"store_123","memory_version_id":"ver_123","created_at":"","updated_at":""})
    ver_json = %({"id":"ver_123","memory_id":"mem_123","memory_store_id":"store_123","operation":"create","created_at":""})

    store_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/memory_stores/store_123?beta=true", store_json)
    mem_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/memory_stores/store_123/memories/mem_123?beta=true", mem_json)
    ver_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/memory_stores/store_123/versions/ver_123?beta=true", ver_json)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.beta.memory_stores.retrieve("store_123", workspace_id: "ws_1")
    client.beta.memory_stores.memories.retrieve(memory_store_id: "store_123", memory_id: "mem_123", workspace_id: "ws_1")
    client.beta.memory_stores.memory_versions.retrieve(memory_store_id: "store_123", version_id: "ver_123", workspace_id: "ws_1")

    store_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    mem_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    ver_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end

  it "sends workspace_id on GA and beta models" do
    list_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)
    ret_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6?beta=true", Fixtures::Responses::BETA_MODEL_INFO)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.models.list(workspace_id: "ws_1")
    client.beta.models.retrieve("claude-sonnet-4-6", workspace_id: "ws_1")

    list_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    ret_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end

  it "sends workspace_id on tunnels and certificates" do
    tunnel_json = %({"id":"tnl_01","created_at":"","domain":"tnl.tunnels.anthropic.com","type":"tunnel"})
    cert_json = %({"id":"tcrt_01","created_at":"","expires_at":null,"fingerprint":"ab","tunnel_id":"tnl_01","type":"tunnel_certificate"})

    tunnel_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/tunnels/tnl_01?beta=true", tunnel_json)
    cert_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/tunnels/tnl_01/certificates/tcrt_01?beta=true", cert_json)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.beta.tunnels.retrieve("tnl_01", workspace_id: "ws_1")
    client.beta.tunnels.certificates.retrieve(tunnel_id: "tnl_01", certificate_id: "tcrt_01", workspace_id: "ws_1")

    tunnel_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    cert_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end

  it "sends workspace_id on user profiles" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/user_profiles/uprof_01abc?beta=true", Fixtures::Responses::USER_PROFILE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.beta.user_profiles.retrieve("uprof_01abc", workspace_id: "ws_1")

    capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end

  it "sends workspace_id on vaults and credentials" do
    vault_json = %({"id":"vault_123","display_name":"test-vault","type":"vault","metadata":{},"created_at":"","updated_at":""})
    cred_json = %({"id":"cred_123","vault_id":"vault_123","display_name":"my-cred","type":"credential","auth":{"type":"static_bearer"},"metadata":{},"created_at":"","updated_at":""})

    vault_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/vaults/vault_123?beta=true", vault_json)
    cred_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/vaults/vault_123/credentials/cred_123?beta=true", cred_json)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.beta.vaults.retrieve("vault_123", workspace_id: "ws_1")
    client.beta.vaults.credentials.retrieve(vault_id: "vault_123", credential_id: "cred_123", workspace_id: "ws_1")

    vault_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    cred_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
  end
end
