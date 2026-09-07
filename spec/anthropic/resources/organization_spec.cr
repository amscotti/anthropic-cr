require "../../spec_helper"

describe Anthropic::BetaOrganizations do
  org_json = %({"id":"org_123","name":"Acme","type":"organization"})

  it "retrieves the organization" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/me?beta=true", org_json)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    org = client.beta.organization.retrieve

    org.id.should eq("org_123")
    org.name.should eq("Acme")
    capture.method.should eq("GET")
  end

  it "lists API keys" do
    body = %({"data":[{"id":"apikey_1","created_at":"2026-01-01T00:00:00Z","created_by":{"type":"user","user_id":"user_1"},"expires_at":"2027-01-01T00:00:00Z","name":"prod","partial_key_hint":"sk-ant-...xyz","principal":{"type":"organization_scope"},"scope":{"type":"organization"},"status":"active","type":"api_key","workspace_id":"ws_1"}],"has_more":false,"first_id":"apikey_1","last_id":"apikey_1"})
    stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/api_keys?beta=true&limit=10", body)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    keys = client.beta.organization.api_keys.list(limit: 10)

    keys.data.size.should eq(1)
    keys.data.first.name.should eq("prod")
    keys.data.first.status.should eq("active")
  end

  it "updates an API key" do
    body = %({"id":"apikey_1","created_at":"2026-01-01T00:00:00Z","created_by":{"type":"user"},"expires_at":"2027-01-01T00:00:00Z","name":"renamed","partial_key_hint":"sk-ant-...xyz","principal":{"type":"organization_scope"},"scope":{"type":"organization"},"status":"archived","type":"api_key","workspace_id":"ws_1"})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/api_keys/apikey_1?beta=true", body)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    key = client.beta.organization.api_keys.update("apikey_1", name: "renamed", status: "archived")

    key.status.should eq("archived")
    sent = JSON.parse(capture.body.not_nil!)
    sent["name"].as_s.should eq("renamed")
  end

  it "creates and deletes invites" do
    invite = %({"id":"invite_1","accepted_at":null,"email":"dev@acme.test","expires_at":"2026-02-01T00:00:00Z","invited_at":"2026-01-01T00:00:00Z","rbac_group_ids":[],"role":"developer","status":"pending","type":"invite"})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/invites?beta=true", invite)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.organization.invites.create(email: "dev@acme.test", role: "developer")
    created.email.should eq("dev@acme.test")
    JSON.parse(capture.body.not_nil!)["role"].as_s.should eq("developer")

    deleted = %({"id":"invite_1","type":"invite_deleted"})
    stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/invites/invite_1?beta=true", deleted)

    result = client.beta.organization.invites.delete("invite_1")
    result.type.should eq("invite_deleted")
  end

  it "updates and removes users" do
    user = %({"id":"user_1","added_at":"2026-01-01T00:00:00Z","email":"dev@acme.test","name":"Dev","role":"admin","type":"user"})
    stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/users/user_1?beta=true", user)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    updated = client.beta.organization.users.update("user_1", "admin")
    updated.role.should eq("admin")

    removed = %({"id":"user_1","type":"user_deleted"})
    stub_and_capture(:delete, "https://api.anthropic.com/v1/organizations/users/user_1?beta=true", removed)

    client.beta.organization.users.remove("user_1").type.should eq("user_deleted")
  end

  it "creates and archives workspaces with members" do
    workspace = %({"id":"ws_1","archived_at":null,"compartment_id":"comp_1","created_at":"2026-01-01T00:00:00Z","data_residency":null,"display_color":"#fff","external_key_id":null,"name":"prod","tags":{},"type":"workspace"})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces?beta=true", workspace)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.organization.workspaces.create(name: "prod")
    created.name.should eq("prod")
    JSON.parse(capture.body.not_nil!)["name"].as_s.should eq("prod")

    member = %({"type":"workspace_member","user_id":"user_1","workspace_id":"ws_1","workspace_role":"admin"})
    stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/workspaces/ws_1/members?beta=true", member)

    added = client.beta.organization.workspaces.members.add("ws_1", "user_1", "admin")
    added.workspace_role.should eq("admin")

    stub_and_capture(
      :post,
      "https://api.anthropic.com/v1/organizations/workspaces/ws_1/archive?beta=true",
      workspace.gsub("\"archived_at\":null", "\"archived_at\":\"2026-03-01T00:00:00Z\"")
    )

    archived = client.beta.organization.workspaces.archive("ws_1")
    archived.archived_at.should eq("2026-03-01T00:00:00Z")
  end

  it "creates service accounts and attaches them to workspaces" do
    account = %({"id":"sa_1","archived_at":null,"archived_by_actor_id":null,"created_at":"2026-01-01T00:00:00Z","created_by_actor_id":"user_1","description":"ci","name":"ci-bot","organization_role":{"type":"organization_role","role":"developer"},"type":"service_account","updated_at":"2026-01-01T00:00:00Z","updated_by_actor_id":"user_1"})
    stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/service_accounts?beta=true", account)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created = client.beta.organization.service_accounts.create(name: "ci-bot", description: "ci")
    created.name.should eq("ci-bot")

    membership = %({"created_by_actor_id":"user_1","implicit":false,"service_account_id":"sa_1","type":"service_account_workspace_member","workspace_id":"ws_1","workspace_role":"developer"})
    stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/service_accounts/sa_1/workspaces?beta=true", membership)

    attached = client.beta.organization.service_accounts.workspaces.add("sa_1", "ws_1", "developer")
    attached.workspace_id.should eq("ws_1")
  end

  it "lists rate limits and reads compliance settings" do
    limits = %({"data":[{"id":"rl_1","group_type":"sessions","limits":{"output_tokens_per_minute":{"type":"limit","value":100000}},"models":["claude-sonnet-5"],"type":"rate_limit"}],"has_more":false,"first_id":"rl_1","last_id":"rl_1"})
    stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/rate_limits?beta=true&limit=20", limits)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    listed = client.beta.organization.rate_limits.list
    listed.data.size.should eq(1)
    listed.data.first.group_type.should eq("sessions")

    settings = %({"state":{"type":"disabled"},"type":"compliance_settings"})
    stub_and_capture(:get, "https://api.anthropic.com/v1/organizations/compliance_settings?beta=true", settings)

    client.beta.organization.compliance_settings.retrieve.type.should eq("compliance_settings")
  end

  it "validates external keys" do
    validation = %({"error":null,"status":"valid","type":"external_key_validation"})
    stub_and_capture(
      :post,
      "https://api.anthropic.com/v1/organizations/external_keys/ek_1/validate?beta=true",
      validation
    )
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    result = client.beta.organization.external_keys.validate("ek_1")
    result.status.should eq("valid")
  end

  it "creates federation issuers and rules" do
    issuer = %({"id":"iss_1","archived_at":null,"archived_by_actor_id":null,"check_jti":true,"created_at":"2026-01-01T00:00:00Z","created_by_actor_id":"user_1","issuer_url":"https://issuer.test","jwks":{"type":"discovery"},"jwks_polling_disabled_at":null,"max_jwt_lifetime_seconds":3600,"name":"main","poll_status":{"consecutive_failures":0,"last_fetched_at":"2026-01-01T00:00:00Z","next_poll_at":"2026-01-02T00:00:00Z"},"type":"federation_issuer","updated_at":"2026-01-01T00:00:00Z","updated_by_actor_id":"user_1"})
    stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/federation_issuers?beta=true", issuer)
    client = Anthropic::Client.new(api_key: "sk-ant-test")

    created_issuer = client.beta.organization.federation.issuers.create(
      issuer_url: "https://issuer.test",
      name: "main"
    )
    created_issuer.issuer_url.should eq("https://issuer.test")
    created_issuer.poll_status.consecutive_failures.should eq(0)

    rule = %({"id":"rule_1","applies_to_all_workspaces":true,"archived_at":null,"archived_by_actor_id":null,"attributes":{},"created_at":"2026-01-01T00:00:00Z","created_by_actor_id":"user_1","description":"ci","issuer_id":"iss_1","issuer_name":"main","match":{"audience":"ci"},"name":"ci-rule","oauth_scope":"ci:run","target":{"type":"service_account","service_account_id":"sa_1"},"token_lifetime_seconds":3600,"type":"federation_rule","updated_at":"2026-01-01T00:00:00Z","updated_by_actor_id":"user_1","workspace_id":null,"workspace_ids":[]})
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/organizations/federation_rules?beta=true", rule)

    created_rule = client.beta.organization.federation.rules.create(
      issuer_id: "iss_1",
      match: Anthropic::BetaFederationRuleMatch.new(audience: "ci"),
      name: "ci-rule",
      oauth_scope: "ci:run",
      target: JSON.parse(%({"type":"service_account","service_account_id":"sa_1"}))
    )
    created_rule.name.should eq("ci-rule")
    created_rule.match.audience.should eq("ci")
    JSON.parse(capture.body.not_nil!)["oauth_scope"].as_s.should eq("ci:run")
  end
end
