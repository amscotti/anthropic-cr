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

    it "manages self-hosted work items" do
      work_json = %({"id":"work_1","acknowledged_at":null,"created_at":"","data":{"id":"sess_1","type":"session"},"environment_id":"env_123","latest_heartbeat_at":null,"metadata":{"k":"v"},"secret":"s3cr3t","started_at":null,"state":"queued","stop_requested_at":null,"stopped_at":null,"type":"work"})
      list_json = %({"data":[#{work_json}],"next_page":null})
      hb_json = %({"last_heartbeat":"","lease_extended":true,"state":"active","ttl_seconds":60,"type":"work_heartbeat"})
      stats_json = %({"depth":2,"oldest_queued_at":null,"pending":1,"type":"work_queue_stats","workers_polling":3})

      stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123/work/work_1?beta=true", work_json)
      update_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/environments/env_123/work/work_1?beta=true", work_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123/work?beta=true&limit=20", list_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/environments/env_123/work/work_1/ack?beta=true", work_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/environments/env_123/work/work_1/heartbeat?beta=true&desired_ttl_seconds=60", hb_json)
      poll_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123/work/poll?beta=true&block_ms=100", work_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123/work/stats?beta=true", stats_json)
      stop_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/environments/env_123/work/work_1/stop?beta=true", work_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      work = client.beta.environments.work

      retrieved = work.retrieve(work_id: "work_1", environment_id: "env_123")
      retrieved.id.should eq("work_1")
      retrieved.state.should eq("queued")
      retrieved.data.id.should eq("sess_1")
      retrieved.metadata["k"].should eq("v")
      retrieved.secret.should eq("s3cr3t")

      work.update(work_id: "work_1", environment_id: "env_123", metadata: {"k" => "v2", "old" => nil})
      update_body = JSON.parse(update_capture.body.not_nil!)
      update_body["metadata"]["k"].as_s.should eq("v2")
      update_body["metadata"]["old"].raw.should be_nil

      list = work.list(environment_id: "env_123")
      list.data.size.should eq(1)
      list.data[0].id.should eq("work_1")

      acked = work.ack(work_id: "work_1", environment_id: "env_123")
      acked.id.should eq("work_1")

      hb = work.heartbeat(work_id: "work_1", environment_id: "env_123", desired_ttl_seconds: 60)
      hb.lease_extended?.should be_true
      hb.ttl_seconds.should eq(60)

      polled = work.poll(environment_id: "env_123", block_ms: 100, anthropic_worker_id: "worker_1")
      polled.should_not be_nil
      polled.not_nil!.id.should eq("work_1")
      poll_capture.headers.not_nil!["anthropic-worker-id"].should eq("worker_1")

      stats = work.stats(environment_id: "env_123")
      stats.depth.should eq(2)
      stats.pending.should eq(1)
      stats.workers_polling.should eq(3)

      stopped = work.stop(work_id: "work_1", environment_id: "env_123", force: true)
      stopped.id.should eq("work_1")
      JSON.parse(stop_capture.body.not_nil!)["force"].as_bool.should be_true
    end

    it "returns nil when work poll finds nothing" do
      stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123/work/poll?beta=true", "")
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.environments.work.poll(environment_id: "env_123").should be_nil
    end

    it "sends workspace_id on environment calls" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/environments/env_123?beta=true", %({"id":"env_123","name":"e","config":{"type":"self_hosted"},"metadata":{},"created_at":"","updated_at":""}))
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.environments.retrieve("env_123", workspace_id: "ws_1")
      capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
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
      stub_and_capture(:get, "https://api.anthropic.com/v1/sessions/sess_123/threads/thread_123?beta=true", thread_json)

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

      thread = client.beta.sessions.threads.retrieve(session_id: "sess_123", thread_id: "thread_123")
      thread.id.should eq("thread_123")
      thread.session_id.should eq("sess_123")
      thread.status.should eq("running")
    end

    it "includes initial_events on session create" do
      session_json = %({"id":"sess_init","environment_id":"env_123","vault_ids":[],"outcome_evaluations":[],"resources":[],"metadata":{},"created_at":"","updated_at":"","status":"idle","agent":{},"stats":{},"usage":{}})
      session_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions?beta=true", session_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.sessions.create(
        environment_id: "env_123",
        agent: "agent_123",
        initial_events: [
          JSON.parse(%({"type":"user.message","content":[{"type":"text","text":"Hello"}]})),
        ],
      )

      body = JSON.parse(session_capture.body.not_nil!)
      body["initial_events"].as_a.size.should eq(1)
      body["initial_events"][0]["type"].as_s.should eq("user.message")
      body["initial_events"][0]["content"][0]["text"].as_s.should eq("Hello")
    end

    it "sends typed input events to a session" do
      send_json = %({"data":[{"type":"user.message","content":[{"type":"text","text":"Where is my order?"}]}]})
      send_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123/events?beta=true", send_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      events = [
        Anthropic::BetaSessionUserMessageEvent.message("Where is my order?"),
        Anthropic::BetaSessionUserInterruptEvent.new(session_thread_id: "thread_123"),
        Anthropic::BetaSessionUserToolConfirmationEvent.new(result: "allow", tool_use_id: "toolu_1"),
      ] of Anthropic::BetaSessionInputEvent

      response = client.beta.sessions.events.send(session_id: "sess_123", events: events)
      response["data"].as_a.size.should eq(1)
      response["data"][0]["type"].as_s.should eq("user.message")

      body = JSON.parse(send_capture.body.not_nil!)
      sent = body["events"].as_a
      sent.size.should eq(3)
      sent[0]["type"].as_s.should eq("user.message")
      sent[0]["content"][0]["type"].as_s.should eq("text")
      sent[0]["content"][0]["text"].as_s.should eq("Where is my order?")
      sent[1]["type"].as_s.should eq("user.interrupt")
      sent[1]["session_thread_id"].as_s.should eq("thread_123")
      sent[2]["type"].as_s.should eq("user.tool_confirmation")
      sent[2]["result"].as_s.should eq("allow")
      sent[2]["tool_use_id"].as_s.should eq("toolu_1")
    end

    it "serializes tool-result, outcome, and system input events" do
      tool_result = Anthropic::BetaSessionUserToolResultEvent.new(
        tool_use_id: "toolu_1",
        content: [Anthropic::BetaSessionTextBlock.new("done")] of Anthropic::BetaSessionEventContent,
        is_error: false
      )
      parsed = JSON.parse(tool_result.to_json)
      parsed["type"].as_s.should eq("user.tool_result")
      parsed["content"][0]["text"].as_s.should eq("done")
      parsed["is_error"].as_bool.should be_false

      custom_result = Anthropic::BetaSessionUserCustomToolResultEvent.new(custom_tool_use_id: "ctu_1")
      parsed = JSON.parse(custom_result.to_json)
      parsed["type"].as_s.should eq("user.custom_tool_result")
      parsed.as_h.has_key?("content").should be_false

      outcome = Anthropic::BetaSessionUserDefineOutcomeEvent.new(
        description: "Resolve the ticket",
        rubric: Anthropic::BetaSessionTextRubric.new("ticket closed"),
        max_iterations: 5
      )
      parsed = JSON.parse(outcome.to_json)
      parsed["type"].as_s.should eq("user.define_outcome")
      parsed["rubric"]["type"].as_s.should eq("text")
      parsed["max_iterations"].as_i.should eq(5)

      file_rubric = Anthropic::BetaSessionUserDefineOutcomeEvent.new(
        description: "Match the spec",
        rubric: Anthropic::BetaSessionFileRubric.new("file_1")
      )
      parsed = JSON.parse(file_rubric.to_json)
      parsed["rubric"]["type"].as_s.should eq("file")
      parsed["rubric"]["file_id"].as_s.should eq("file_1")
      parsed.as_h.has_key?("max_iterations").should be_false

      system = Anthropic::BetaSessionSystemMessageEvent.message("policy update")
      parsed = JSON.parse(system.to_json)
      parsed["type"].as_s.should eq("system.message")
      parsed["content"][0]["text"].as_s.should eq("policy update")
    end

    it "manages typed session resources" do
      file_json = %({"id":"res_1","created_at":"","file_id":"file_123","mount_path":"/mnt/f","type":"file","updated_at":""})
      list_json = %({"data":[
        {"id":"res_1","created_at":"","file_id":"file_123","mount_path":"/mnt/f","type":"file","updated_at":""},
        {"id":"res_2","created_at":"","mount_path":"/mnt/repo","type":"github_repository","updated_at":"","url":"https://github.com/org/repo","checkout":{"type":"branch","name":"main"}},
        {"memory_store_id":"store_1","type":"memory_store","access":"read_only","mount_path":"/mnt/mem","name":"kb"},
        {"id":"res_9","type":"future_thing","created_at":"","updated_at":""}
      ],"next_page":null})
      del_json = %({"id":"res_1","type":"session_resource_deleted"})

      stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123/resources?beta=true", file_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/sessions/sess_123/resources/res_1?beta=true", file_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123/resources/res_1?beta=true", file_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/sessions/sess_123/resources?beta=true&limit=20", list_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/sessions/sess_123/resources/res_1?beta=true", del_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")

      added = client.beta.sessions.resources.add_file(session_id: "sess_123", file_id: "file_123", mount_path: "/mnt/f")
      added.should be_a(Anthropic::BetaSessionFileResource)
      added.as(Anthropic::BetaSessionFileResource).file_id.should eq("file_123")

      retrieved = client.beta.sessions.resources.retrieve(session_id: "sess_123", resource_id: "res_1")
      retrieved.should be_a(Anthropic::BetaSessionFileResource)

      updated = client.beta.sessions.resources.update(session_id: "sess_123", resource_id: "res_1", authorization_token: "tok")
      updated.should be_a(Anthropic::BetaSessionFileResource)

      list = client.beta.sessions.resources.list(session_id: "sess_123")
      list.data.size.should eq(4)
      list.data[0].should be_a(Anthropic::BetaSessionFileResource)
      repo = list.data[1].as(Anthropic::BetaSessionGitHubRepositoryResource)
      repo.url.should eq("https://github.com/org/repo")
      checkout = repo.checkout.as(Anthropic::BetaManagedAgentsBranchCheckoutParam)
      checkout.name.should eq("main")
      store = list.data[2].as(Anthropic::BetaSessionMemoryStoreResource)
      store.memory_store_id.should eq("store_1")
      store.access.should eq("read_only")
      fallback = list.data[3].as(Anthropic::GenericSessionResource)
      fallback.type.should eq("future_thing")
      fallback.raw["id"].as_s.should eq("res_9")

      deleted = client.beta.sessions.resources.delete(session_id: "sess_123", resource_id: "res_1")
      deleted.id.should eq("res_1")
      deleted.type.should eq("session_resource_deleted")
    end

    it "sends workspace_id on events and thread calls" do
      events_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/sessions/sess_123/events?beta=true&limit=20", %({"data":[]}))
      thread_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/sessions/sess_123/threads?beta=true&limit=20", %({"data":[]}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.sessions.events.list(session_id: "sess_123", workspace_id: "ws_1")
      client.beta.sessions.threads.list(session_id: "sess_123", workspace_id: "ws_1")

      events_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
      thread_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    end

    it "updates sessions with metadata patches and vault ids" do
      session_json = %({"id":"sess_123","environment_id":"env_123","vault_ids":["vlt_1"],"outcome_evaluations":[],"resources":[],"metadata":{},"created_at":"","updated_at":"","status":"idle","agent":{},"stats":{},"usage":{}})
      update_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123?beta=true", session_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      session = client.beta.sessions.update(
        session_id: "sess_123",
        metadata: {"keep" => "v", "drop" => nil},
        vault_ids: ["vlt_1"]
      )
      session.id.should eq("sess_123")

      body = JSON.parse(update_capture.body.not_nil!)
      body["metadata"]["keep"].as_s.should eq("v")
      body["metadata"]["drop"].raw.should be_nil
      body["vault_ids"][0].as_s.should eq("vlt_1")
    end

    it "sends workspace_id on session list, delete, and archive" do
      list_capture = stub_and_capture(:get, "https://api.anthropic.com/v1/sessions?beta=true&limit=20", %({"data":[],"next_page":null,"prev_page":null}))
      del_capture = stub_and_capture(:delete, "https://api.anthropic.com/v1/sessions/sess_123?beta=true", %({"id":"sess_123","type":"session_deleted"}))
      session_json = %({"id":"sess_123","environment_id":"env_123","vault_ids":[],"outcome_evaluations":[],"resources":[],"metadata":{},"created_at":"","updated_at":"","status":"idle","agent":{},"stats":{},"usage":{}})
      arch_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/sessions/sess_123/archive?beta=true", session_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.sessions.list(workspace_id: "ws_1")
      client.beta.sessions.delete("sess_123", workspace_id: "ws_1")
      client.beta.sessions.archive("sess_123", workspace_id: "ws_1")

      list_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
      del_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
      arch_capture.headers.not_nil!["anthropic-workspace-id"].should eq("ws_1")
    end

    it "parses healthcheck work payloads" do
      work = Anthropic::BetaSelfHostedWork.from_json(%({
        "id": "work_9", "acknowledged_at": null, "created_at": "",
        "data": {"id": "hc_1", "type": "healthcheck"},
        "environment_id": "env_123", "latest_heartbeat_at": null,
        "metadata": {}, "secret": null, "started_at": null,
        "state": "queued", "stop_requested_at": null, "stopped_at": null,
        "type": "work"
      }))
      data = work.data.as(Anthropic::BetaHealthCheckWorkData)
      data.id.should eq("hc_1")
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

    it "parses payloads without verification" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      payload = %({"id":"evt_1","created_at":"","type":"event","data":{"id":"sess_1","organization_id":"org_1","type":"session.created","workspace_id":"ws_1"}})

      event = client.beta.webhooks.parse_unverified(payload)
      event.id.should eq("evt_1")
      event.event_type.should eq("session.created")
      event.session_event?.should be_true
    end

    it "falls back to the client webhook key" do
      key = "whsec_54321/abcde12345=="
      client = Anthropic::Client.new(api_key: "sk-ant-test", webhook_key: key)

      msg_id = "msg_id_1"
      msg_timestamp = Time.utc.to_unix.to_s
      payload = %({"id":"evt_2","created_at":"","type":"event","data":{}})

      key_bytes = Base64.decode(key[6..-1])
      digest = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, "#{msg_id}.#{msg_timestamp}.#{payload}")
      headers = {
        "webhook-id"        => msg_id,
        "webhook-timestamp" => msg_timestamp,
        "webhook-signature" => "v1,#{Base64.strict_encode(digest)}",
      }

      event = client.beta.webhooks.unwrap(payload: payload, headers: headers)
      event.id.should eq("evt_2")
    end

    it "falls back to ANTHROPIC_WEBHOOK_SIGNING_KEY" do
      key = "whsec_54321/abcde12345=="
      ENV["ANTHROPIC_WEBHOOK_SIGNING_KEY"] = key
      begin
        client = Anthropic::Client.new(api_key: "sk-ant-test")
        client.webhook_key.should eq(key)

        msg_id = "msg_id_2"
        msg_timestamp = Time.utc.to_unix.to_s
        payload = %({"id":"evt_3","created_at":"","type":"event","data":{}})

        key_bytes = Base64.decode(key[6..-1])
        digest = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, "#{msg_id}.#{msg_timestamp}.#{payload}")
        headers = {
          "webhook-id"        => msg_id,
          "webhook-timestamp" => msg_timestamp,
          "webhook-signature" => "v1,#{Base64.strict_encode(digest)}",
        }

        event = client.beta.webhooks.unwrap(payload: payload, headers: headers)
        event.id.should eq("evt_3")
      ensure
        ENV.delete("ANTHROPIC_WEBHOOK_SIGNING_KEY")
      end
    end

    it "prefers the explicit key over the client key" do
      good_key = "whsec_54321/abcde12345=="
      client = Anthropic::Client.new(api_key: "sk-ant-test", webhook_key: "whsec_wrongkeyAAAAAAAAAA==")

      msg_id = "msg_id_3"
      msg_timestamp = Time.utc.to_unix.to_s
      payload = %({"id":"evt_4","created_at":"","type":"event","data":{}})

      key_bytes = Base64.decode(good_key[6..-1])
      digest = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, "#{msg_id}.#{msg_timestamp}.#{payload}")
      headers = {
        "webhook-id"        => msg_id,
        "webhook-timestamp" => msg_timestamp,
        "webhook-signature" => "v1,#{Base64.strict_encode(digest)}",
      }

      event = client.beta.webhooks.unwrap(payload: payload, headers: headers, key: good_key)
      event.id.should eq("evt_4")
    end
  end

  describe Anthropic::BetaAgents do
    it "lists agent versions" do
      list_json = %({
        "data": [
          {
            "id": "agent_123",
            "name": "My Agent",
            "type": "agent",
            "version": 2,
            "model": {"id": "claude-sonnet-4-6", "type": "model_config"},
            "created_at": "",
            "updated_at": "",
            "archived_at": null
          }
        ],
        "next_page": null
      })
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/agents/agent_123/versions?beta=true&limit=20", list_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      versions = client.beta.agents.versions.list("agent_123")

      versions.data.size.should eq(1)
      versions.data.first.version.should eq(2)
      versions.next_page.should be_nil
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MANAGED_AGENTS_BETA)
    end

    it "creates agents with typed toolsets and parses toolset responses" do
      agent_json = %({
        "id": "agent_ts", "name": "TS Agent", "type": "agent", "version": 1,
        "model": {"id": "claude-sonnet-4-6", "type": "model_config"},
        "tools": [
          {
            "type": "agent_toolset_20260401",
            "configs": [
              {"enabled": true, "name": "bash", "permission_policy": {"type": "always_ask"}, "type": "bash"}
            ],
            "default_config": {"enabled": true, "permission_policy": {"type": "auto"}}
          },
          {
            "type": "mcp_toolset", "mcp_server_name": "files",
            "configs": [
              {"enabled": false, "name": "read_file", "permission_policy": {"type": "always_allow"}}
            ],
            "default_config": {"enabled": true, "permission_policy": {"type": "always_allow"}}
          }
        ],
        "created_at": "", "updated_at": "", "archived_at": null
      })
      create_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents?beta=true", agent_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      agent = client.beta.agents.create(
        model: :sonnet,
        name: "TS Agent",
        tools: [
          Anthropic::BetaManagedAgentsAgentToolset20260401Params.new(
            configs: [
              Anthropic::BetaManagedAgentsAgentToolConfigParams.new(
                name: Anthropic::BetaManagedAgentsAgentToolName::BASH,
                permission_policy: Anthropic::BetaManagedAgentsPermissionPolicy.new(
                  Anthropic::BetaManagedAgentsPermissionPolicyType::ALWAYS_ASK
                )
              ),
            ],
            default_config: Anthropic::BetaManagedAgentsToolsetDefaultConfigParams.new(
              permission_policy: Anthropic::BetaManagedAgentsPermissionPolicy.new(
                Anthropic::BetaManagedAgentsPermissionPolicyType::AUTO
              )
            )
          ),
          Anthropic::BetaManagedAgentsMCPToolsetParams.new(mcp_server_name: "files"),
        ] of Anthropic::BetaManagedAgentsToolsetParam
      )

      body = JSON.parse(create_capture.body.not_nil!)
      body["tools"][0]["type"].as_s.should eq("agent_toolset_20260401")
      body["tools"][0]["configs"][0]["name"].as_s.should eq("bash")
      body["tools"][0]["configs"][0]["permission_policy"]["type"].as_s.should eq("always_ask")
      body["tools"][0]["default_config"]["permission_policy"]["type"].as_s.should eq("auto")
      body["tools"][1]["type"].as_s.should eq("mcp_toolset")
      body["tools"][1]["mcp_server_name"].as_s.should eq("files")

      toolsets = agent.tools.not_nil!
      toolsets.size.should eq(2)
      builtin = toolsets[0].as(Anthropic::BetaManagedAgentsAgentToolset20260401)
      builtin.configs[0].name.should eq("bash")
      builtin.configs[0].enabled?.should be_true
      builtin.default_config.permission_policy.type.should eq("auto")
      mcp = toolsets[1].as(Anthropic::BetaManagedAgentsMCPToolset)
      mcp.mcp_server_name.should eq("files")
      mcp.configs[0].enabled?.should be_false
    end

    it "updates agents with toolsets and custom tools" do
      agent_json = %({
        "id": "agent_ts", "name": "TS Agent", "type": "agent", "version": 2,
        "model": {"id": "claude-sonnet-4-6", "type": "model_config"},
        "tools": [
          {
            "type": "custom", "name": "get_weather",
            "description": "Look up the weather",
            "input_schema": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}
          },
          {
            "type": "agent_toolset_20260401",
            "configs": [
              {"enabled": true, "name": "web_fetch", "permission_policy": {"type": "auto"}, "type": "web_fetch",
               "allowed_domains": ["example.com"], "max_content_tokens": 5000},
              {"enabled": true, "name": "web_search", "permission_policy": {"type": "auto"}, "type": "web_search",
               "user_location": {"type": "approximate", "city": "Paris", "country": "FR"}}
            ],
            "default_config": {"enabled": true, "permission_policy": {"type": "auto"}}
          }
        ],
        "created_at": "", "updated_at": "", "archived_at": null
      })
      update_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents/agent_ts?beta=true", agent_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      updated = client.beta.agents.update(
        "agent_ts",
        version: 1,
        tools: [
          Anthropic::BetaManagedAgentsCustomTool.new(
            description: "Look up the weather",
            input_schema: Anthropic::BetaManagedAgentsCustomToolInputSchema.new(
              properties: {"city" => JSON.parse(%({"type":"string"}))},
              required: ["city"]
            ),
            name: "get_weather"
          ),
        ] of Anthropic::BetaManagedAgentsToolsetParam
      )

      body = JSON.parse(update_capture.body.not_nil!)
      body["tools"][0]["type"].as_s.should eq("custom")
      body["tools"][0]["input_schema"]["required"][0].as_s.should eq("city")

      toolsets = updated.tools.not_nil!
      custom = toolsets[0].as(Anthropic::BetaManagedAgentsCustomTool)
      custom.name.should eq("get_weather")
      custom.input_schema.required.should eq(["city"])
      fetch = toolsets[1].as(Anthropic::BetaManagedAgentsAgentToolset20260401)
      fetch.configs[0].allowed_domains.should eq(["example.com"])
      fetch.configs[0].max_content_tokens.should eq(5000)
      fetch.configs[1].user_location.not_nil!.city.should eq("Paris")
    end

    it "raises a clear error for unknown toolset types" do
      expect_raises(JSON::ParseException, "Unknown toolset type") do
        Anthropic::BetaManagedAgentsToolsetConverter.from_json(JSON::PullParser.new(%({"type":"future_toolset"})))
      end
    end

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
        "next_page": null
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
      list.next_page.should be_nil

      # Archive
      archived = client.beta.agents.archive("agent_123")
      archived.id.should eq("agent_123")
    end

    it "creates an agent with model config effort and speed" do
      agent_json = %({
        "id": "agent_cfg",
        "name": "Config Agent",
        "type": "agent",
        "version": 1,
        "model": {"id": "claude-sonnet-5", "effort": {"type": "high"}, "speed": "fast"},
        "created_at": "2026-05-24T12:00:00Z",
        "updated_at": "2026-05-24T12:00:00Z",
        "archived_at": null
      })

      create_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents?beta=true", agent_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      agent = client.beta.agents.create(
        model: Anthropic::BetaManagedAgentsModelConfig.new(
          id: :sonnet,
          effort: "high",
          speed: "fast",
        ),
        name: "Config Agent",
      )
      agent.id.should eq("agent_cfg")

      body = JSON.parse(create_capture.body.not_nil!)
      body["model"]["id"].as_s.should eq("claude-sonnet-5")
      body["model"]["effort"].as_s.should eq("high")
      body["model"]["speed"].as_s.should eq("fast")
    end

    it "creates an agent with effort as typed object" do
      agent_json = %({
        "id": "agent_obj",
        "name": "Obj Agent",
        "type": "agent",
        "version": 1,
        "model": {"id": "claude-sonnet-5", "effort": {"type": "xhigh"}},
        "created_at": "",
        "updated_at": "",
        "archived_at": null
      })

      create_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents?beta=true", agent_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.agents.create(
        model: Anthropic::BetaManagedAgentsModelConfig.new(
          id: "claude-sonnet-5",
          effort: Anthropic::BetaManagedAgentsEffort.xhigh,
        ),
        name: "Obj Agent",
      )

      body = JSON.parse(create_capture.body.not_nil!)
      body["model"]["effort"]["type"].as_s.should eq("xhigh")
    end

    it "updates an agent model config" do
      agent_json = %({
        "id": "agent_123",
        "name": "My Agent",
        "type": "agent",
        "version": 2,
        "model": {"id": "claude-sonnet-5", "effort": {"type": "medium"}, "speed": "standard"},
        "created_at": "",
        "updated_at": "",
        "archived_at": null
      })

      update_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/agents/agent_123?beta=true", agent_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.agents.update(
        "agent_123",
        version: 1,
        model: Anthropic::BetaManagedAgentsModelConfig.new(
          id: :sonnet,
          effort: Anthropic::BetaManagedAgentsEffort.medium,
          speed: "standard",
        ),
      )

      body = JSON.parse(update_capture.body.not_nil!)
      body["version"].as_i.should eq(1)
      body["model"]["id"].as_s.should eq("claude-sonnet-5")
      body["model"]["effort"]["type"].as_s.should eq("medium")
      body["model"]["speed"].as_s.should eq("standard")
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
