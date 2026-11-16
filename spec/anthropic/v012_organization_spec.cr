require "../spec_helper"

private class OrgBetaSpyMiddleware
  include Anthropic::Middleware

  getter seen_betas = [] of Bool

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    @seen_betas << request.beta?
    Anthropic::APIResponse.new(200, HTTP::Headers.new, %({"id":"org_ga","name":"GA Org","type":"organization"}))
  end
end

describe "Organization Admin v0.12.0 & 2026-10-21 Parity" do
  describe "2026-10-21 updates to existing organization models and endpoints" do
    it "parses API keys without workspace_id and with nullable fields" do
      body = %({
        "data": [
          {
            "id": "apikey_new_ws",
            "created_at": "2026-10-21T00:00:00Z",
            "created_by": null,
            "expires_at": null,
            "name": "workspace-key",
            "partial_key_hint": null,
            "principal": {"type": "user_actor", "user_id": "user_99"},
            "scope": {"type": "workspace", "workspace_id": "ws_42"},
            "status": "expired",
            "type": "api_key"
          },
          {
            "id": "apikey_new_org",
            "created_at": "2026-10-21T00:00:00Z",
            "created_by": {"id": "user_1", "type": "user"},
            "expires_at": null,
            "name": "org-key",
            "partial_key_hint": "sk-ant-...abc",
            "principal": {"type": "service_account_actor", "service_account_id": "sa_7"},
            "scope": {"type": "organization"},
            "status": "active",
            "type": "api_key"
          }
        ],
        "has_more": false,
        "first_id": "apikey_new_ws",
        "last_id": "apikey_new_org"
      })
      stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/api_keys?limit=10&after_id=k_0&created_by_user_id=user_1&status=active&workspace_id=ws_42",
        body
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      resp = client.organization.api_keys.list(
        limit: 10,
        after_id: "k_0",
        created_by_user_id: "user_1",
        status: Anthropic::APIKeyStatus::ACTIVE,
        workspace_id: "ws_42"
      )

      ws_key = resp.data[0]
      ws_key.created_by.should be_nil
      ws_key.expires_at.should be_nil
      ws_key.partial_key_hint.should be_nil
      ws_key.workspace_id.should eq("ws_42")
      ws_key.status.should eq(Anthropic::APIKeyStatus::EXPIRED)
      ws_key.parsed_scope.should be_a(Anthropic::APIKeyWorkspaceScope)
      ws_key.parsed_principal.as(Anthropic::APIKeyUserActor).user_id.should eq("user_99")

      org_key = resp.data[1]
      org_key.workspace_id.should be_nil
      org_key.parsed_scope.should be_a(Anthropic::APIKeyOrganizationScope)
      org_key.parsed_created_by.not_nil!.id.should eq("user_1")
      org_key.parsed_principal.as(Anthropic::APIKeyServiceAccountActor).service_account_id.should eq("sa_7")
    end

    it "parses rate limits without group_type and with array limits" do
      body = %({
        "data": [{
          "id": "rl_1",
          "group": {"id": "mg_1", "display_name": "Opus", "type": "model_group"},
          "limits": [{"type": "input_tokens_per_minute", "value": 100000}],
          "models": ["claude-opus-4-6"],
          "type": "rate_limit"
        }],
        "next_page": null
      })
      stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/rate_limits?limit=20&group_type=model_group&model=claude-opus-4-6",
        body
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      resp = client.organization.rate_limits.list(group_type: "model_group", model: "claude-opus-4-6")

      item = resp.data.first
      item.group_type.should be_nil
      item.limit_values.size.should eq(1)
      item.limit_values.first.type.should eq("input_tokens_per_minute")
      item.limit_values.first.value.should eq(100_000_i64)
    end

    it "lists and updates workspace rate limits with inherited flags and null clear" do
      list_body = %({
        "data": [{
          "group": {"id": "mg_1", "display_name": "Sonnet", "type": "model_group"},
          "limits": [
            {"org_limit": 100000, "source": {"type": "workspace"}, "type": "input_tokens_per_minute", "value": 50000},
            {"org_limit": 20000, "source": {"type": "organization"}, "type": "output_tokens_per_minute", "value": 20000}
          ],
          "models": ["claude-sonnet-4-6"],
          "rate_limit_id": "rl_1",
          "type": "workspace_rate_limit",
          "workspace_id": "ws_1"
        }],
        "next_page": null
      })
      stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/workspaces/ws_1/rate_limits?limit=20&group_type=model_group&include_inherited=true",
        list_body
      )

      update_body = %({
        "group": {"id": "mg_1", "display_name": "Sonnet", "type": "model_group"},
        "limits": [
          {"org_limit": 100000, "source": {"type": "workspace"}, "type": "input_tokens_per_minute", "value": 75000}
        ],
        "models": ["claude-sonnet-4-6"],
        "rate_limit_id": "rl_1",
        "type": "workspace_rate_limit",
        "workspace_id": "ws_1"
      })
      capture = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/organizations/workspaces/ws_1/rate_limits/rl_1",
        update_body
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      listed = client.organization.workspaces.rate_limits.list(
        "ws_1",
        group_type: "model_group",
        include_inherited: true
      )
      listed.data.first.rate_limit_id.should eq("rl_1")
      listed.data.first.limits[0].source.should be_a(Anthropic::WorkspaceRateLimitWorkspaceSource)
      listed.data.first.limits[1].source.should be_a(Anthropic::WorkspaceRateLimitOrganizationSource)

      updated = client.organization.workspaces.rate_limits.update(
        "ws_1",
        "rl_1",
        limits: [
          Anthropic::WorkspaceRateLimitUpdateValue.new(
            type: Anthropic::WorkspaceRateLimitType::INPUT_TOKENS_PER_MINUTE,
            value: 75_000_i64
          ),
          Anthropic::WorkspaceRateLimitUpdateValue.new(
            type: Anthropic::WorkspaceRateLimitType::OUTPUT_TOKENS_PER_MINUTE,
            value: nil
          ),
        ]
      )
      updated.limits.first.value.should eq(75_000_i64)
      sent = JSON.parse(capture.body.not_nil!)
      sent["limits"][1]["type"].as_s.should eq("output_tokens_per_minute")
      sent["limits"][1]["value"].raw.should be_nil
    end

    it "supports user_profile_id on external keys and workspaces plus workspace list filters" do
      ext_json = %({
        "id": "ek_1",
        "attachment": {"type": "unattached"},
        "created_at": "2026-10-21T00:00:00Z",
        "display_name": null,
        "geo": "us",
        "provider_config": {"type": "aws", "kms_arn": "arn:aws:kms:us-east-1:123:key/abc"},
        "type": "external_key",
        "updated_at": "2026-10-21T00:00:00Z",
        "user_profile_id": "up_1"
      })
      ext_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/external_keys", ext_json)

      ws_json = %({
        "id": "ws_1",
        "archived_at": null,
        "compartment_id": "comp_1",
        "created_at": "2026-10-21T00:00:00Z",
        "data_residency": {"allowed_inference_geos": "unrestricted", "default_inference_geo": "global", "workspace_geo": "us"},
        "display_color": "#000",
        "external_key_id": "ek_1",
        "name": "Tenant",
        "tags": {},
        "type": "workspace",
        "user_profile_id": "up_1"
      })
      ws_create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces", ws_json)
      ws_list_json = %({"data":[#{ws_json}],"has_more":false,"first_id":"ws_1","last_id":"ws_1"})
      stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/workspaces?limit=20&ids%5B%5D=ws_1&include_default=true",
        ws_list_json
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      ext = client.organization.external_keys.create(
        provider_config: JSON.parse(%({"type":"aws","kms_arn":"arn:aws:kms:us-east-1:123:key/abc"})),
        user_profile_id: "up_1"
      )
      ext.user_profile_id.should eq("up_1")
      ext.display_name.should be_nil
      JSON.parse(ext_capture.body.not_nil!)["user_profile_id"].as_s.should eq("up_1")

      ws = client.organization.workspaces.create(name: "Tenant", external_key_id: "ek_1", user_profile_id: "up_1")
      ws.user_profile_id.should eq("up_1")
      JSON.parse(ws_create_cap.body.not_nil!)["user_profile_id"].as_s.should eq("up_1")

      listed = client.organization.workspaces.list(ids: ["ws_1"], include_default: true)
      listed.data.size.should eq(1)
    end

    it "forwards invite rbac_group_ids, roles/statuses filters, and signs out users on beta" do
      invite_json = %({
        "id": "inv_1",
        "accepted_at": null,
        "email": "a@b.test",
        "expires_at": "2026-11-01T00:00:00Z",
        "invited_at": "2026-10-21T00:00:00Z",
        "rbac_group_ids": ["rbac_group_1"],
        "role": "developer",
        "status": "pending",
        "type": "invite"
      })
      inv_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/invites", invite_json)

      user_json = %({"id":"user_1","added_at":"2026-10-21T00:00:00Z","email":"a@b.test","name":"A","role":"owner","type":"user"})
      signout_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/users/user_1/sign_out", user_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      inv = client.organization.invites.create(
        email: "a@b.test",
        role: Anthropic::OrganizationRole::DEVELOPER,
        rbac_group_ids: ["rbac_group_1"]
      )
      inv.rbac_group_ids.should eq(["rbac_group_1"])
      JSON.parse(inv_cap.body.not_nil!)["rbac_group_ids"].as_a.map(&.as_s).should eq(["rbac_group_1"])

      Anthropic::OrganizationRole::OWNER.should eq("owner")
      Anthropic::OrganizationRole::PRIMARY_OWNER.should eq("primary_owner")
      Anthropic::WorkspaceRole::WORKSPACE_ADMIN.should eq("workspace_admin")
      Anthropic::NoBillingWorkspaceRole::WORKSPACE_RESTRICTED_DEVELOPER.should eq("workspace_restricted_developer")

      signed_out = client.beta.organization.users.sign_out("user_1")
      signed_out.role.should eq(Anthropic::OrganizationRole::OWNER)
      signout_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::ADMIN_USER_SIGN_OUT_BETA)
    end

    it "parses nullable fields on service accounts and federation issuers" do
      sa_json = %({
        "id": "sa_1",
        "archived_at": null,
        "archived_by_actor_id": null,
        "created_at": "2026-10-21T00:00:00Z",
        "created_by_actor_id": null,
        "description": null,
        "name": "bot",
        "organization_role": "developer",
        "type": "service_account",
        "updated_at": "2026-10-21T00:00:00Z",
        "updated_by_actor_id": null
      })
      sa = Anthropic::ServiceAccount.from_json(sa_json)
      sa.created_by_actor_id.should be_nil
      sa.description.should be_nil
      sa.updated_by_actor_id.should be_nil
    end
  end

  describe "GA vs Beta separation and request context" do
    it "marks GA client.organization requests with beta: false and no auto beta headers" do
      middleware = OrgBetaSpyMiddleware.new

      client = Anthropic::Client.new(api_key: "sk-ant-test", middleware: [middleware])
      client.organization.retrieve.id.should eq("org_ga")
      client.beta.organization.retrieve.id.should eq("org_ga")
      middleware.seen_betas.should eq([false, true])
    end

    it "exposes beta-only endpoints on client.beta.organization only" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      ga = client.organization
      beta = client.beta.organization

      ga.responds_to?(:plugins).should be_false
      ga.responds_to?(:plugin_marketplaces).should be_false
      ga.responds_to?(:telemetry_destinations).should be_false
      ga.responds_to?(:webhooks).should be_false
      ga.responds_to?(:claude_tag).should be_false
      ga.users.responds_to?(:sign_out).should be_false
      ga.spend_limits.responds_to?(:list).should be_false
      ga.spend_limits.responds_to?(:set).should be_false
      ga.analytics.responds_to?(:usage).should be_false
      ga.analytics.responds_to?(:cost).should be_false
      ga.analytics.responds_to?(:usage_report).should be_false

      beta.responds_to?(:plugins).should be_true
      beta.responds_to?(:plugin_marketplaces).should be_true
      beta.responds_to?(:telemetry_destinations).should be_true
      beta.responds_to?(:webhooks).should be_true
      beta.responds_to?(:claude_tag).should be_true
      beta.users.responds_to?(:sign_out).should be_true
      beta.spend_limits.responds_to?(:list).should be_true
      beta.analytics.responds_to?(:usage).should be_true
      beta.analytics.responds_to?(:cost).should be_true
      beta.analytics.responds_to?(:usage_report).should be_true
    end
  end

  describe "RBAC groups and roles (GA + Beta)" do
    it "manages RBAC groups, members, roles, and typed permissions" do
      group_json = %({
        "id": "rbac_group_1",
        "created_at": "2026-10-21T00:00:00Z",
        "name": "Engineering",
        "role_ids": ["rbac_role_1"],
        "source_type": "direct",
        "type": "rbac_group",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      list_groups_json = %({"data":[#{group_json}],"next_page":null})
      del_group_json = %({"id":"rbac_group_1","type":"rbac_group_deleted"})
      member_json = %({"created_at":"2026-10-21T00:00:00Z","email":"dev@acme.test","rbac_group_id":"rbac_group_1","type":"rbac_group_member","user_id":"user_1"})
      del_member_json = %({"rbac_group_id":"rbac_group_1","type":"rbac_group_member_deleted","user_id":"user_1"})

      role_json = %({"id":"rbac_role_1","created_at":"2026-10-21T00:00:00Z","display_name":"Connector Admin","type":"rbac_role","updated_at":"2026-10-21T00:00:00Z"})
      perm_list_json = %({
        "data": [
          {"action": "read", "resource": {"type": "organization", "organization_id": "org_1"}, "type": "rbac_role_permission"},
          {"action": "use", "resource": {"type": "connector", "connector_id": "conn_1"}, "type": "rbac_role_permission"},
          {"action": "use", "resource": {"type": "connector_scope", "connector_id": "conn_1", "scope": "repo"}, "type": "rbac_role_permission"},
          {"action": "invoke", "resource": {"type": "connector_tool", "connector_id": "conn_1", "tool_name": "search"}, "type": "rbac_role_permission"},
          {"action": "use", "resource": {"type": "all_connectors"}, "type": "rbac_role_permission"},
          {"action": "future", "resource": {"type": "future_res", "x": 1}, "type": "rbac_role_permission"}
        ],
        "next_page": null
      })

      create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/rbac_groups", group_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_groups", list_groups_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1", group_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1", group_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1", del_group_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1/members", %({"data":[#{member_json}],"next_page":null}))
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1/members", member_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/rbac_groups/rbac_group_1/members/user_1", del_member_json)

      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_roles", %({"data":[#{role_json}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_roles/rbac_role_1", role_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rbac_roles/rbac_role_1/permissions", perm_list_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      create_cap_resp = client.organization.rbac_groups.create(name: "Engineering")
      create_cap_resp.name.should eq("Engineering")
      create_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      client.organization.rbac_groups.list.data.size.should eq(1)
      client.organization.rbac_groups.retrieve("rbac_group_1").source_type.should eq("direct")
      client.organization.rbac_groups.update("rbac_group_1", name: "Platform").id.should eq("rbac_group_1")
      client.organization.rbac_groups.members.list("rbac_group_1").data.first.user_id.should eq("user_1")
      client.organization.rbac_groups.members.add("rbac_group_1", "user_1").type.should eq("rbac_group_member")
      client.organization.rbac_groups.members.remove("rbac_group_1", "user_1").type.should eq("rbac_group_member_deleted")
      client.organization.rbac_groups.delete("rbac_group_1").type.should eq("rbac_group_deleted")

      roles = client.organization.rbac_roles.list
      roles.data.first.display_name.should eq("Connector Admin")
      client.organization.rbac_roles.retrieve("rbac_role_1").id.should eq("rbac_role_1")

      perms = client.beta.organization.rbac_roles.permissions.list("rbac_role_1")
      perms.data[0].resource.should be_a(Anthropic::RbacOrganizationPermissionResource)
      perms.data[1].resource.should be_a(Anthropic::RbacConnectorPermissionResource)
      perms.data[2].resource.as(Anthropic::RbacConnectorScopePermissionResource).scope.should eq("repo")
      perms.data[3].resource.as(Anthropic::RbacConnectorToolPermissionResource).tool_name.should eq("search")
      perms.data[4].resource.should be_a(Anthropic::RbacAllConnectorsPermissionResource)
      perms.data[5].resource.as(Anthropic::RbacGenericPermissionResource).type.should eq("future_res")
    end
  end

  describe "Spend limits (GA + Beta)" do
    it "handles GA effective summaries and increase requests" do
      summary_json = %({
        "actor": {"deleted": false, "email_address": "u@test", "name": "U", "type": "user_actor", "user_id": "user_1"},
        "amount": "5000",
        "currency": "USD",
        "period": "monthly",
        "period_to_date_spend": "1200",
        "scope": {"type": "user", "user_id": "user_1"},
        "source": {"type": "organization"},
        "spend_limit_id": "sl_1"
      })
      req_json = %({
        "id": "slir_1",
        "actor": {"type": "scoped_api_key_actor", "scoped_api_key_id": "sak_1"},
        "created_at": "2026-10-21T00:00:00Z",
        "period": "monthly",
        "resolved_at": null,
        "resolved_by": null,
        "spend_summary": #{summary_json},
        "status": "pending",
        "type": "spend_limit_increase_request"
      })
      limit_json = %({
        "id": "sl_2",
        "amount": "10000",
        "created_at": "2026-10-21T00:00:00Z",
        "currency": "USD",
        "is_enabled": true,
        "period": "monthly",
        "scope": {"type": "workspace", "workspace_id": "ws_1"},
        "type": "spend_limit",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      approve_json = %({
        "id": "slir_1",
        "actor": {"type": "scoped_api_key_actor", "scoped_api_key_id": "sak_1"},
        "created_at": "2026-10-21T00:00:00Z",
        "period": "monthly",
        "resolved_at": "2026-10-21T01:00:00Z",
        "resolved_by": {"deleted": false, "email_address": "admin@test", "name": "Admin", "type": "user_actor", "user_id": "user_admin"},
        "spend_limit": #{limit_json},
        "spend_summary": null,
        "status": "approved",
        "type": "spend_limit_increase_request"
      })

      eff_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/spend_limits/effective?period%5B%5D=monthly&user_ids%5B%5D=user_1",
        %({"data":[#{summary_json}],"next_page":null})
      )
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/spend_limit_increase_requests?status%5B%5D=pending", %({"data":[#{req_json}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/spend_limit_increase_requests/slir_1", req_json)
      app_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/spend_limit_increase_requests/slir_1/approve", approve_json)
      deny_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/spend_limit_increase_requests/slir_1/deny", req_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      eff = client.organization.spend_limits.effective.list(period: "monthly", user_ids: ["user_1"])
      eff.data.first.actor.as(Anthropic::SpendLimitUserActor).user_id.should eq("user_1")
      eff.data.first.source.should be_a(Anthropic::SpendLimitOrganizationScope)
      eff_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      reqs = client.organization.spend_limits.increase_requests.list(status: ["pending"])
      reqs.data.first.resolved_by.should be_nil
      client.organization.spend_limits.increase_requests.retrieve("slir_1").status.should eq("pending")

      approved = client.organization.spend_limits.increase_requests.approve("slir_1", amount: "10000", suppress_notification: true)
      approved.spend_limit.not_nil!.scope.as(Anthropic::SpendLimitWorkspaceScope).workspace_id.should eq("ws_1")
      JSON.parse(app_cap.body.not_nil!)["amount"].as_s.should eq("10000")

      client.organization.spend_limits.increase_requests.deny("slir_1", suppress_notification: false)
      JSON.parse(deny_cap.body.not_nil!)["suppress_notification"].as_bool.should be_false
    end

    it "manages Beta spend_limits CRUD with SPEND_LIMIT_READS_BETA on list and nullable amount on set" do
      limit_json = %({
        "id": "sl_1",
        "amount": null,
        "created_at": "2026-10-21T00:00:00Z",
        "currency": "USD",
        "is_enabled": true,
        "period": "monthly",
        "scope": {"type": "rbac_group", "rbac_group_id": "rg_1"},
        "type": "spend_limit",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      list_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/spend_limits?workspace_id=ws_1&scope_type%5B%5D=rbac_group",
        %({"data":[#{limit_json}],"next_page":null})
      )
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/spend_limits/sl_1", limit_json)
      set_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/spend_limits", limit_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/spend_limits/sl_1", %({"id":"sl_1","type":"spend_limit_deleted"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      listed = client.beta.organization.spend_limits.list(scope_type: ["rbac_group"], workspace_id: "ws_1")
      listed.data.first.scope.as(Anthropic::SpendLimitRbacGroupScope).rbac_group_id.should eq("rg_1")
      list_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::SPEND_LIMIT_READS_BETA)

      client.beta.organization.spend_limits.retrieve("sl_1").id.should eq("sl_1")

      set_resp = client.beta.organization.spend_limits.set(
        amount: nil,
        scope: Anthropic::SpendLimitUserScope.new(user_id: "user_1"),
        period: Anthropic::SpendLimitPeriod::MONTHLY
      )
      set_resp.amount.should be_nil
      sent = JSON.parse(set_cap.body.not_nil!)
      sent.as_h.has_key?("amount").should be_true
      sent["amount"].raw.should be_nil
      sent["scope"]["user_id"].as_s.should eq("user_1")

      client.beta.organization.spend_limits.delete("sl_1").type.should eq("spend_limit_deleted")
    end
  end

  describe "Analytics (GA activity + Beta usage/cost & legacy reports)" do
    it "queries GA enterprise activity endpoints including claude_tag and chat_cowork_unified metrics" do
      summary_json = %({
        "assigned_seat_count": 100,
        "cowork_daily_active_user_count": 20,
        "cowork_monthly_active_user_count": 50,
        "cowork_weekly_active_user_count": 35,
        "daily_active_user_count": 60,
        "daily_adoption_rate": 0.6,
        "ending_at": "2026-10-21T00:00:00Z",
        "monthly_active_user_count": 90,
        "monthly_adoption_rate": 0.9,
        "pending_invite_count": 5,
        "starting_at": "2026-10-20T00:00:00Z",
        "weekly_active_user_count": 75,
        "weekly_adoption_rate": 0.75,
        "claude_tag_daily_active_user_count": 12,
        "chat_cowork_unified_daily_active_user_count": 18
      })
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/summaries?starting_date=2026-10-20", %({"data":[#{summary_json}],"next_page":"p2"}))

      user_json = %({
        "chat_metrics": {"connectors_used_count":1,"distinct_artifacts_created_count":1,"distinct_connectors_used_count":1,"distinct_conversation_count":1,"distinct_files_uploaded_count":0,"distinct_projects_created_count":0,"distinct_projects_used_count":0,"distinct_shared_artifacts_viewed_count":0,"distinct_skills_used_count":0,"message_count":5,"shared_conversations_viewed_count":0,"thinking_message_count":1},
        "claude_code_metrics": {"core_metrics":{"artifacts_created_count":0,"commit_count":2,"distinct_session_count":1,"lines_of_code":{"added_count":20,"removed_count":4},"pull_request_count":1},"tool_actions":{"edit_tool":{"accepted_count":3,"rejected_count":0},"multi_edit_tool":{"accepted_count":0,"rejected_count":0},"notebook_edit_tool":{"accepted_count":0,"rejected_count":0},"write_tool":{"accepted_count":1,"rejected_count":0}}},
        "cowork_metrics": {"action_count":1,"artifacts_created_count":0,"connectors_used_count":0,"dispatch_turn_count":0,"distinct_connectors_used_count":null,"distinct_plugins_used_count":null,"distinct_session_count":1,"distinct_skills_used_count":null,"edit_tool_count":null,"file_edit_count":null,"message_count":2,"multi_edit_tool_count":null,"notebook_edit_tool_count":null,"plugins_used_count":null,"sessions_with_file_edits_count":null,"skills_used_count":0,"write_tool_count":null},
        "design_metrics": {"distinct_projects_created_count":0,"distinct_projects_used_count":0,"distinct_session_count":0,"message_count":0},
        "distinct_user_count": 1,
        "office_metrics": {"excel":{"connectors_used_count":0,"distinct_connectors_used_count":0,"distinct_session_count":0,"distinct_skills_used_count":0,"message_count":0,"skills_used_count":0},"outlook":{"connectors_used_count":0,"distinct_connectors_used_count":0,"distinct_session_count":0,"distinct_skills_used_count":0,"message_count":0,"skills_used_count":0},"powerpoint":{"connectors_used_count":0,"distinct_connectors_used_count":0,"distinct_session_count":0,"distinct_skills_used_count":0,"message_count":0,"skills_used_count":0},"word":{"connectors_used_count":0,"distinct_connectors_used_count":0,"distinct_session_count":0,"distinct_skills_used_count":0,"message_count":0,"skills_used_count":0}},
        "science_metrics": {"delegation_count":0,"distinct_session_count":0,"message_count":0,"remote_compute_job_count":0,"skills_used_count":0},
        "user": {"id":"user_1","email_address":"u@test","type":"user"},
        "web_search_count": 3,
        "claude_tag_metrics": {"active_day_count": 2, "active_message_count": 14}
      })
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/users?date=2026-10-20&group_by%5B%5D=rbac_group_id", %({"data":[#{user_json}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/apps/chat/projects", %({"data":[{"created_at":"2026-10-01T00:00:00Z","created_by":null,"distinct_conversation_count":3,"distinct_user_count":2,"message_count":9,"project_id":"proj_1","project_name":"Docs"}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/connectors", %({"data":[{"chat_metrics":{"distinct_conversation_connector_used_count":1},"claude_code_metrics":{"distinct_session_connector_used_count":1},"connector_display_name":"GitHub","connector_name":"github","cowork_metrics":{"distinct_session_connector_used_count":0},"distinct_user_count":2,"individual_auth_distinct_user_count":2,"managed_auth_distinct_user_count":0,"office_metrics":{"excel":{"distinct_session_connector_used_count":0},"outlook":{"distinct_session_connector_used_count":0},"powerpoint":{"distinct_session_connector_used_count":0},"word":{"distinct_session_connector_used_count":0}},"read_call_count":4,"unclassified_call_count":0,"write_call_count":1}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/plugins", %({"data":[{"claude_code_metrics":{"distinct_session_plugin_used_count":2},"cowork_metrics":{"distinct_session_plugin_used_count":1},"distinct_user_count":2,"install_count":3,"invocation_count":7,"plugin_id":"plug_1","plugin_name":"linter"}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/skills", %({"data":[{"attributed_list_price":"1.50","chat_metrics":{"distinct_conversation_skill_used_count":1},"claude_code_metrics":{"distinct_session_skill_used_count":2},"cowork_metrics":{"distinct_session_skill_used_count":0},"currency":"USD","distinct_user_count":2,"enable_count":2,"estimated_overage_spend":"0.00","invocation_count":4,"office_metrics":{"excel":{"distinct_session_skill_used_count":0},"outlook":{"distinct_session_skill_used_count":0},"powerpoint":{"distinct_session_skill_used_count":0},"word":{"distinct_session_skill_used_count":0}},"share_status":"organization","skill_display_name":"Formatter","skill_name":"fmt"}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/artifacts?date=2026-10-20", %({"data":[{"artifact_type":"text/markdown","artifacts_created_count":5,"distinct_user_count":2,"is_shared":true,"published_artifacts_created_count":1}],"next_page":null}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      summaries = client.organization.analytics.summaries.list(starting_date: "2026-10-20")
      summaries.has_next_page?.should be_true
      summaries.data.first.claude_tag_daily_active_user_count.should eq(12)
      summaries.data.first.chat_cowork_unified_daily_active_user_count.should eq(18)

      users = client.organization.analytics.users.list(date: "2026-10-20", group_by: "rbac_group_id")
      users.data.first.claude_tag_metrics.not_nil!.active_message_count.should eq(14)

      client.organization.analytics.apps.chat.projects.list.data.first.project_id.should eq("proj_1")
      client.organization.analytics.connectors.list.data.first.connector_name.should eq("github")
      client.organization.analytics.plugins.list.data.first.invocation_count.should eq(7)
      client.organization.analytics.skills.list.data.first.skill_name.should eq("fmt")
      client.organization.analytics.artifacts.list(date: "2026-10-20").data.first.is_shared?.should be_true
    end

    it "queries Beta usage and cost endpoints with ANALYTICS_USAGE_COST_BETA and ReportPageCursor" do
      usage_json = %({
        "data": [{
          "starting_at": "2026-10-20T00:00:00Z",
          "ending_at": "2026-10-21T00:00:00Z",
          "group": {
            "actor": {"type": "federated_actor", "provider": {"type": "aws", "account_id": "111", "signed_principal": "arn:aws:iam::111:role/r"}, "subject": "sub_1"},
            "actor_type": "federated_actor",
            "model": "claude-sonnet-4-6"
          },
          "usage": {
            "cache_creation": {"ephemeral_1h_input_tokens": 100, "ephemeral_5m_input_tokens": 50},
            "cache_read_input_tokens": 200,
            "output_tokens": 300,
            "requests": 10,
            "server_tool_use": {"web_search_requests": 2},
            "total_tokens": 650,
            "uncached_input_tokens": 150
          }
        }],
        "has_more": true,
        "next_page": "cursor_2",
        "data_refreshed_at": "2026-10-21T02:00:00Z"
      })
      cost_json = %({
        "data": [{
          "starting_at": "2026-10-20T00:00:00Z",
          "ending_at": "2026-10-21T00:00:00Z",
          "group": {"cost_type": "tokens", "token_type": "output_tokens"},
          "cost": {"amount": "420", "currency": "USD", "list_amount": "500", "requests": 10}
        }],
        "has_more": false,
        "next_page": null,
        "data_refreshed_at": "2026-10-21T02:00:00Z"
      })

      u_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/analytics/usage?starting_at=2026-10-20T00%3A00%3A00Z&group_by%5B%5D=actor&time_bucket_width=1d",
        usage_json
      )
      c_cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/analytics/cost?starting_at=2026-10-20T00%3A00%3A00Z&order_by=amount",
        cost_json
      )

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      usage = client.beta.organization.analytics.usage.list(
        starting_at: "2026-10-20T00:00:00Z",
        group_by: [Anthropic::BetaAnalyticsUsageGroupBy::ACTOR],
        time_bucket_width: Anthropic::BetaAnalyticsTimeBucketWidth::DAY
      )
      usage.should be_a(Anthropic::ReportPageCursor(Anthropic::BetaAnalyticsUsageItem))
      usage.has_more?.should be_true
      usage.has_next_page?.should be_true
      usage.data_refreshed_at.should eq("2026-10-21T02:00:00Z")
      actor = usage.data.first.group.actor.as(Anthropic::BetaAnalyticsFederatedActor)
      actor.provider.as(Anthropic::BetaAnalyticsFederatedActorAWSProvider).account_id.should eq("111")
      u_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::ANALYTICS_USAGE_COST_BETA)

      cost = client.beta.organization.analytics.cost.list(
        starting_at: "2026-10-20T00:00:00Z",
        order_by: Anthropic::BetaAnalyticsCostOrderBy::AMOUNT
      )
      cost.has_more?.should be_false
      cost.data.first.cost.amount.should eq("420")
      c_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::ANALYTICS_USAGE_COST_BETA)
    end

    it "queries legacy Beta usage_report, cost_report, user_usage_report, and user_cost_report" do
      usage_bucket_json = %({
        "data": [{
          "starting_at": "2026-10-20T00:00:00Z",
          "ending_at": "2026-10-21T00:00:00Z",
          "results": [{
            "cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0},
            "cache_read_input_tokens": 10,
            "output_tokens": 20,
            "server_tool_use": {"web_search_requests": 0},
            "uncached_input_tokens": 30
          }]
        }],
        "has_more": false,
        "next_page": null
      })
      cost_bucket_json = %({
        "data": [{
          "starting_at": "2026-10-20T00:00:00Z",
          "ending_at": "2026-10-21T00:00:00Z",
          "results": [{"amount": "15", "currency": "USD", "list_amount": "15"}]
        }],
        "has_more": false,
        "next_page": null
      })
      user_usage_json = %({
        "data": [{
          "actor": {"deleted": false, "email_address": "u@test", "name": "U", "type": "user_actor", "user_id": "user_1"},
          "cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0},
          "cache_read_input_tokens": 0,
          "output_tokens": 25,
          "server_tool_use": {"web_search_requests": 0},
          "total_tokens": 75,
          "uncached_input_tokens": 50
        }],
        "has_more": false,
        "next_page": null
      })
      user_cost_json = %({
        "data": [{
          "actor": {"deleted": false, "email_address": "u@test", "name": "U", "type": "user_actor", "user_id": "user_1"},
          "amount": "99",
          "currency": "USD",
          "list_amount": "99"
        }],
        "has_more": false,
        "next_page": null
      })

      ur_cap = stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/usage_report?starting_at=2026-10-20T00%3A00%3A00Z&bucket_width=1d", usage_bucket_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/cost_report?starting_at=2026-10-20T00%3A00%3A00Z", cost_bucket_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/user_usage_report?starting_at=2026-10-20T00%3A00%3A00Z", user_usage_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/analytics/user_cost_report?starting_at=2026-10-20T00%3A00%3A00Z", user_cost_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      ur = client.beta.organization.analytics.usage_report.list(starting_at: "2026-10-20T00:00:00Z", bucket_width: "1d")
      ur.data.first.results.first.output_tokens.should eq(20)
      ur_cap.headers.not_nil!.has_key?("anthropic-beta").should be_false

      client.beta.organization.analytics.cost_report.list(starting_at: "2026-10-20T00:00:00Z").data.first.results.first.amount.should eq("15")
      client.beta.organization.analytics.user_usage_report.list(starting_at: "2026-10-20T00:00:00Z").data.first.total_tokens.should eq(75)
      client.beta.organization.analytics.user_cost_report.list(starting_at: "2026-10-20T00:00:00Z").data.first.amount.should eq("99")
    end
  end

  describe "Beta plugins and plugin_marketplaces" do
    it "uploads plugins, manages versions/settings/shares, and downloads binary content" do
      plugin_json = %({
        "id": "plugin_1",
        "components": [{"description": "Lint hook", "name": "pre-commit", "type": "hook"}],
        "content_scan": {"assessment": "pass", "reason": null, "status": "completed"},
        "created_at": "2026-10-21T00:00:00Z",
        "created_by": {"type": "user_actor", "email_address": "dev@test", "user_id": "user_1"},
        "description": "Plugin desc",
        "display_name": "Linter",
        "latest_version_id": "pv_1",
        "manifest_version": "1.0.0",
        "marketplace_id": "mp_1",
        "name": "linter",
        "organization_installation_preference": "available",
        "organization_installation_preference_inherited": true,
        "owner": {"type": "organization"},
        "reach": "privileged",
        "served_version_id": "pv_1",
        "served_version_pinned": false,
        "type": "plugin",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      version_json = %({
        "id": "pv_2",
        "components": [],
        "content_scan": null,
        "created_at": "2026-10-21T00:00:00Z",
        "created_by": {"type": "api_actor", "api_key_id": "apikey_1"},
        "description": null,
        "display_name": "Linter",
        "manifest_version": "1.1.0",
        "plugin_id": "plugin_1",
        "reach": "contained",
        "release_notes": "v1.1",
        "type": "plugin_version"
      })
      setting_json = %({
        "created_at": "2026-10-21T00:00:00Z",
        "installation_preference": "required",
        "plugin_id": "plugin_1",
        "target": {"type": "rbac_group", "rbac_group_id": "rg_1"},
        "type": "plugin_installation_setting",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      share_json = %({
        "granted_at": "2026-10-21T00:00:00Z",
        "plugin_id": "plugin_1",
        "target": {"type": "organization_member", "user_id": "user_2"},
        "type": "plugin_share"
      })

      create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugins", plugin_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1?organization_id=org_1", plugin_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugins/plugin_1", plugin_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins?created_at%5Bgt%5D=2026-10-01T00%3A00%3A00Z&owner_type=organization", %({"data":[#{plugin_json}],"next_page":null}))
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/plugins/plugin_1", %({"id":"plugin_1","type":"plugin_deleted"}))

      v_create_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/versions", version_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/versions/pv_2", version_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/versions", %({"data":[#{version_json}],"next_page":null}))

      dl_cap = nil
      WebMock.stub(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/versions/pv_2/content?organization_id=org_1").to_return do |request|
        dl_cap = request
        HTTP::Client::Response.new(200, body: "ZIPDATA", headers: HTTP::Headers{"Content-Type" => "application/zip"})
      end

      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/installation_settings", %({"data":[#{setting_json}],"next_page":null}))
      set_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/installation_settings/rg_1", setting_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/installation_settings/rg_1", %({"plugin_id":"plugin_1","target":{"type":"rbac_group","rbac_group_id":"rg_1"},"type":"plugin_installation_setting_deleted"}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugins/plugin_1/shares", %({"data":[#{share_json}],"next_page":null}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = Anthropic::FileUpload.from_bytes("{}".to_slice, content_type: "application/json", filename: "plugin.json")
      created = client.beta.organization.plugins.create(files: [file], marketplace_id: "mp_1", release_notes: "init")
      created.owner.should be_a(Anthropic::BetaPluginOwnerOrganization)
      create_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
      create_cap.body.not_nil!.should contain("name=\"files[]\"; filename=\"plugin.json\"")
      create_cap.body.not_nil!.should contain("name=\"marketplace_id\"")

      client.beta.organization.plugins.retrieve("plugin_1", organization_id: "org_1").name.should eq("linter")
      client.beta.organization.plugins.update("plugin_1", served_version_id: "pv_1").served_version_id.should eq("pv_1")
      client.beta.organization.plugins.list(created_at_gt: "2026-10-01T00:00:00Z", owner_type: "organization").data.size.should eq(1)
      client.beta.organization.plugins.delete("plugin_1").type.should eq("plugin_deleted")

      ver = client.beta.organization.plugins.versions.create("plugin_1", files: [file], release_notes: "v1.1")
      ver.created_by.should be_a(Anthropic::BetaPluginAPIActor)
      v_create_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
      client.beta.organization.plugins.versions.retrieve("plugin_1", "pv_2").id.should eq("pv_2")
      client.beta.organization.plugins.versions.list("plugin_1").data.size.should eq(1)

      downloaded = client.beta.organization.plugins.versions.download("plugin_1", "pv_2", organization_id: "org_1")
      downloaded.gets_to_end.should eq("ZIPDATA")
      dl_cap.not_nil!.headers["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
      dl_cap.not_nil!.headers["accept"].should eq("application/binary")

      client.beta.organization.plugins.installation_settings.list("plugin_1").data.first.target.should be_a(Anthropic::BetaPluginTargetRbacGroup)
      pref = client.beta.organization.plugins.installation_settings.set("plugin_1", "rg_1", Anthropic::BetaPluginInstallationPreference::REQUIRED)
      pref.installation_preference.should eq("required")
      set_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
      client.beta.organization.plugins.installation_settings.remove("plugin_1", "rg_1").type.should eq("plugin_installation_setting_deleted")
      client.beta.organization.plugins.shares.list("plugin_1").data.first.target.should be_a(Anthropic::BetaPluginTargetOrganizationMember)
    end

    it "manages plugin marketplaces and validates archives with field name 'archive'" do
      mp_json = %({
        "id": "mp_1",
        "created_at": "2026-10-21T00:00:00Z",
        "default_installation_preference": "available",
        "last_sync_ended_at": null,
        "last_sync_read_sha": null,
        "name": "Corp",
        "owner": {"type": "organization"},
        "source": "github",
        "sync_status": "success",
        "type": "plugin_marketplace"
      })
      report_json = %({
        "commit_sha": "abc123",
        "manifest_error": null,
        "manifest_error_code": null,
        "plugin_errors": [],
        "plugin_warnings": [],
        "ref": "main",
        "total_plugin_count": 3,
        "type": "plugin_marketplace_validation_report",
        "valid": true
      })

      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugin_marketplaces/mp_1", mp_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugin_marketplaces/mp_1", mp_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/plugin_marketplaces?source=github", %({"data":[#{mp_json}],"next_page":null}))
      arc_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugin_marketplaces/validate_archive", report_json)
      repo_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/plugin_marketplaces/validate_repository", report_json)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.organization.plugin_marketplaces.retrieve("mp_1").sync_status.should eq("success")
      client.beta.organization.plugin_marketplaces.update("mp_1", default_installation_preference: "auto_install")
      client.beta.organization.plugin_marketplaces.list(source: "github").data.size.should eq(1)

      archive = Anthropic::FileUpload.from_bytes("PK...".to_slice, content_type: "application/zip", filename: "mp.zip")
      rep = client.beta.organization.plugin_marketplaces.validate_archive(archive)
      rep.valid?.should be_true
      arc_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
      arc_cap.body.not_nil!.should contain("name=\"archive\"; filename=\"mp.zip\"")

      repo_rep = client.beta.organization.plugin_marketplaces.validate_repository("https://github.com/acme/mp", ref: "main")
      repo_rep.total_plugin_count.should eq(3)
      repo_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::CE_PLUGINS_BETA)
    end
  end

  describe "Beta telemetry destinations, webhooks, and claude_tag" do
    it "manages telemetry destinations with null clearing and workspace add/remove" do
      dest_json = %({
        "id": "tdst_1",
        "created_at": "2026-10-21T00:00:00Z",
        "delivery_health": {"last_error": null, "last_error_at": null, "last_success_at": "2026-10-21T01:00:00Z"},
        "display_name": "Datadog",
        "endpoint_url": "https://otel.test/v1",
        "header_names": ["x-api-key"],
        "state": {"type": "enabled"},
        "traces": {"content_mode": "metadata_only", "enabled": true, "endpoint_url": null, "max_content_bytes": null},
        "type": "telemetry_destination",
        "updated_at": "2026-10-21T00:00:00Z",
        "workspaces": {"type": "include"}
      })
      ws_json = %({"created_at":"2026-10-21T00:00:00Z","telemetry_destination_id":"tdst_1","type":"telemetry_destination_workspace","workspace_id":"ws_1"})

      c_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/telemetry_destinations", dest_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1", dest_json)
      u_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1", dest_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/telemetry_destinations", %({"data":[#{dest_json}],"next_page":null}))
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1", %({"id":"tdst_1","type":"telemetry_destination_deleted"}))
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1/test", %({"result":{"type":"failure","error":"timeout"},"type":"telemetry_destination_test"}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1/workspaces", %({"data":[#{ws_json}],"next_page":null}))
      add_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1/workspaces/ws_1", ws_json)
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/telemetry_destinations/tdst_1/workspaces/ws_1", %({"telemetry_destination_id":"tdst_1","type":"telemetry_destination_workspace_deleted","workspace_id":"ws_1"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      created = client.beta.organization.telemetry_destinations.create(
        endpoint_url: "https://otel.test/v1",
        workspaces: Anthropic::BetaTelemetryDestinationWorkspacesInclude.new(workspace_ids: ["ws_1"]),
        display_name: "Datadog",
        headers: {"x-api-key" => "secret"}
      )
      created.workspaces.should be_a(Anthropic::BetaTelemetryDestinationWorkspacesInclude)
      c_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::TELEMETRY_DESTINATIONS_BETA)

      client.beta.organization.telemetry_destinations.retrieve("tdst_1").state.should be_a(Anthropic::BetaTelemetryDestinationStateEnabled)
      client.beta.organization.telemetry_destinations.update(
        "tdst_1",
        display_name: nil,
        headers: {"x-old" => nil, "x-new" => "ok"} of String => String?,
        traces: nil
      )
      sent_u = JSON.parse(u_cap.body.not_nil!)
      sent_u.as_h.has_key?("display_name").should be_true
      sent_u["display_name"].raw.should be_nil
      sent_u.as_h.has_key?("traces").should be_true
      sent_u["traces"].raw.should be_nil
      sent_u["headers"]["x-old"].raw.should be_nil
      sent_u["headers"]["x-new"].as_s.should eq("ok")

      client.beta.organization.telemetry_destinations.list.data.size.should eq(1)
      client.beta.organization.telemetry_destinations.delete("tdst_1").type.should eq("telemetry_destination_deleted")
      client.beta.organization.telemetry_destinations.test("tdst_1").result.as(Anthropic::BetaTelemetryDestinationTestFailure).error.should eq("timeout")

      client.beta.organization.telemetry_destinations.workspaces.list("tdst_1").data.first.workspace_id.should eq("ws_1")
      added = client.beta.organization.telemetry_destinations.workspaces.add("tdst_1", "ws_1")
      added.telemetry_destination_id.should eq("tdst_1")
      add_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::TELEMETRY_DESTINATIONS_BETA)
      client.beta.organization.telemetry_destinations.workspaces.remove("tdst_1", "ws_1").type.should eq("telemetry_destination_workspace_deleted")
    end

    it "manages organization webhook endpoints and signing secret regeneration" do
      ep_json = %({
        "id": "wh_1",
        "created_at": "2026-10-21T00:00:00Z",
        "description": "Audit",
        "disabled_reason": "",
        "enabled_events": ["user_profile.enforcement_action_opened"],
        "name": "sec",
        "state": "enabled",
        "updated_at": "2026-10-21T00:00:00Z",
        "url": "https://hooks.test/events"
      })
      new_ep_json = %({
        "id": "wh_1",
        "created_at": "2026-10-21T00:00:00Z",
        "description": "Audit",
        "disabled_reason": "",
        "enabled_events": ["user_profile.enforcement_action_opened"],
        "name": "sec",
        "signing_secret": "whsec_initial",
        "state": "enabled",
        "updated_at": "2026-10-21T00:00:00Z",
        "url": "https://hooks.test/events"
      })

      c_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/webhooks", new_ep_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/webhooks/wh_1", ep_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/webhooks/wh_1", ep_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/webhooks?limit=10&order=asc", %({"data":[#{ep_json}],"has_more":false,"first_id":"wh_1","last_id":"wh_1"}))
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/webhooks/wh_1", %({"id":"wh_1","type":"webhook_endpoint_deleted"}))
      r_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/webhooks/wh_1/regenerate_signing_secret", %({"signing_secret":"whsec_rotated"}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      created = client.beta.organization.webhooks.create(
        enabled_events: [Anthropic::BetaOrganizationWebhookEndpointEnabledEvent::USER_PROFILE_ENFORCEMENT_ACTION_OPENED],
        url: "https://hooks.test/events",
        name: "sec",
        description: "Audit"
      )
      created.signing_secret.should eq("whsec_initial")
      c_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::WEBHOOKS_BETA)

      client.beta.organization.webhooks.retrieve("wh_1").state.should eq("enabled")
      client.beta.organization.webhooks.update("wh_1", state: "disabled").id.should eq("wh_1")
      client.beta.organization.webhooks.list(limit: 10, order: "asc").data.size.should eq(1)
      client.beta.organization.webhooks.delete("wh_1").type.should eq("webhook_endpoint_deleted")
      regen = client.beta.organization.webhooks.regenerate_signing_secret("wh_1")
      regen.signing_secret.should eq("whsec_rotated")
      r_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::WEBHOOKS_BETA)
    end

    it "manages Claude Tag bundles, unwrapped targets, slack channels, and slack workspaces" do
      bundle_json = %({"id":"bnd_1","created_at":"2026-10-21T00:00:00Z","description":"Eng","display_name":"Eng","type":"bundle","updated_at":"2026-10-21T00:00:00Z"})
      target_ch_json = %({"id":"tgt_1","created_at":"2026-10-21T00:00:00Z","slack_channel_id":"C123","type":"slack_channel"})
      target_ws_json = %({"id":"tgt_2","created_at":"2026-10-21T00:00:00Z","slack_workspace_id":"T123","type":"slack_workspace"})
      chan_json = %({
        "id": "sc_1",
        "created_at": "2026-10-21T00:00:00Z",
        "settings": {"enabled": true, "environment_id": "env_1", "guest_policy": {"type": "channel_only"}, "instructions": "Be brief", "model": "claude-sonnet-4-6", "reply_mode": {"type": "thread"}},
        "slack": {"channel_id": "C123", "workspace_id": "T123"},
        "sources": {"enabled": {"type": "slack_channel", "slack_channel_id": "C123"}, "environment_id": {"type": "default"}, "guest_policy": {"type": "slack_workspace", "slack_workspace_id": "T123"}, "instructions": [{"type": "slack_default"}], "model": {"type": "default"}, "reply_mode": {"type": "slack_channel", "slack_channel_id": "C123"}},
        "type": "slack_channel",
        "updated_at": "2026-10-21T00:00:00Z"
      })
      sws_json = %({
        "id": "sws_1",
        "created_at": "2026-10-21T00:00:00Z",
        "settings": {"enabled": true, "environment_id": null, "guest_policy": null, "instructions": null, "model": null, "reply_mode": null},
        "slack": {"workspace_id": "T123"},
        "sources": {"enabled": null, "environment_id": null, "guest_policy": null, "instructions": [], "model": null, "reply_mode": null},
        "type": "slack_workspace",
        "updated_at": "2026-10-21T00:00:00Z"
      })

      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/bundles", %({"data":[#{bundle_json}],"next_page":null}))
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/bundles/bnd_1", bundle_json)
      t_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/claude_tag/bundles/bnd_1/targets", target_ch_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/bundles/bnd_1/targets/tgt_2", target_ws_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/bundles/bnd_1/targets", %({"data":[#{target_ch_json},#{target_ws_json}],"next_page":null}))
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/claude_tag/bundles/bnd_1/targets/tgt_1", %({"id":"tgt_1","type":"bundle_target_deleted"}))

      sc_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/claude_tag/slack_channels", chan_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/slack_channels/sc_1?include_inherited=true", chan_json)
      stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/claude_tag/slack_channels/sc_1", chan_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/slack_channels?slack_workspace_id=T123", %({"data":[#{chan_json}],"next_page":null}))
      stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/claude_tag/slack_channels/sc_1", %({"id":"sc_1","type":"slack_channel_deleted"}))

      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/slack_workspaces/sws_1", sws_json)
      sws_cap = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/claude_tag/slack_workspaces/sws_1", sws_json)
      stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/claude_tag/slack_workspaces", %({"data":[#{sws_json}],"next_page":null}))

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.organization.claude_tag.bundles.list.data.first.display_name.should eq("Eng")
      client.beta.organization.claude_tag.bundles.retrieve("bnd_1").id.should eq("bnd_1")

      tgt = client.beta.organization.claude_tag.bundles.targets.create(
        "bnd_1",
        target: Anthropic::BetaClaudeTagSlackChannelBundleTargetCreate.new(slack_channel_id: "C123")
      )
      tgt.as(Anthropic::BetaClaudeTagSlackChannelBundleTarget).slack_channel_id.should eq("C123")
      t_sent = JSON.parse(t_cap.body.not_nil!)
      t_sent["type"].as_s.should eq("slack_channel")
      t_sent["slack_channel_id"].as_s.should eq("C123")
      t_sent.as_h.has_key?("target").should be_false
      t_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::EXPERIMENTAL_CLAUDE_TAG_BETA)

      client.beta.organization.claude_tag.bundles.targets.retrieve("bnd_1", "tgt_2").should be_a(Anthropic::BetaClaudeTagSlackWorkspaceBundleTarget)
      client.beta.organization.claude_tag.bundles.targets.list("bnd_1").data.size.should eq(2)
      client.beta.organization.claude_tag.bundles.targets.delete("bnd_1", "tgt_1").type.should eq("bundle_target_deleted")

      ch = client.beta.organization.claude_tag.slack_channels.create(
        slack: Anthropic::BetaClaudeTagSlackChannelIdentifiers.new(channel_id: "C123", workspace_id: "T123"),
        settings: Anthropic::BetaClaudeTagSettingsParam.new(
          enabled: true,
          guest_policy: Anthropic::BetaClaudeTagGuestPolicyChannelOnly.new,
          reply_mode: Anthropic::BetaClaudeTagReplyModeThread.new
        )
      )
      ch.settings.reply_mode.should be_a(Anthropic::BetaClaudeTagReplyModeThread)
      ch.sources.instructions.first.should be_a(Anthropic::BetaClaudeTagSlackDefaultSettingSource)
      sc_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::EXPERIMENTAL_CLAUDE_TAG_BETA)

      client.beta.organization.claude_tag.slack_channels.retrieve("sc_1", include_inherited: true)
      client.beta.organization.claude_tag.slack_channels.update("sc_1", settings: Anthropic::BetaClaudeTagSettingsParam.new(instructions: nil))
      client.beta.organization.claude_tag.slack_channels.list(slack_workspace_id: "T123").data.size.should eq(1)
      client.beta.organization.claude_tag.slack_channels.delete("sc_1").type.should eq("slack_channel_deleted")

      client.beta.organization.claude_tag.slack_workspaces.retrieve("sws_1").slack.workspace_id.should eq("T123")
      client.beta.organization.claude_tag.slack_workspaces.update("sws_1", settings: Anthropic::BetaClaudeTagSettingsParam.new(model: "claude-sonnet-4-6"))
      sws_cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::EXPERIMENTAL_CLAUDE_TAG_BETA)
      client.beta.organization.claude_tag.slack_workspaces.list.data.size.should eq(1)
    end
  end

  describe "Path segment validation and escaping" do
    it "rejects empty/traversal IDs and encodes slash-containing IDs" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      expect_raises(ArgumentError) { client.organization.rbac_groups.retrieve("..") }
      expect_raises(ArgumentError) { client.beta.organization.webhooks.retrieve("") }
      expect_raises(ArgumentError) { client.beta.organization.plugins.retrieve(".") }
      expect_raises(ArgumentError) { client.beta.organization.spend_limits.delete("..") }
      expect_raises(ArgumentError) { client.beta.organization.telemetry_destinations.retrieve("") }
      expect_raises(ArgumentError) { client.beta.organization.claude_tag.bundles.retrieve(".") }

      cap = stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/webhooks/wh%2F1%20test",
        %({"id":"wh/1 test","created_at":"2026-10-21T00:00:00Z","description":"","disabled_reason":"","enabled_events":[],"name":"","state":"enabled","updated_at":"2026-10-21T00:00:00Z","url":"https://hooks.test"})
      )
      client.beta.organization.webhooks.retrieve("wh/1 test").id.should eq("wh/1 test")
      cap.headers.not_nil!["anthropic-beta"].should eq(Anthropic::WEBHOOKS_BETA)
    end
  end

  describe "Nullable parity and multi-value query params" do
    it "handles nullable scan assessment, plugin components, marketplace status, skill share_status, implicit, and poll_status" do
      scan = Anthropic::BetaPluginContentScan.from_json(%({"assessment":null,"reason":null,"status":"processing"}))
      scan.assessment.should be_nil
      scan.status.should eq("processing")

      plugin = Anthropic::BetaPlugin.from_json(%({
        "id": "plugin_2",
        "components": null,
        "content_scan": null,
        "created_at": "2026-10-21T00:00:00Z",
        "created_by": null,
        "description": null,
        "display_name": null,
        "latest_version_id": "pv_1",
        "manifest_version": null,
        "marketplace_id": "mp_1",
        "name": "empty",
        "organization_installation_preference": null,
        "organization_installation_preference_inherited": null,
        "owner": {"type": "user", "user_id": "user_1"},
        "reach": null,
        "served_version_id": "pv_1",
        "served_version_pinned": false,
        "type": "plugin",
        "updated_at": "2026-10-21T00:00:00Z"
      }))
      plugin.components.should be_nil

      version = Anthropic::BetaPluginVersion.from_json(%({
        "id": "pv_1",
        "components": null,
        "content_scan": null,
        "created_at": "2026-10-21T00:00:00Z",
        "created_by": null,
        "description": null,
        "display_name": null,
        "manifest_version": null,
        "plugin_id": "plugin_2",
        "reach": null,
        "release_notes": null,
        "type": "plugin_version"
      }))
      version.components.should be_nil

      mp = Anthropic::BetaPluginMarketplace.from_json(%({
        "id": "mp_2",
        "created_at": "2026-10-21T00:00:00Z",
        "default_installation_preference": null,
        "last_sync_ended_at": null,
        "last_sync_read_sha": null,
        "name": "Personal",
        "owner": {"type": "user", "user_id": "user_1"},
        "source": "manual",
        "sync_status": null,
        "type": "plugin_marketplace"
      }))
      mp.default_installation_preference.should be_nil
      mp.sync_status.should be_nil

      skill = Anthropic::AnalyticsSkillActivity.from_json(%({
        "attributed_list_price": null,
        "chat_metrics": {"distinct_conversation_skill_used_count": 0},
        "claude_code_metrics": {"distinct_session_skill_used_count": 0},
        "cowork_metrics": {"distinct_session_skill_used_count": 0},
        "currency": null,
        "distinct_user_count": 1,
        "enable_count": null,
        "estimated_overage_spend": null,
        "invocation_count": null,
        "office_metrics": {"excel":{"distinct_session_skill_used_count":0},"outlook":{"distinct_session_skill_used_count":0},"powerpoint":{"distinct_session_skill_used_count":0},"word":{"distinct_session_skill_used_count":0}},
        "share_status": null,
        "skill_display_name": null,
        "skill_name": "internal"
      }))
      skill.share_status.should be_nil

      member = Anthropic::ServiceAccountWorkspaceMember.from_json(%({
        "created_by_actor_id": null,
        "implicit": null,
        "service_account_id": "sa_1",
        "type": "service_account_workspace_member",
        "workspace_id": "ws_1",
        "workspace_role": "workspace_developer"
      }))
      member.implicit.should be_nil
      member.implicit?.should be_false

      issuer = Anthropic::FederationIssuer.from_json(%({
        "id": "iss_2",
        "archived_at": null,
        "archived_by_actor_id": null,
        "check_jti": false,
        "created_at": "2026-10-21T00:00:00Z",
        "created_by_actor_id": null,
        "issuer_url": "https://issuer.test",
        "jwks": {"type": "inline", "keys": []},
        "jwks_polling_disabled_at": null,
        "max_jwt_lifetime_seconds": 3600,
        "name": "inline",
        "poll_status": null,
        "type": "federation_issuer",
        "updated_at": "2026-10-21T00:00:00Z",
        "updated_by_actor_id": null
      }))
      issuer.poll_status.should be_nil

      poll = Anthropic::FederationIssuerPollStatus.from_json(%({"consecutive_failures":0,"last_fetched_at":null,"next_poll_at":null}))
      poll.last_fetched_at.should be_nil
      poll.next_poll_at.should be_nil
    end

    it "supports array period filters on spend_limits.effective and explicit null content_mode on traces params" do
      stub_and_capture(
        :get,
        "https://api.anthropic.com/v1/organizations/spend_limits/effective?period%5B%5D=daily&period%5B%5D=monthly",
        %({"data":[],"next_page":null})
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.organization.spend_limits.effective.list(period: ["daily", "monthly"]).data.should be_empty

      traces = Anthropic::BetaTelemetryDestinationTracesParams.new(content_mode: nil)
      parsed = JSON.parse(traces.to_json)
      parsed.as_h.has_key?("content_mode").should be_true
      parsed["content_mode"].raw.should be_nil
    end
  end
end
