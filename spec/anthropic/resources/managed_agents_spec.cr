require "../../spec_helper"

describe "Stateful Managed Agents APIs" do
  describe Anthropic::BetaEnvironments do
    it "creates an environment" do
      response_json = %({
        "id": "env_123",
        "name": "test-env",
        "type": "environment",
        "config": {
          "type": "cloud",
          "networking": {
            "type": "unrestricted"
          },
          "packages": {
            "apt": ["curl"],
            "cargo": [],
            "gem": [],
            "go": [],
            "npm": [],
            "pip": [],
            "type": "packages"
          }
        },
        "description": "My test env",
        "metadata": {"key": "val"},
        "scope": "account",
        "created_at": "2026-05-24T12:00:00Z",
        "updated_at": "2026-05-24T12:00:00Z",
        "archived_at": null
      })

      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/environments?beta=true", response_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      packages = Anthropic::BetaPackages.new(apt: ["curl"])
      net_config = Anthropic::BetaUnrestrictedNetwork.new
      config = Anthropic::BetaCloudConfig.new(net_config, packages)

      env = client.beta.environments.create(
        name: "test-env",
        config: config,
        description: "My test env",
        metadata: {"key" => "val"},
        scope: "account"
      )

      env.id.should eq("env_123")
      env.name.should eq("test-env")
      env.description.should eq("My test env")
      env.metadata["key"].should eq("val")
      env.scope.should eq("account")

      body = JSON.parse(capture.body.not_nil!)
      body["name"].as_s.should eq("test-env")
      body["scope"].as_s.should eq("account")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
    end

    it "retrieves, archives, and deletes an environment" do
      env_json = %({"id":"env_123","name":"test-env","config":{"type":"self_hosted"},"metadata":{},"created_at":"","updated_at":""})
      del_json = %({"id":"env_123","type":"environment_deleted"})

      stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123?beta=true", env_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/environments/env_123/archive?beta=true", env_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/environments/env_123?beta=true", del_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      env = client.beta.environments.retrieve("env_123")
      env.id.should eq("env_123")
      env.config.should be_a(Anthropic::BetaSelfHostedConfig)

      archived = client.beta.environments.archive("env_123")
      archived.id.should eq("env_123")

      deleted = client.beta.environments.delete("env_123")
      deleted.id.should eq("env_123")
      deleted.type.should eq("environment_deleted")
    end
  end

  describe Anthropic::BetaMemoryStores do
    it "manages memory stores, memories, and versions" do
      store_json = %({"id":"store_123","name":"test-store","created_at":"","updated_at":""})
      mem_json = %({"id":"mem_123","path":"/test","content_sha256":"abc","content_size_bytes":100,"memory_store_id":"store_123","memory_version_id":"ver_123","created_at":"","updated_at":""})
      ver_json = %({"id":"ver_123","memory_id":"mem_123","memory_store_id":"store_123","operation":"create","created_at":""})

      stub_and_capture(:post, "https://api.anthropic.com/v1/memory_stores?beta=true", store_json)
      mem_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/memory_stores/store_123/memories?beta=true", mem_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/memory_stores/store_123/versions/ver_123?beta=true", ver_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      store = client.beta.memory_stores.create(name: "test-store")
      store.id.should eq("store_123")

      memory = client.beta.memory_stores.memories.create(memory_store_id: "store_123", path: "/test", content: "hello")
      memory.id.should eq("mem_123")
      memory.memory_store_id.should eq("store_123")

      # All memory-stores requests carry the managed-agents AND agent-memory betas.
      mem_capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
      mem_capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::AGENT_MEMORY_BETA)

      version = client.beta.memory_stores.memory_versions.retrieve(memory_store_id: "store_123", version_id: "ver_123")
      version.id.should eq("ver_123")
      version.operation.should eq("create")
    end
  end

  describe Anthropic::BetaSessions do
    it "manages sessions and threads" do
      session_json = %({"id":"sess_123","environment_id":"env_123","vault_ids":[],"outcome_evaluations":[],"resources":[],"metadata":{},"created_at":"","updated_at":"","status":"idle","agent":{},"stats":{},"usage":{}})
      thread_json = %({"id":"thread_123","session_id":"sess_123","status":"running","created_at":"","updated_at":"","agent":{}})

      session_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions?beta=true", session_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123/threads?beta=true", thread_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      session = client.beta.sessions.create(
        environment_id: "env_123",
        agent: "agent_123",
        resources: [Anthropic::BetaManagedAgentsFileResourceParam.new(file_id: "file_123")]
      )
      session.id.should eq("sess_123")

      session_body = JSON.parse(session_capture.body.not_nil!)
      session_body["agent"].as_s.should eq("agent_123")
      session_body["resources"][0]["type"].as_s.should eq("file")
      session_body["resources"][0]["file_id"].as_s.should eq("file_123")

      thread = client.beta.sessions.threads.create(session_id: "sess_123", agent: JSON.parse("{}"))
      thread.id.should eq("thread_123")
      thread.session_id.should eq("sess_123")
      thread.status.should eq("running")
    end
  end

  describe Anthropic::BetaWebhooks do
    it "successfully unwraps and verifies verified webhook payloads" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      # Mock Standard Webhooks credentials
      key = "whsec_54321/abcde12345=="
      msg_id = "msg_id_999"
      msg_timestamp = Time.utc.to_unix.to_s
      payload = %({"id":"evt_123","created_at":"2026-05-24T12:00:00Z","type":"event","data":{"id":"sess_123","organization_id":"org_123","type":"session.created","workspace_id":"ws_123"}})

      # Compute valid expected Standard Webhooks HMAC signature
      key_clean = key[6..-1]
      key_bytes = Base64.decode(key_clean)
      to_sign = "#{msg_id}.#{msg_timestamp}.#{payload}"
      digest = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, to_sign)
      signature = Base64.strict_encode(digest)

      headers = {
        "webhook-id"          => msg_id,
        "webhook-timestamp"   => msg_timestamp,
        "x-webhook-signature" => "v1,#{signature}",
      }

      event = client.beta.webhooks.unwrap(payload: payload, headers: headers, key: key)
      event.id.should eq("evt_123")
      event.type.should eq("event")
      event.data["id"].as_s.should eq("sess_123")
      event.data["type"].as_s.should eq("session.created")
    end

    it "raises when signature verification fails" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      key = "whsec_54321/abcde12345=="
      msg_id = "msg_id_999"
      msg_timestamp = Time.utc.to_unix.to_s
      payload = %({"id":"evt_123","created_at":"","type":"event","data":{}})

      headers = {
        "webhook-id"        => msg_id,
        "webhook-timestamp" => msg_timestamp,
        "webhook-signature" => "v1,bad_sig_hash",
      }

      expect_raises(ArgumentError, "Webhook signature verification failed") do
        client.beta.webhooks.unwrap(payload: payload, headers: headers, key: key)
      end
    end

    it "raises when timestamp age exceeds 5 minutes tolerance limit" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      key = "whsec_54321/abcde12345=="
      msg_id = "msg_id_999"
      msg_timestamp = (Time.utc.to_unix - 350).to_s # 350 seconds ago (> 300 seconds threshold)
      payload = %({"id":"evt_123","created_at":"","type":"event","data":{}})

      headers = {
        "webhook-id"        => msg_id,
        "webhook-timestamp" => msg_timestamp,
        "webhook-signature" => "v1,sig",
      }

      expect_raises(ArgumentError, "Webhook timestamp is outside tolerance limits") do
        client.beta.webhooks.unwrap(payload: payload, headers: headers, key: key)
      end
    end
  end

  describe Anthropic::BetaAgents do
    it "creates, retrieves, updates, lists, and archives an agent" do
      agent_json = %({
        "id": "agent_123",
        "name": "My Agent",
        "type": "agent",
        "version": 1,
        "description": "My test agent",
        "metadata": {"key": "val"},
        "model": {"id": "claude-sonnet-4-6", "type": "model_config"},
        "system": "Pirate speak",
        "created_at": "2026-05-24T12:00:00Z",
        "updated_at": "2026-05-24T12:00:00Z",
        "archived_at": null
      })

      list_json = %({
        "data": [
          {
            "id": "agent_123",
            "name": "My Agent",
            "type": "agent",
            "version": 1,
            "metadata": {},
            "model": {"id": "claude-sonnet-4-6", "type": "model_config"},
            "created_at": "",
            "updated_at": "",
            "archived_at": null
          }
        ],
        "has_more": false
      })

      create_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents?beta=true", agent_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/agents/agent_123?beta=true", agent_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/agents/agent_123?beta=true", agent_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/agents?beta=true&limit=20", list_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/agents/agent_123/archive?beta=true", agent_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      # Create
      agent = client.beta.agents.create(
        model: :sonnet,
        name: "My Agent",
        description: "My test agent",
        metadata: {"key" => "val"},
        system: "Pirate speak"
      )
      agent.id.should eq("agent_123")
      agent.name.should eq("My Agent")
      agent.description.should eq("My test agent")
      agent.metadata.not_nil!["key"].should eq("val")
      agent.system_.should eq("Pirate speak")
      agent.version.should eq(1)

      create_body = JSON.parse(create_capture.body.not_nil!)
      create_body["model"].as_s.should eq("claude-sonnet-5")
      create_body["name"].as_s.should eq("My Agent")
      create_body["system"].as_s.should eq("Pirate speak")
      create_capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)

      # Retrieve
      retrieved = client.beta.agents.retrieve("agent_123")
      retrieved.id.should eq("agent_123")

      # Update
      updated = client.beta.agents.update("agent_123", version: 1, name: "New Name")
      updated.id.should eq("agent_123")

      # List
      list = client.beta.agents.list
      list.data.size.should eq(1)
      list.data.first.id.should eq("agent_123")
      list.has_more?.should be_false

      # Archive
      archived = client.beta.agents.archive("agent_123")
      archived.id.should eq("agent_123")
    end
  end

  describe Anthropic::BetaVaults do
    it "manages vaults, credentials, and validation" do
      vault_json = %({"id":"vault_123","display_name":"test-vault","type":"vault","metadata":{"k":"v"},"created_at":"","updated_at":"","archived_at":null})
      del_vault_json = %({"id":"vault_123","type":"vault_deleted"})
      cred_json = %({"id":"cred_123","vault_id":"vault_123","display_name":"my-cred","type":"credential","auth":{"type":"static_bearer"},"metadata":{},"created_at":"","updated_at":"","archived_at":null})
      del_cred_json = %({"id":"cred_123","type":"credential_deleted"})
      val_json = %({"status":"valid"})

      stub_and_capture(:post, "https://api.anthropic.com/v1/vaults?beta=true", vault_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/vaults/vault_123?beta=true", vault_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/vaults/vault_123?beta=true", del_vault_json)

      stub_and_capture(:post, "https://api.anthropic.com/v1/vaults/vault_123/credentials?beta=true", cred_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/vaults/vault_123/credentials/cred_123?beta=true", del_cred_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/vaults/vault_123/credentials/cred_123/mcp_oauth_validate?beta=true", val_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      # Vaults
      vault = client.beta.vaults.create(display_name: "test-vault", metadata: {"k" => "v"})
      vault.id.should eq("vault_123")
      vault.display_name.should eq("test-vault")
      vault.metadata.not_nil!["k"].should eq("v")

      retrieved_vault = client.beta.vaults.retrieve("vault_123")
      retrieved_vault.id.should eq("vault_123")

      deleted_vault = client.beta.vaults.delete("vault_123")
      deleted_vault.id.should eq("vault_123")
      deleted_vault.type.should eq("vault_deleted")

      # Credentials
      cred = client.beta.vaults.credentials.create(
        vault_id: "vault_123",
        auth: JSON.parse(%({"type":"static_bearer","token":"secret"})),
        display_name: "my-cred"
      )
      cred.id.should eq("cred_123")
      cred.vault_id.should eq("vault_123")

      deleted_cred = client.beta.vaults.credentials.delete(vault_id: "vault_123", credential_id: "cred_123")
      deleted_cred.id.should eq("cred_123")
      deleted_cred.type.should eq("credential_deleted")

      val = client.beta.vaults.credentials.mcp_oauth_validate(vault_id: "vault_123", credential_id: "cred_123")
      val.status.should eq("valid")
    end
  end
end
