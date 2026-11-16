require "../spec_helper"

describe "v0.12.0 UserProfiles, Webhooks, Managed Agents, and Tunnels parity" do
  describe "GA UserProfiles (client.user_profiles)" do
    it "creates, retrieves, updates, lists, creates action URLs, and deletes without beta header" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      full_profile = %({
        "id": "uprof_01",
        "access_type": "passthrough",
        "created_at": "2026-10-21T00:00:00Z",
        "updated_at": "2026-10-21T01:00:00Z",
        "type": "user_profile",
        "metadata": {"tier": "enterprise"},
        "name": "Acme Corp",
        "external_user_details": {
          "account_status": "active",
          "entity_type": "business",
          "country": "US",
          "email_hash": "ehash",
          "name_hash": "nhash",
          "onboarded_at": "2026-10-01T00:00:00Z",
          "reference_id": "ext_acme_1"
        },
        "enforcement_status": "restricted",
        "enforcement_actions": [
          {
            "id": "enac_1",
            "action": "verify",
            "expires_at": "2026-11-01T00:00:00Z",
            "opened_at": "2026-10-20T00:00:00Z",
            "reason": "fraud_or_abuse",
            "type": "restriction"
          },
          {
            "id": "enac_2",
            "opened_at": "2026-10-19T00:00:00Z",
            "reason": "high_harm",
            "type": "ban"
          },
          {
            "id": "enac_3",
            "opened_at": "2026-10-18T00:00:00Z",
            "reason": "unspecified",
            "type": "custom_audit"
          }
        ],
        "programs": {
          "cyber": {
            "requirements": {"data_retention": true, "human_review": false},
            "status": "active",
            "tiers": {"tier_1": {"status": "active"}}
          },
          "efs": {
            "status": "pending",
            "features": {"priority_queue": {"status": "pending"}}
          }
        }
      })

      create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles", full_profile)
      created = client.user_profiles.create(
        access_type: Anthropic::UserProfileAccessType::PASSTHROUGH,
        external_user_details: Anthropic::UserProfileExternalUserDetails.new(
          account_status: Anthropic::UserProfileExternalUserAccountStatus::ACTIVE,
          entity_type: Anthropic::UserProfileExternalUserEntityType::BUSINESS,
          country: "US",
          reference_id: "ext_acme_1",
        ),
        metadata: {"tier" => "enterprise"},
        name: "Acme Corp",
        workspace_id: "wrkspc_1",
      )

      create_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false
      create_cap.headers.not_nil!["anthropic-workspace-id"].should eq("wrkspc_1")
      req_body = JSON.parse(create_cap.body.not_nil!)
      req_body["access_type"].as_s.should eq("passthrough")
      req_body["name"].as_s.should eq("Acme Corp")
      req_body["external_user_details"]["reference_id"].as_s.should eq("ext_acme_1")

      created.id.should eq("uprof_01")
      created.access_type.should eq("passthrough")
      created.name.should eq("Acme Corp")
      created.external_user_details.reference_id.should eq("ext_acme_1")
      created.enforcement_status.should eq(Anthropic::UserProfileEnforcementStatus::RESTRICTED)
      created.enforcement_actions.size.should eq(3)
      created.enforcement_actions[0].should be_a(Anthropic::UserProfileEnforcementActionRestriction)
      created.enforcement_actions[0].as(Anthropic::UserProfileEnforcementActionRestriction).action.should eq("verify")
      created.enforcement_actions[1].should be_a(Anthropic::UserProfileEnforcementActionBan)
      created.enforcement_actions[2].should be_a(Anthropic::GenericUserProfileEnforcementAction)
      created.programs.cyber.not_nil!.requirements.not_nil!.data_retention?.should be_true
      created.programs.cyber.not_nil!.requirements.not_nil!.human_review?.should be_false
      created.programs.cyber.not_nil!.tiers["tier_1"].status.should eq("active")
      created.programs.efs.not_nil!.features["priority_queue"].status.should eq("pending")

      get_cap = stub_and_capture(:get, "https://api.anthropic.com/v1/user_profiles/uprof_01", full_profile)
      retrieved = client.user_profiles.retrieve("uprof_01")
      retrieved.id.should eq("uprof_01")
      get_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      update_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles/uprof_01", full_profile)
      client.user_profiles.update("uprof_01", name: JSON::Any.new(nil), metadata: {"tier" => "pro"})
      update_body = JSON.parse(update_cap.body.not_nil!)
      update_body["name"].raw.should be_nil
      update_body["metadata"]["tier"].as_s.should eq("pro")
      update_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      list_json = %({"data":[#{full_profile}],"next_page":"page_2"})
      list_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/user_profiles?limit=10&order=desc&order_by=created_at&page=page_1&enforcement_status[]=restricted&enforcement_status[]=banned",
        list_json
      )
      list = client.user_profiles.list(
        enforcement_status: [Anthropic::UserProfileEnforcementStatus::RESTRICTED, Anthropic::UserProfileEnforcementStatus::BANNED],
        limit: 10,
        order: Anthropic::UserProfileListOrder::DESC,
        order_by: Anthropic::UserProfileListOrderBy::CREATED_AT,
        page: "page_1",
      )
      list.data.size.should eq(1)
      list.has_next_page?.should be_true
      list.next_page.should eq("page_2")
      list_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      action_cap = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/user_profiles/uprof_01/action_urls",
        %({"type":"user_profile_action_url","url":"https://claude.ai/action/123","expires_at":"2026-10-21T02:00:00Z"})
      )
      action_url = client.user_profiles.action_urls.create("uprof_01", action: Anthropic::UserProfileEnrollEndUserAction.new)
      action_url.url.should eq("https://claude.ai/action/123")
      action_url.type.should eq("user_profile_action_url")
      JSON.parse(action_cap.body.not_nil!)["action"]["type"].as_s.should eq("enroll_end_user")
      action_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      # Also accept hash action argument
      WebMock.reset
      stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/user_profiles/uprof_01/action_urls",
        %({"type":"user_profile_action_url","url":"https://claude.ai/action/456","expires_at":"2026-10-21T02:00:00Z"})
      )
      client.user_profiles.action_urls.create("uprof_01", action: {"type" => "enroll_end_user"}).url.should eq("https://claude.ai/action/456")

      del_cap = stub_and_capture(:delete, "https://api.anthropic.com/v1/user_profiles/uprof_01", %({"id":"uprof_01","type":"user_profile_deleted"}))
      deleted = client.user_profiles.delete("uprof_01")
      deleted.id.should eq("uprof_01")
      deleted.type.should eq("user_profile_deleted")
      del_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false
    end

    it "validates and URL-encodes user_profile_id path segments" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      expect_raises(ArgumentError) { client.user_profiles.retrieve("") }
      expect_raises(ArgumentError) { client.user_profiles.update("..", name: "x") }
      expect_raises(ArgumentError) { client.user_profiles.delete("..;x") }
      expect_raises(ArgumentError) { client.user_profiles.action_urls.create(";bar", action: Anthropic::UserProfileEnrollEndUserAction.new) }

      cap = stub_and_capture(:delete, "https://api.anthropic.com/v1/user_profiles/a%2Fb", %({"id":"a/b","type":"user_profile_deleted"}))
      client.user_profiles.delete("a/b").id.should eq("a/b")
      cap.path.should eq("/v1/user_profiles/a%2Fb")
    end
  end

  describe "Beta UserProfiles (client.beta.user_profiles)" do
    it "supports delete, action_urls.create, enforcement_status filter, name/access_type, and legacy/full deserialization" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      legacy_json = %({
        "id": "uprof_legacy",
        "type": "user_profile",
        "created_at": "2026-08-18T00:00:00Z",
        "updated_at": "2026-08-18T00:00:00Z",
        "metadata": {},
        "trust_grants": {"cyber": {"status": "active"}},
        "external_id": "legacy_1"
      })
      legacy = Anthropic::BetaUserProfile.from_json(legacy_json)
      legacy.id.should eq("uprof_legacy")
      legacy.enforcement_status.should be_nil
      legacy.enforcement_actions.should be_nil
      legacy.programs.should be_nil

      full_beta_json = %({
        "id": "uprof_beta",
        "type": "user_profile",
        "created_at": "2026-10-21T00:00:00Z",
        "updated_at": "2026-10-21T00:00:00Z",
        "access_type": "application",
        "name": "Beta User",
        "metadata": {},
        "trust_grants": {},
        "enforcement_status": "unrestricted",
        "enforcement_actions": [],
        "programs": {"cyber": {"status": "pending", "tiers": {}}}
      })

      create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/user_profiles", full_beta_json)
      created = client.beta.user_profiles.create(
        access_type: "application",
        name: "Beta User",
        external_user_details: Anthropic::BetaUserProfileExternalUserDetails.new(reference_id: "ref_1"),
      )
      beta_header = create_cap.headers.not_nil!["anthropic-beta"]
      beta_header.should contain(Anthropic::USER_PROFILES_BETA)
      beta_header.should contain(Anthropic::USER_PROFILES_2026_09_04_BETA)
      created.enforcement_status.should eq("unrestricted")
      created.enforcement_actions.should eq([] of Anthropic::UserProfileEnforcementAction)
      created.programs.not_nil!.cyber.not_nil!.status.should eq("pending")

      list_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/user_profiles?limit=20&enforcement_status[]=pending",
        %({"data":[#{full_beta_json}],"next_page":null})
      )
      listed = client.beta.user_profiles.list(enforcement_status: ["pending"])
      listed.data.size.should eq(1)
      list_cap.headers.not_nil!["anthropic-beta"].should contain(Anthropic::USER_PROFILES_BETA)

      action_cap = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/user_profiles/uprof_beta/action_urls",
        %({"type":"user_profile_action_url","url":"https://claude.ai/beta-action/1","expires_at":"2026-10-21T02:00:00Z"})
      )
      action_res = client.beta.user_profiles.action_urls.create("uprof_beta", action: Anthropic::BetaUserProfileEnrollEndUserAction.new)
      action_res.url.should eq("https://claude.ai/beta-action/1")
      action_cap.headers.not_nil!["anthropic-beta"].should contain(Anthropic::USER_PROFILES_BETA)

      del_cap = stub_and_capture(:delete, "https://api.anthropic.com/v1/user_profiles/uprof_beta", %({"id":"uprof_beta","type":"user_profile_deleted"}))
      deleted = client.beta.user_profiles.delete("uprof_beta")
      deleted.type.should eq("user_profile_deleted")
      del_cap.headers.not_nil!["anthropic-beta"].should contain(Anthropic::USER_PROFILES_BETA)
    end
  end

  describe "Webhook user_profile.* events" do
    it "parses enforcement_action_opened, enforcement_action_resolved, and program_status_updated events" do
      opened_json = %({
        "id": "wh_1",
        "created_at": "2026-10-21T00:00:00Z",
        "type": "event",
        "data": {
          "id": "uprof_1",
          "enforcement_action_id": "enac_1",
          "organization_id": "org_1",
          "type": "user_profile.enforcement_action_opened"
        }
      })
      opened = Anthropic::BetaWebhookEvent.from_json(opened_json)
      opened.event_type.should eq(Anthropic::BetaWebhookEvent::EventType::USER_PROFILE_ENFORCEMENT_ACTION_OPENED)
      opened.user_profile_event?.should be_true
      opened.session_event?.should be_false
      parsed_opened = opened.parsed_user_profile_data.as(Anthropic::BetaWebhookUserProfileEnforcementActionOpenedEventData)
      parsed_opened.enforcement_action_id.should eq("enac_1")
      parsed_opened.organization_id.should eq("org_1")

      resolved_json = %({
        "id": "wh_2",
        "created_at": "2026-10-21T00:00:00Z",
        "type": "event",
        "data": {
          "id": "uprof_1",
          "enforcement_action_id": "enac_1",
          "organization_id": "org_1",
          "type": "user_profile.enforcement_action_resolved"
        }
      })
      resolved = Anthropic::BetaWebhookEvent.from_json(resolved_json)
      resolved.user_profile_event?.should be_true
      resolved.parsed_user_profile_data.should be_a(Anthropic::BetaWebhookUserProfileEnforcementActionResolvedEventData)

      prog_json = %({
        "id": "wh_3",
        "created_at": "2026-10-21T00:00:00Z",
        "type": "event",
        "data": {
          "id": "uprof_1",
          "organization_id": "org_1",
          "type": "user_profile.program_status_updated"
        }
      })
      prog = Anthropic::BetaWebhookEvent.from_json(prog_json)
      prog.user_profile_event?.should be_true
      prog.parsed_user_profile_data.should be_a(Anthropic::BetaWebhookUserProfileProgramStatusUpdatedEventData)

      other = Anthropic::BetaWebhookEvent.from_json(%({"id":"wh_4","created_at":"2026-10-21T00:00:00Z","type":"event","data":{"type":"agent.created","id":"ag_1"}}))
      other.user_profile_event?.should be_false
      other.parsed_user_profile_data.should be_nil
    end
  end

  describe "Managed Agents updates" do
    it "exposes new BetaManagedAgentsModel constants" do
      Anthropic::BetaManagedAgentsModel::CLAUDE_FABLE_5_2.should eq("claude-fable-5-2")
      Anthropic::BetaManagedAgentsModel::CLAUDE_HAIKU_5_5.should eq("claude-haiku-5-5")
      Anthropic::BetaManagedAgentsModel::CLAUDE_SONNET_5_5.should eq("claude-sonnet-5-5")
    end

    it "supports execution_identity, multiagent_20261001, and web_fetch.url_sources on agents" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response_json = %({
        "id": "agent_123",
        "name": "Multi Agent",
        "type": "agent",
        "version": 1,
        "description": "Helper",
        "metadata": {},
        "model": {"id": "claude-sonnet-5-5", "speed": "standard"},
        "execution_identity": {"type": "aws_role", "role_arn": "arn:aws:iam::123456789012:role/agent"},
        "multiagent": {
          "type": "multiagent_20261001",
          "advisor": {"type": "enabled", "model": "claude-opus-4-7"},
          "subagents": {"type": "enabled", "inline_agents": {"type": "enabled"}, "predefined_agents": [{"id": "ag_sub", "type": "agent", "version": 1}]},
          "workflows": {"type": "disabled"}
        },
        "mcp_servers": [],
        "skills": [],
        "system": null,
        "tools": [
          {
            "type": "agent_toolset_20260401",
            "default_config": {"enabled": true, "permission_policy": {"type": "always_allow"}},
            "configs": [
              {
                "name": "web_fetch",
                "enabled": true,
                "permission_policy": {"type": "always_allow"},
                "type": "web_fetch",
                "url_sources": {
                  "client_tool_results": {"type": "all"},
                  "server_tool_results": {"type": "only", "tools": [{"type": "tool_reference", "name": "web_search"}]},
                  "user_input": {"type": "none"}
                }
              }
            ]
          }
        ],
        "created_at": "2026-10-21T00:00:00Z",
        "updated_at": "2026-10-21T00:00:00Z",
        "archived_at": null
      })

      cap = stub_and_capture(:post, "https://api.anthropic.com/v1/agents", response_json)
      created = client.beta.agents.create(
        model: Anthropic::BetaManagedAgentsModel::CLAUDE_SONNET_5_5,
        name: "Multi Agent",
        execution_identity: Anthropic::BetaManagedAgentsAWSRoleExecutionIdentity.new(
          role_arn: "arn:aws:iam::123456789012:role/agent"
        ),
        multiagent: Anthropic::BetaManagedAgentsMultiagent20261001Params.new(
          advisor: Anthropic::BetaManagedAgentsMultiagentAdvisorDisabled.new,
          subagents: Anthropic::BetaManagedAgentsMultiagentSubagentsEnabledParams.new(
            inline_agents: Anthropic::BetaManagedAgentsMultiagentInlineAgentsEnabled.new,
            predefined_agents: ["ag_sub"],
          ),
          workflows: Anthropic::BetaManagedAgentsMultiagentWorkflowsEnabledParams.new(
            inline_agents: Anthropic::BetaManagedAgentsMultiagentInlineAgentsDisabled.new,
            predefined_agents: [Anthropic::BetaManagedAgentsAgentParam.new(id: "ag_wf", version: 2)],
          ),
        ),
        tools: [
          Anthropic::BetaManagedAgentsAgentToolset20260401Params.new(
            configs: [
              Anthropic::BetaManagedAgentsWebFetchToolConfigParams.new(
                enabled: true,
                url_sources: Anthropic::BetaManagedAgentsWebFetchURLSourcesParams.new(
                  client_tool_results: "all",
                  server_tool_results: Anthropic::BetaManagedAgentsWebFetchURLSourceOnly.tools("web_search"),
                  user_input: Anthropic::BetaManagedAgentsWebFetchURLSourceNone.new,
                ),
              ),
            ],
          ),
        ],
      )

      sent = JSON.parse(cap.body.not_nil!)
      sent["execution_identity"]["type"].as_s.should eq("aws_role")
      sent["execution_identity"]["role_arn"].as_s.should eq("arn:aws:iam::123456789012:role/agent")
      sent["multiagent"]["type"].as_s.should eq("multiagent_20261001")
      sent["multiagent"]["subagents"]["inline_agents"]["type"].as_s.should eq("enabled")
      sent["multiagent"]["workflows"]["predefined_agents"][0]["id"].as_s.should eq("ag_wf")
      sent["tools"][0]["configs"][0]["url_sources"]["client_tool_results"].as_s.should eq("all")

      created.execution_identity.should be_a(Anthropic::BetaManagedAgentsAWSRoleExecutionIdentity)
      ma = created.multiagent.as(Anthropic::BetaManagedAgentsMultiagent20261001)
      ma.advisor.as(Anthropic::BetaManagedAgentsMultiagentAdvisorEnabled).model.should eq("claude-opus-4-7")
      ma.subagents.should be_a(Anthropic::BetaManagedAgentsMultiagentSubagentsEnabled)
      ma.workflows.should be_a(Anthropic::BetaManagedAgentsMultiagentWorkflowsDisabled)

      toolset = created.tools.not_nil![0].as(Anthropic::BetaManagedAgentsAgentToolset20260401)
      sources = toolset.configs[0].url_sources.not_nil!
      sources.client_tool_results.should be_a(Anthropic::BetaManagedAgentsWebFetchURLSourceAll)
      sources.server_tool_results.as(Anthropic::BetaManagedAgentsWebFetchURLSourceOnly).tools.map(&.name).should eq(["web_search"])
      sources.user_input.should be_a(Anthropic::BetaManagedAgentsWebFetchURLSourceNone)
    end

    it "parses Session usage, SessionAgent multiagent/execution_identity, and SessionThread inline agents & statuses" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      session_json = %({
        "id": "sess_1",
        "type": "session",
        "status": "idle",
        "title": "Test",
        "environment_id": "env_1",
        "vault_ids": [],
        "outcome_evaluations": [],
        "resources": [],
        "metadata": {},
        "created_at": "2026-10-21T00:00:00Z",
        "updated_at": "2026-10-21T00:00:00Z",
        "archived_at": null,
        "budget": null,
        "deployment_id": "dep_1",
        "stats": {"active_seconds": 12.5, "duration_seconds": 30.0},
        "usage": {
          "active_seconds": 12.5,
          "input_tokens": 100,
          "output_tokens": 50,
          "cache_read_input_tokens": 25,
          "cache_creation": {"ephemeral_1h_input_tokens": 10, "ephemeral_5m_input_tokens": 5},
          "list_cost": {"amount": "0.12", "currency": "USD"},
          "server_tool_use": {"web_fetch_requests": 2, "web_search_requests": 1}
        },
        "agent": {
          "id": "ag_1",
          "type": "agent",
          "version": 1,
          "name": "Root",
          "description": null,
          "execution_identity": {"type": "service_account"},
          "model": {"id": "claude-sonnet-5-5", "speed": "standard"},
          "mcp_servers": [],
          "skills": [],
          "system": null,
          "tools": [],
          "multiagent": {
            "type": "multiagent_20261001",
            "advisor": {"type": "disabled"},
            "subagents": {"type": "enabled", "inline_agents": {"type": "enabled"}, "predefined_agents": [{"id": "ag_sub", "name": "Sub", "type": "agent", "version": 1, "description": null, "execution_identity": {"type": "service_account"}, "model": {"id": "claude-haiku-5-5"}, "mcp_servers": [], "skills": [], "system": null, "tools": []}]},
            "workflows": {"type": "disabled"}
          }
        }
      })
      session = Anthropic::BetaManagedAgentsSession.from_json(session_json)
      session.deployment_id.should eq("dep_1")
      session.usage.active_seconds.should eq(12.5)
      session.usage.list_cost.not_nil!.amount.should eq("0.12")
      session.usage.list_cost.not_nil!.currency.should eq("USD")
      session.usage.server_tool_use.not_nil!.web_fetch_requests.should eq(2)
      session.usage.server_tool_use.not_nil!.web_search_requests.should eq(1)
      session.agent.execution_identity.should be_a(Anthropic::BetaManagedAgentsServiceAccountExecutionIdentity)
      session.agent.multiagent.should be_a(Anthropic::BetaManagedAgentsSessionMultiagent20261001)

      thread_json = %({
        "id": "sthr_1",
        "type": "session_thread",
        "status": "running",
        "session_id": "sess_1",
        "parent_thread_id": "sthr_root",
        "workflow_run_id": "wfrun_1",
        "stats": {"active_seconds": 3.2, "startup_seconds": 0.4},
        "usage": {"active_seconds": 3.2, "list_cost": {"amount": "0.03", "currency": "USD"}},
        "created_at": "2026-10-21T00:00:00Z",
        "updated_at": "2026-10-21T00:00:00Z",
        "archived_at": null,
        "agent": {
          "type": "inline",
          "name": "Inline Worker",
          "description": "Ephemeral",
          "execution_identity": {"type": "aws_role", "role_arn": "arn:aws:iam::111:role/w"},
          "model": {"id": "claude-haiku-5-5"},
          "mcp_servers": [],
          "skills": [],
          "system": "Do work",
          "tools": []
        }
      })

      threads_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/sessions/sess_1/threads?limit=20&statuses[]=running&statuses[]=idle",
        %({"data":[#{thread_json}],"next_page":null})
      )
      threads = client.beta.sessions.threads.list(
        "sess_1",
        statuses: [Anthropic::BetaManagedAgentsSessionThreadStatus::RUNNING, Anthropic::BetaManagedAgentsSessionThreadStatus::IDLE],
      )
      threads_cap.path.not_nil!.should contain("statuses")
      thread = threads.data[0]
      thread.workflow_run_id.should eq("wfrun_1")
      inline = thread.agent.as(Anthropic::BetaManagedAgentsInlineAgent)
      inline.type.should eq("inline")
      inline.name.should eq("Inline Worker")
      inline.execution_identity.should be_a(Anthropic::BetaManagedAgentsAWSRoleExecutionIdentity)
    end

    it "parses all 41 event types, refusal stop details, 7 new session errors, and 7 workflow_run events" do
      Anthropic::BetaManagedAgentsSessionEventType.values.size.should eq(41)
      Anthropic::BetaManagedAgentsSessionEventType.values.uniq!.size.should eq(41)

      idle_json = JSON.parse(%({
        "id": "evt_idle",
        "type": "session.status_idle",
        "processed_at": "2026-10-21T00:00:00Z",
        "stop_reason": {"type": "refusal"},
        "stop_details": {"type": "refusal", "category": "cyber", "explanation": "Blocked"}
      }))
      idle_ev = Anthropic::Sessions.parse_event(idle_json).as(Anthropic::BetaManagedAgentsSessionStatusIdleEvent)
      idle_ev.stop_reason.should be_a(Anthropic::BetaManagedAgentsSessionRefusal)
      idle_ev.stop_details.not_nil!.category.should eq(Anthropic::BetaManagedAgentsSessionRefusalCategory::CYBER)
      idle_ev.stop_details.not_nil!.explanation.should eq("Blocked")

      thread_idle_json = JSON.parse(%({
        "id": "evt_tidle",
        "type": "session.thread_status_idle",
        "agent_name": "sub",
        "session_thread_id": "sthr_1",
        "processed_at": "2026-10-21T00:00:00Z",
        "stop_reason": {"type": "refusal"},
        "stop_details": {"type": "refusal", "category": "general_harms", "explanation": null}
      }))
      thread_idle = Anthropic::Sessions.parse_event(thread_idle_json).as(Anthropic::BetaManagedAgentsSessionThreadStatusIdleEvent)
      thread_idle.stop_reason.should be_a(Anthropic::BetaManagedAgentsSessionRefusal)

      new_session_errors = [
        {"tool_use_limit_reached_error", Anthropic::BetaManagedAgentsToolUseLimitReachedError},
        {"compaction_limit_reached_error", Anthropic::BetaManagedAgentsCompactionLimitReachedError},
        {"repository_authentication_error", Anthropic::BetaManagedAgentsRepositoryAuthenticationError},
        {"repository_forbidden_error", Anthropic::BetaManagedAgentsRepositoryForbiddenError},
        {"repository_not_found_error", Anthropic::BetaManagedAgentsRepositoryNotFoundError},
        {"repository_checkout_error", Anthropic::BetaManagedAgentsRepositoryCheckoutError},
        {"repository_clone_error", Anthropic::BetaManagedAgentsRepositoryCloneError},
      ]
      new_session_errors.each do |(err_type, expected_klass)|
        payload = %({
          "id": "evt_err",
          "type": "session.error",
          "processed_at": "2026-10-21T00:00:00Z",
          "error": {
            "type": "#{err_type}",
            "message": "boom",
            "repository_url": "https://github.com/org/repo",
            "retry_status": {"type": "retrying"}
          }
        })
        ev = Anthropic::Sessions.parse_event(JSON.parse(payload)).as(Anthropic::BetaManagedAgentsSessionErrorEvent)
        ev.error.class.should eq(expected_klass)
      end

      workflow_events = [
        %({"id":"e1","type":"workflow_run.created","name":"plan","description":"run","phases":[{"id":"p1","name":"build","description":null}],"processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1"}),
        %({"id":"e2","type":"workflow_run.status_running","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1"}),
        %({"id":"e3","type":"workflow_run.status_idle","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1"}),
        %({"id":"e4","type":"workflow_run.status_ended","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1","result":{"type":"error","error":{"type":"timeout_error","message":"timed out"}}}),
        %({"id":"e5","type":"workflow_run.error","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":null,"error":{"type":"max_workflow_runs_error","message":"limit reached"}}),
        %({"id":"e6","type":"workflow_run.phase_started","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1","workflow_run_phase_id":"p1"}),
        %({"id":"e7","type":"workflow_run.phase_ended","phase_started_id":"e6","processed_at":"2026-10-21T00:00:00Z","workflow_run_id":"wf_1","workflow_run_phase_id":"p1"}),
      ]
      parsed_wf = workflow_events.map { |raw| Anthropic::Sessions.parse_event(JSON.parse(raw)) }
      parsed_wf[0].as(Anthropic::BetaManagedAgentsWorkflowRunCreatedEvent).phases[0].id.should eq("p1")
      parsed_wf[1].should be_a(Anthropic::BetaManagedAgentsWorkflowRunStatusRunningEvent)
      parsed_wf[2].should be_a(Anthropic::BetaManagedAgentsWorkflowRunStatusIdleEvent)
      ended = parsed_wf[3].as(Anthropic::BetaManagedAgentsWorkflowRunStatusEndedEvent)
      ended.result.as(Anthropic::BetaManagedAgentsWorkflowRunResultError).error.should be_a(Anthropic::BetaManagedAgentsTimeoutWorkflowRunError)
      wf_err = parsed_wf[4].as(Anthropic::BetaManagedAgentsWorkflowRunErrorEvent)
      wf_err.workflow_run_id.should be_nil
      wf_err.error.should be_a(Anthropic::BetaManagedAgentsMaxWorkflowRunsWorkflowRunError)
      parsed_wf[5].should be_a(Anthropic::BetaManagedAgentsWorkflowRunPhaseStartedEvent)
      parsed_wf[6].as(Anthropic::BetaManagedAgentsWorkflowRunPhaseEndedEvent).phase_started_id.should eq("e6")

      ["program_error", "unknown_error", "thread_limit_error"].each do |wf_err_type|
        ev = Anthropic::Sessions.parse_event(JSON.parse(%({
          "id": "e_wf",
          "type": "workflow_run.error",
          "processed_at": "2026-10-21T00:00:00Z",
          "workflow_run_id": "wf_1",
          "error": {"type": "#{wf_err_type}", "message": "err"}
        }))).as(Anthropic::BetaManagedAgentsWorkflowRunErrorEvent)
        ev.error.should_not be_a(Anthropic::GenericBetaManagedAgentsWorkflowRunError)
      end

      t_created = Anthropic::Sessions.parse_event(JSON.parse(%({
        "id": "e_tc",
        "type": "session.thread_created",
        "agent_name": "worker",
        "processed_at": "2026-10-21T00:00:00Z",
        "session_thread_id": "sthr_1",
        "workflow_run_id": "wf_1"
      }))).as(Anthropic::BetaManagedAgentsSessionThreadCreatedEvent)
      t_created.workflow_run_id.should eq("wf_1")
    end

    it "fixes MemoryStores create with metadata and preserves nil-safe MemoryStore models" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      ms_json = %({"id":"ms_1","name":"Notes","type":"memory_store","created_at":"2026-10-21T00:00:00Z","updated_at":"2026-10-21T00:00:00Z"})
      ms = Anthropic::BetaManagedAgentsMemoryStore.from_json(ms_json)
      ms.archived?.should be_false

      cap = stub_and_capture(:post, "https://api.anthropic.com/v1/memory_stores", ms_json)
      client.beta.memory_stores.create(name: "Notes", description: "Prefs", metadata: {"scope" => "user"})
      JSON.parse(cap.body.not_nil!)["metadata"]["scope"].as_s.should eq("user")
    end

    it "handles forward-compatible delta accumulation and SSE errors on SessionEventStream" do
      start = JSON.parse(%({"type":"event_start","event":{"id":"evt_1","type":"agent.message"}}))
      snap = Anthropic::Sessions.accumulate_managed_agents_event(nil, start)
      custom_frag = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"type":"content_delta","index":0,"content":{"type":"citation","url":"https://example.com"}}}))
      snap = Anthropic::Sessions.accumulate_managed_agents_event(snap, custom_frag)
      snap.not_nil!["content"][0]["type"].as_s.should eq("citation")

      followup = JSON.parse(%({"type":"event_delta","event_id":"evt_1","delta":{"type":"content_delta","index":0,"content":{"type":"text","text":"ignored"}}}))
      snap2 = Anthropic::Sessions.accumulate_managed_agents_event(snap, followup)
      snap2.not_nil!["content"][0]["type"].as_s.should eq("citation")

      sse = "event:error\ndata:{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Busy\"}}\n\n"
      resp = HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "text/event-stream"}, body_io: IO::Memory.new(sse))
      expect_raises(Anthropic::OverloadedError, /Busy/) do
        Anthropic::SessionEventStream.new(resp).each { |_| }
      end
    end

    it "stops SessionRunner on any non-requires_action session.status_idle stop_reason" do
      ["refusal", "max_tokens", "budget_reached", "retries_exhausted"].each do |stop_type|
        body = [
          "event: session.status_idle",
          %Q(data: {"type":"session.status_idle","id":"evt_idle","stop_reason":{"type":"#{stop_type}"}}),
          "",
          "event: agent.message",
          %q(data: {"type":"agent.message","id":"evt_late","content":[]}),
          "",
        ].join("\n") + "\n"

        WebMock.reset
        WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?limit=1000")
          .to_return(body: %q({"data":[]}))
        WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream")
          .to_return(body: body, headers: {"Content-Type" => "text/event-stream"})

        client = Anthropic::Client.new(api_key: "sk-ant-test")
        seen = [] of String
        runner = Anthropic::SessionRunner.new(
          client: client,
          session_id: "sess_1",
          max_idle: 1.millisecond,
          on_event: ->(ev : JSON::Any) {
            seen << ev["type"].as_s
            sleep 10.milliseconds if ev["type"].as_s == "session.status_idle"
            nil
          }
        )
        runner.run.should be_nil
        seen.should eq(["session.status_idle"])
      end

      # Contrast: requires_action must NOT stop on max_idle
      body_req = [
        "event: session.status_idle",
        %q(data: {"type":"session.status_idle","id":"evt_req","stop_reason":{"type":"requires_action","event_ids":["e1"]}}),
        "",
        "event: session.status_terminated",
        %q(data: {"type":"session.status_terminated","id":"evt_done"}),
        "",
      ].join("\n") + "\n"

      WebMock.reset
      WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events?limit=1000")
        .to_return(body: %q({"data":[]}))
      WebMock.stub(:get, "https://api.anthropic.com/v1/sessions/sess_1/events/stream")
        .to_return(body: body_req, headers: {"Content-Type" => "text/event-stream"})

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      seen_req = [] of String
      runner_req = Anthropic::SessionRunner.new(
        client: client,
        session_id: "sess_1",
        max_idle: 1.millisecond,
        on_event: ->(ev : JSON::Any) {
          seen_req << ev["type"].as_s
          sleep 10.milliseconds if ev["type"].as_s == "session.status_idle"
          nil
        }
      )
      terminal = runner_req.run
      terminal.not_nil!["type"].as_s.should eq("session.status_terminated")
      seen_req.should eq(["session.status_idle", "session.status_terminated"])
    end
  end

  describe "MCP Tunnels transport" do
    it "parses cloudflare, relay (with and without token), unrecognized generic, and nil legacy transports" do
      cf_json = %({
        "id": "tnl_cf",
        "type": "tunnel",
        "domain": "cf.tunnel.test",
        "display_name": "CF",
        "created_at": "2026-10-21T00:00:00Z",
        "archived_at": null,
        "transport": {"type": "cloudflare"}
      })
      cf = Anthropic::BetaTunnel.from_json(cf_json)
      cf.transport.should be_a(Anthropic::BetaCloudflareTunnelTransport)

      relay_json = %({
        "id": "tnl_relay",
        "type": "tunnel",
        "domain": "relay.tunnel.test",
        "display_name": "Relay",
        "created_at": "2026-10-21T00:00:00Z",
        "archived_at": null,
        "transport": {"type": "relay", "token": {"id": "ttok_1", "tunnel_token": "tok_secret", "type": "tunnel_token"}}
      })
      relay = Anthropic::BetaTunnel.from_json(relay_json)
      rt = relay.transport.as(Anthropic::BetaRelayTunnelTransport)
      rt.token.not_nil!.tunnel_token.should eq("tok_secret")
      rt.token.not_nil!.id.should eq("ttok_1")

      relay_no_tok = Anthropic::BetaTunnel.from_json(%({
        "id": "tnl_relay2",
        "type": "tunnel",
        "domain": "relay2.tunnel.test",
        "display_name": null,
        "created_at": "2026-10-21T00:00:00Z",
        "transport": {"type": "relay"}
      }))
      relay_no_tok.transport.as(Anthropic::BetaRelayTunnelTransport).token.should be_nil

      generic_tnl = Anthropic::BetaTunnel.from_json(%({
        "id": "tnl_gen",
        "type": "tunnel",
        "domain": "gen.tunnel.test",
        "display_name": null,
        "created_at": "2026-10-21T00:00:00Z",
        "transport": {"type": "wireguard", "port": 51820}
      }))
      gt = generic_tnl.transport.as(Anthropic::GenericBetaTunnelTransport)
      gt.type.should eq("wireguard")
      gt.raw["port"].as_i.should eq(51820)

      legacy_tnl = Anthropic::BetaTunnel.from_json(%({
        "id": "tnl_old",
        "type": "tunnel",
        "domain": "old.tunnel.test",
        "display_name": null,
        "created_at": "2026-10-01T00:00:00Z"
      }))
      legacy_tnl.transport.should be_nil
    end
  end
end
