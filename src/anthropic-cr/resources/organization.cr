module Anthropic
  # Shared internal helpers for query-string, JSON-body, and beta-header
  # assembly across organization admin resource classes.
  module OrganizationHelpers
    alias QueryHash = Hash(String, String | Array(String))

    def self.beta_headers(
      required_betas : Array(String) = [] of String,
      extra_betas : Array(String) = [] of String,
    ) : Hash(String, String)?
      combined = [] of String
      required_betas.each { |beta| combined << beta unless combined.includes?(beta) }
      extra_betas.each { |beta| combined << beta unless combined.includes?(beta) }
      return nil if combined.empty?

      {"anthropic-beta" => combined.join(",")}
    end

    def self.set_query(query : QueryHash, key : String, value : String?) : Nil
      query[key] = value if value
    end

    def self.set_query(query : QueryHash, key : String, value : Int32?) : Nil
      query[key] = value.to_s if value
    end

    def self.set_query(query : QueryHash, key : String, value : Bool?) : Nil
      query[key] = value.to_s unless value.nil?
    end

    def self.set_query(query : QueryHash, key : String, value : Array(String)?) : Nil
      query[key] = value if value
    end

    def self.set_json_opt(body : Hash(String, JSON::Any), key : String, value : String?) : Nil
      body[key] = JSON::Any.new(value) if value
    end

    def self.set_json_opt(body : Hash(String, JSON::Any), key : String, value : Int64?) : Nil
      body[key] = JSON::Any.new(value) if value
    end

    def self.set_json_opt(body : Hash(String, JSON::Any), key : String, value : Bool?) : Nil
      body[key] = JSON::Any.new(value) unless value.nil?
    end

    def self.set_json_any(body : Hash(String, JSON::Any), key : String, value) : Nil
      body[key] = JSON.parse(value.to_json) unless value.nil?
    end
  end

  # Organization Admin API (GA).
  #
  # Access via `client.organization`. Retrieve organization details with
  # `#retrieve`, then manage API keys, external keys, invites, users,
  # workspaces, service accounts, federation, rate limits, compliance
  # settings, RBAC groups and roles, spend limits, and analytics through
  # the sub-resources below.
  #
  # ```
  # org = client.organization.retrieve
  # puts org.name
  #
  # keys = client.organization.api_keys.list(limit: 10)
  # ```
  class Organizations
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve information about the organization associated with the
    # authenticated API key.
    def retrieve : Organization
      response = @client.get("/v1/organizations/me", beta: @beta)
      Organization.from_json(response.body)
    end

    def api_keys : OrganizationAPIKeys
      OrganizationAPIKeys.new(@client, beta: @beta)
    end

    def external_keys : OrganizationExternalKeys
      OrganizationExternalKeys.new(@client, beta: @beta)
    end

    def invites : OrganizationInvites
      OrganizationInvites.new(@client, beta: @beta)
    end

    def users : OrganizationUsers
      OrganizationUsers.new(@client, beta: @beta)
    end

    def workspaces : OrganizationWorkspaces
      OrganizationWorkspaces.new(@client, beta: @beta)
    end

    def service_accounts : OrganizationServiceAccounts
      OrganizationServiceAccounts.new(@client, beta: @beta)
    end

    def federation : OrganizationFederation
      OrganizationFederation.new(@client, beta: @beta)
    end

    def rate_limits : OrganizationRateLimits
      OrganizationRateLimits.new(@client, beta: @beta)
    end

    def compliance_settings : OrganizationComplianceSettings
      OrganizationComplianceSettings.new(@client, beta: @beta)
    end

    def rbac_groups : OrganizationRbacGroups
      OrganizationRbacGroups.new(@client, beta: @beta)
    end

    def rbac_roles : OrganizationRbacRoles
      OrganizationRbacRoles.new(@client, beta: @beta)
    end

    def spend_limits : OrganizationSpendLimits
      OrganizationSpendLimits.new(@client, beta: @beta)
    end

    def analytics : OrganizationAnalytics
      OrganizationAnalytics.new(@client, beta: @beta)
    end
  end

  # Organization Admin API (beta surface).
  #
  # Access via `client.beta.organization`. Mirrors all GA organization
  # sub-resources and exposes beta-only capabilities (`users.sign_out`,
  # `spend_limits` CRUD, `analytics.usage`/`cost`/legacy reports, `plugins`,
  # `plugin_marketplaces`, `telemetry_destinations`, `webhooks`, and
  # `claude_tag`).
  class BetaOrganizations < Organizations
    def initialize(client : Client)
      super(client, beta: true)
    end

    def users : BetaOrganizationUsers
      BetaOrganizationUsers.new(@client)
    end

    def spend_limits : BetaOrganizationSpendLimits
      BetaOrganizationSpendLimits.new(@client)
    end

    def analytics : BetaOrganizationAnalytics
      BetaOrganizationAnalytics.new(@client)
    end

    def plugins : BetaOrganizationPlugins
      BetaOrganizationPlugins.new(@client)
    end

    def plugin_marketplaces : BetaOrganizationPluginMarketplaces
      BetaOrganizationPluginMarketplaces.new(@client)
    end

    def telemetry_destinations : BetaOrganizationTelemetryDestinations
      BetaOrganizationTelemetryDestinations.new(@client)
    end

    def webhooks : BetaOrganizationWebhooks
      BetaOrganizationWebhooks.new(@client)
    end

    def claude_tag : BetaOrganizationClaudeTag
      BetaOrganizationClaudeTag.new(@client)
    end
  end

  # Organization API keys.
  class OrganizationAPIKeys
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve an API key by ID.
    def retrieve(api_key_id : String) : APIKey
      response = @client.get("/v1/organizations/api_keys/#{Anthropic.encode_path_segment(api_key_id)}", beta: @beta)
      APIKey.from_json(response.body)
    end

    # Update an API key's name or status (`"active"`, `"archived"`, or `"inactive"`).
    def update(
      api_key_id : String,
      name : String? = nil,
      status : String? = nil,
    ) : APIKey
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "name", name)
      OrganizationHelpers.set_json_opt(body, "status", status)

      response = @client.post("/v1/organizations/api_keys/#{Anthropic.encode_path_segment(api_key_id)}", body, beta: @beta)
      APIKey.from_json(response.body)
    end

    # List API keys with optional filtering and pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      after_id : String? = nil,
      before_id : String? = nil,
      created_by_user_id : String? = nil,
      status : String? = nil,
      workspace_id : String? = nil,
    ) : APIKeyListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "created_by_user_id", created_by_user_id)
      OrganizationHelpers.set_query(query, "status", status)
      OrganizationHelpers.set_query(query, "workspace_id", workspace_id)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/api_keys", query, beta: @beta)
      APIKeyListResponse.from_json(response.body)
    end
  end

  class BetaOrganizationAPIKeys < OrganizationAPIKeys
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization external (BYO-cloud) keys.
  #
  # `provider_config` accepts the raw provider configuration object
  # (AWS/GCP/Azure shapes); it is sent through untouched.
  class OrganizationExternalKeys
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Create an external key.
    def create(
      provider_config : JSON::Any | Hash(String, JSON::Any),
      display_name : String? = nil,
      geo : String? = nil,
      user_profile_id : String? = nil,
    ) : ExternalKey
      body = {} of String => JSON::Any
      body["provider_config"] = JSON.parse(provider_config.to_json)
      OrganizationHelpers.set_json_opt(body, "display_name", display_name)
      OrganizationHelpers.set_json_opt(body, "geo", geo)
      OrganizationHelpers.set_json_opt(body, "user_profile_id", user_profile_id)

      response = @client.post("/v1/organizations/external_keys", body, beta: @beta)
      ExternalKey.from_json(response.body)
    end

    # Retrieve an external key by ID.
    def retrieve(external_key_id : String) : ExternalKey
      response = @client.get("/v1/organizations/external_keys/#{Anthropic.encode_path_segment(external_key_id)}", beta: @beta)
      ExternalKey.from_json(response.body)
    end

    # Update an external key.
    def update(
      external_key_id : String,
      display_name : String? = nil,
      geo : String? = nil,
      provider_config : JSON::Any | Hash(String, JSON::Any)? = nil,
    ) : ExternalKey
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "display_name", display_name)
      OrganizationHelpers.set_json_opt(body, "geo", geo)
      OrganizationHelpers.set_json_any(body, "provider_config", provider_config)

      response = @client.post("/v1/organizations/external_keys/#{Anthropic.encode_path_segment(external_key_id)}", body, beta: @beta)
      ExternalKey.from_json(response.body)
    end

    # List external keys with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : ExternalKeyListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/external_keys", query, beta: @beta)
      ExternalKeyListResponse.from_json(response.body)
    end

    # Delete an external key.
    def delete(external_key_id : String) : DeletedExternalKey
      response = @client.delete("/v1/organizations/external_keys/#{Anthropic.encode_path_segment(external_key_id)}", beta: @beta)
      DeletedExternalKey.from_json(response.body)
    end

    # Validate an external key's credentials.
    def validate(external_key_id : String) : ExternalKeyValidation
      response = @client.post(
        "/v1/organizations/external_keys/#{Anthropic.encode_path_segment(external_key_id)}/validate",
        {} of String => JSON::Any,
        beta: @beta
      )
      ExternalKeyValidation.from_json(response.body)
    end
  end

  class BetaOrganizationExternalKeys < OrganizationExternalKeys
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization invites.
  class OrganizationInvites
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Invite a user by email with an organization role.
    def create(
      email : String,
      role : String,
      rbac_group_ids : Array(String)? = nil,
    ) : OrganizationInvite
      body = {} of String => JSON::Any
      body["email"] = JSON::Any.new(email)
      body["role"] = JSON::Any.new(role)
      OrganizationHelpers.set_json_any(body, "rbac_group_ids", rbac_group_ids)

      response = @client.post("/v1/organizations/invites", body, beta: @beta)
      OrganizationInvite.from_json(response.body)
    end

    # Retrieve an invite by ID.
    def retrieve(invite_id : String) : OrganizationInvite
      response = @client.get("/v1/organizations/invites/#{Anthropic.encode_path_segment(invite_id)}", beta: @beta)
      OrganizationInvite.from_json(response.body)
    end

    # List invites with optional filtering and pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      after_id : String? = nil,
      before_id : String? = nil,
      email : String? = nil,
      roles : Array(String)? = nil,
      statuses : Array(String)? = nil,
    ) : OrganizationInviteListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "email", email)
      OrganizationHelpers.set_query(query, "roles", roles)
      OrganizationHelpers.set_query(query, "statuses", statuses)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/invites", query, beta: @beta)
      OrganizationInviteListResponse.from_json(response.body)
    end

    # Delete (revoke) an invite.
    def delete(invite_id : String) : DeletedInvite
      response = @client.delete("/v1/organizations/invites/#{Anthropic.encode_path_segment(invite_id)}", beta: @beta)
      DeletedInvite.from_json(response.body)
    end
  end

  class BetaOrganizationInvites < OrganizationInvites
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization users.
  class OrganizationUsers
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve a user by ID.
    def retrieve(user_id : String) : OrganizationUser
      response = @client.get("/v1/organizations/users/#{Anthropic.encode_path_segment(user_id)}", beta: @beta)
      OrganizationUser.from_json(response.body)
    end

    # Update a user's organization role.
    def update(user_id : String, role : String) : OrganizationUser
      body = {"role" => JSON::Any.new(role)}

      response = @client.post("/v1/organizations/users/#{Anthropic.encode_path_segment(user_id)}", body, beta: @beta)
      OrganizationUser.from_json(response.body)
    end

    # List users with optional filtering and pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      after_id : String? = nil,
      before_id : String? = nil,
      email : String? = nil,
      roles : Array(String)? = nil,
    ) : OrganizationUserListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "email", email)
      OrganizationHelpers.set_query(query, "roles", roles)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/users", query, beta: @beta)
      OrganizationUserListResponse.from_json(response.body)
    end

    # Remove a user from the organization.
    def remove(user_id : String) : DeletedOrganizationUser
      response = @client.delete("/v1/organizations/users/#{Anthropic.encode_path_segment(user_id)}", beta: @beta)
      DeletedOrganizationUser.from_json(response.body)
    end
  end

  # Beta organization users resource adding session sign-out.
  class BetaOrganizationUsers < OrganizationUsers
    def initialize(client : Client)
      super(client, beta: true)
    end

    # Sign a member out of Claude everywhere, without removing them from the organization.
    #
    # Sends `anthropic-beta: admin-user-sign-out-2026-10-08`.
    def sign_out(
      user_id : String,
      betas : Array(String) = [] of String,
    ) : BetaOrganizationUser
      headers = OrganizationHelpers.beta_headers([ADMIN_USER_SIGN_OUT_BETA], betas)
      response = @client.post(
        "/v1/organizations/users/#{Anthropic.encode_path_segment(user_id)}/sign_out",
        nil,
        extra_headers: headers,
        beta: true
      )
      BetaOrganizationUser.from_json(response.body)
    end
  end

  # Organization rate limits (read-only, with pagination on list).
  class OrganizationRateLimits
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List rate limits, optionally filtered by group type or model.
    def list(
      group_type : String? = nil,
      limit : Int32 = 20,
      model : String? = nil,
      page : String? = nil,
    ) : OrganizationRateLimitListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "group_type", group_type)
      OrganizationHelpers.set_query(query, "model", model)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/rate_limits", query, beta: @beta)
      OrganizationRateLimitListResponse.from_json(response.body)
    end
  end

  class BetaOrganizationRateLimits < OrganizationRateLimits
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization compliance settings.
  class OrganizationComplianceSettings
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve the current compliance settings.
    def retrieve : ComplianceSettings
      response = @client.get("/v1/organizations/compliance_settings", beta: @beta)
      ComplianceSettings.from_json(response.body)
    end

    # Update compliance settings.
    #
    # `state` is `{type: "enabled", ...}` or `{type: "disabled"}`.
    def update(state : JSON::Any | Hash(String, JSON::Any)) : ComplianceSettings
      body = {"state" => JSON.parse(state.to_json)}

      response = @client.post("/v1/organizations/compliance_settings", body, beta: @beta)
      ComplianceSettings.from_json(response.body)
    end
  end

  class BetaOrganizationComplianceSettings < OrganizationComplianceSettings
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization workspaces.
  class OrganizationWorkspaces
    def initialize(@client : Client, @beta : Bool = false)
    end

    def members : OrganizationWorkspaceMembers
      OrganizationWorkspaceMembers.new(@client, beta: @beta)
    end

    def rate_limits : OrganizationWorkspaceRateLimits
      OrganizationWorkspaceRateLimits.new(@client, beta: @beta)
    end

    def service_accounts : OrganizationWorkspaceServiceAccounts
      OrganizationWorkspaceServiceAccounts.new(@client, beta: @beta)
    end

    # Create a workspace.
    def create(
      name : String,
      data_residency : BetaDataResidency | BetaDataResidencyCreateConfig | Hash(String, JSON::Any)? = nil,
      display_color : String? = nil,
      external_key_id : String? = nil,
      tags : Hash(String, String)? = nil,
      user_profile_id : String? = nil,
    ) : Workspace
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name)
      OrganizationHelpers.set_json_any(body, "data_residency", data_residency)
      OrganizationHelpers.set_json_opt(body, "display_color", display_color)
      OrganizationHelpers.set_json_opt(body, "external_key_id", external_key_id)
      OrganizationHelpers.set_json_any(body, "tags", tags)
      OrganizationHelpers.set_json_opt(body, "user_profile_id", user_profile_id)

      response = @client.post("/v1/organizations/workspaces", body, beta: @beta)
      Workspace.from_json(response.body)
    end

    # Retrieve a workspace by ID.
    def retrieve(workspace_id : String) : Workspace
      response = @client.get("/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}", beta: @beta)
      Workspace.from_json(response.body)
    end

    # Update a workspace. Pass `tags: nil` explicitly to leave tags
    # unchanged; other omitted fields are left unchanged.
    def update(
      workspace_id : String,
      name : String? = nil,
      data_residency : BetaDataResidency | BetaDataResidencyUpdateConfig | Hash(String, JSON::Any)? = nil,
      display_color : String? = nil,
      external_key_id : String? = nil,
      tags : Hash(String, String) | Hash(String, String?) | Nil = nil,
      user_profile_id : String? = nil,
    ) : Workspace
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "name", name)
      OrganizationHelpers.set_json_any(body, "data_residency", data_residency)
      OrganizationHelpers.set_json_opt(body, "display_color", display_color)
      OrganizationHelpers.set_json_opt(body, "external_key_id", external_key_id)
      OrganizationHelpers.set_json_any(body, "tags", tags)
      OrganizationHelpers.set_json_opt(body, "user_profile_id", user_profile_id)

      response = @client.post("/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}", body, beta: @beta)
      Workspace.from_json(response.body)
    end

    # List workspaces with optional filtering and pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      after_id : String? = nil,
      before_id : String? = nil,
      ids : Array(String)? = nil,
      include_archived : Bool? = nil,
      include_default : Bool? = nil,
    ) : WorkspaceListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "ids", ids)
      OrganizationHelpers.set_query(query, "include_archived", include_archived)
      OrganizationHelpers.set_query(query, "include_default", include_default)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/workspaces", query, beta: @beta)
      WorkspaceListResponse.from_json(response.body)
    end

    # Archive a workspace.
    def archive(workspace_id : String) : Workspace
      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/archive",
        {} of String => JSON::Any,
        beta: @beta
      )
      Workspace.from_json(response.body)
    end
  end

  class BetaOrganizationWorkspaces < OrganizationWorkspaces
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Workspace members (user memberships).
  class OrganizationWorkspaceMembers
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve a member by workspace and user ID.
    def retrieve(workspace_id : String, user_id : String) : WorkspaceMember
      response = @client.get(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/members/#{Anthropic.encode_path_segment(user_id)}",
        beta: @beta
      )
      WorkspaceMember.from_json(response.body)
    end

    # Update a member's workspace role.
    def update(workspace_id : String, user_id : String, workspace_role : String) : WorkspaceMember
      body = {"workspace_role" => JSON::Any.new(workspace_role)}

      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/members/#{Anthropic.encode_path_segment(user_id)}",
        body,
        beta: @beta
      )
      WorkspaceMember.from_json(response.body)
    end

    # List members of a workspace.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      after_id : String? = nil,
      before_id : String? = nil,
    ) : WorkspaceMemberListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/members",
        query,
        beta: @beta
      )
      WorkspaceMemberListResponse.from_json(response.body)
    end

    # Add a user to a workspace.
    def add(workspace_id : String, user_id : String, workspace_role : String) : WorkspaceMember
      body = {
        "user_id"        => JSON::Any.new(user_id),
        "workspace_role" => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/members",
        body,
        beta: @beta
      )
      WorkspaceMember.from_json(response.body)
    end

    # Remove a user from a workspace.
    def remove(workspace_id : String, user_id : String) : DeletedWorkspaceMember
      response = @client.delete(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/members/#{Anthropic.encode_path_segment(user_id)}",
        beta: @beta
      )
      DeletedWorkspaceMember.from_json(response.body)
    end
  end

  class BetaOrganizationWorkspaceMembers < OrganizationWorkspaceMembers
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Workspace rate limits (list and per-group override updates).
  class OrganizationWorkspaceRateLimits
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List rate limits for a workspace, optionally including organization defaults.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      group_type : String? = nil,
      include_inherited : Bool? = nil,
    ) : WorkspaceRateLimitListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "group_type", group_type)
      OrganizationHelpers.set_query(query, "include_inherited", include_inherited)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/rate_limits",
        query,
        beta: @beta
      )
      WorkspaceRateLimitListResponse.from_json(response.body)
    end

    # Set or clear workspace rate-limit overrides for a group.
    def update(
      workspace_id : String,
      rate_limit_id : String,
      limits : Array(WorkspaceRateLimitUpdateValue) | JSON::Any,
    ) : WorkspaceRateLimit
      body = {"limits" => JSON.parse(limits.to_json)}

      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/rate_limits/#{Anthropic.encode_path_segment(rate_limit_id)}",
        body,
        beta: @beta
      )
      WorkspaceRateLimit.from_json(response.body)
    end
  end

  class BetaOrganizationWorkspaceRateLimits < OrganizationWorkspaceRateLimits
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Service accounts attached to a workspace.
  class OrganizationWorkspaceServiceAccounts
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve a workspace service account by workspace and account ID.
    def retrieve(workspace_id : String, service_account_id : String) : ServiceAccountWorkspaceMember
      response = @client.get(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}",
        beta: @beta
      )
      ServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Update a workspace service account's role.
    def update(
      workspace_id : String,
      service_account_id : String,
      workspace_role : String,
    ) : ServiceAccountWorkspaceMember
      body = {"workspace_role" => JSON::Any.new(workspace_role)}

      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}",
        body,
        beta: @beta
      )
      ServiceAccountWorkspaceMember.from_json(response.body)
    end

    # List service accounts attached to a workspace.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : ServiceAccountWorkspaceMemberListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/service_accounts",
        query,
        beta: @beta
      )
      ServiceAccountWorkspaceMemberListResponse.from_json(response.body)
    end

    # Attach a service account to a workspace.
    def add(
      workspace_id : String,
      service_account_id : String,
      workspace_role : String,
    ) : ServiceAccountWorkspaceMember
      body = {
        "service_account_id" => JSON::Any.new(service_account_id),
        "workspace_role"     => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/service_accounts",
        body,
        beta: @beta
      )
      ServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Remove a service account from a workspace.
    def remove(workspace_id : String, service_account_id : String) : DeletedServiceAccountWorkspaceMember
      response = @client.delete(
        "/v1/organizations/workspaces/#{Anthropic.encode_path_segment(workspace_id)}/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}",
        beta: @beta
      )
      DeletedServiceAccountWorkspaceMember.from_json(response.body)
    end
  end

  class BetaOrganizationWorkspaceServiceAccounts < OrganizationWorkspaceServiceAccounts
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Organization service accounts.
  class OrganizationServiceAccounts
    def initialize(@client : Client, @beta : Bool = false)
    end

    def workspaces : OrganizationServiceAccountWorkspaces
      OrganizationServiceAccountWorkspaces.new(@client, beta: @beta)
    end

    # Create a service account.
    def create(
      name : String,
      description : String? = nil,
      organization_role : String | JSON::Any? = nil,
    ) : ServiceAccount
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name)
      OrganizationHelpers.set_json_opt(body, "description", description)
      apply_organization_role(body, organization_role)

      response = @client.post("/v1/organizations/service_accounts", body, beta: @beta)
      ServiceAccount.from_json(response.body)
    end

    # Retrieve a service account by ID.
    def retrieve(service_account_id : String) : ServiceAccount
      response = @client.get("/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}", beta: @beta)
      ServiceAccount.from_json(response.body)
    end

    # Update a service account's description or organization role.
    def update(
      service_account_id : String,
      description : String? = nil,
      organization_role : String | JSON::Any? = nil,
    ) : ServiceAccount
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "description", description)
      apply_organization_role(body, organization_role)

      response = @client.post("/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}", body, beta: @beta)
      ServiceAccount.from_json(response.body)
    end

    # List service accounts with optional filtering and pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      include_archived : Bool? = nil,
    ) : ServiceAccountListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_archived", include_archived)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/service_accounts", query, beta: @beta)
      ServiceAccountListResponse.from_json(response.body)
    end

    # Archive a service account.
    def archive(service_account_id : String) : ServiceAccount
      response = @client.post(
        "/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}/archive",
        {} of String => JSON::Any,
        beta: @beta
      )
      ServiceAccount.from_json(response.body)
    end

    private def apply_organization_role(
      body : Hash(String, JSON::Any),
      organization_role : String | JSON::Any?,
    ) : Nil
      case organization_role
      when JSON::Any then body["organization_role"] = organization_role
      when String    then body["organization_role"] = JSON::Any.new(organization_role)
      end
    end
  end

  class BetaOrganizationServiceAccounts < OrganizationServiceAccounts
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Workspaces attached to a service account.
  class OrganizationServiceAccountWorkspaces
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List workspaces a service account belongs to.
    def list(
      service_account_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : ServiceAccountWorkspaceMemberListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}/workspaces",
        query,
        beta: @beta
      )
      ServiceAccountWorkspaceMemberListResponse.from_json(response.body)
    end

    # Attach a service account to a workspace.
    def add(
      service_account_id : String,
      workspace_id : String,
      workspace_role : String,
    ) : ServiceAccountWorkspaceMember
      body = {
        "workspace_id"   => JSON::Any.new(workspace_id),
        "workspace_role" => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}/workspaces",
        body,
        beta: @beta
      )
      ServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Remove a service account from a workspace.
    def remove(service_account_id : String, workspace_id : String) : DeletedServiceAccountWorkspaceMember
      response = @client.delete(
        "/v1/organizations/service_accounts/#{Anthropic.encode_path_segment(service_account_id)}/workspaces/#{Anthropic.encode_path_segment(workspace_id)}",
        beta: @beta
      )
      DeletedServiceAccountWorkspaceMember.from_json(response.body)
    end
  end

  class BetaOrganizationServiceAccountWorkspaces < OrganizationServiceAccountWorkspaces
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Workload-identity federation (issuers and rules).
  class OrganizationFederation
    def initialize(@client : Client, @beta : Bool = false)
    end

    def issuers : OrganizationFederationIssuers
      OrganizationFederationIssuers.new(@client, beta: @beta)
    end

    def rules : OrganizationFederationRules
      OrganizationFederationRules.new(@client, beta: @beta)
    end
  end

  class BetaOrganizationFederation < OrganizationFederation
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Federation issuers.
  class OrganizationFederationIssuers
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Create a federation issuer.
    #
    # `jwks` accepts a `discovery`, `explicit_url`, or `inline` shape.
    def create(
      issuer_url : String,
      name : String,
      check_jti : Bool? = nil,
      jwks : JSON::Any | Hash(String, JSON::Any)? = nil,
      max_jwt_lifetime_seconds : Int64? = nil,
    ) : FederationIssuer
      body = {} of String => JSON::Any
      body["issuer_url"] = JSON::Any.new(issuer_url)
      body["name"] = JSON::Any.new(name)
      OrganizationHelpers.set_json_opt(body, "check_jti", check_jti)
      OrganizationHelpers.set_json_any(body, "jwks", jwks)
      OrganizationHelpers.set_json_opt(body, "max_jwt_lifetime_seconds", max_jwt_lifetime_seconds)

      response = @client.post("/v1/organizations/federation_issuers", body, beta: @beta)
      FederationIssuer.from_json(response.body)
    end

    # Retrieve a federation issuer by ID.
    def retrieve(federation_issuer_id : String) : FederationIssuer
      response = @client.get("/v1/organizations/federation_issuers/#{Anthropic.encode_path_segment(federation_issuer_id)}", beta: @beta)
      FederationIssuer.from_json(response.body)
    end

    # Update a federation issuer.
    def update(
      federation_issuer_id : String,
      check_jti : Bool? = nil,
      issuer_url : String? = nil,
      jwks : JSON::Any | Hash(String, JSON::Any)? = nil,
      jwks_polling_disabled : Bool? = nil,
      max_jwt_lifetime_seconds : Int64? = nil,
      name : String? = nil,
    ) : FederationIssuer
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "check_jti", check_jti)
      OrganizationHelpers.set_json_opt(body, "issuer_url", issuer_url)
      OrganizationHelpers.set_json_any(body, "jwks", jwks)
      OrganizationHelpers.set_json_opt(body, "jwks_polling_disabled", jwks_polling_disabled)
      OrganizationHelpers.set_json_opt(body, "max_jwt_lifetime_seconds", max_jwt_lifetime_seconds)
      OrganizationHelpers.set_json_opt(body, "name", name)

      response = @client.post("/v1/organizations/federation_issuers/#{Anthropic.encode_path_segment(federation_issuer_id)}", body, beta: @beta)
      FederationIssuer.from_json(response.body)
    end

    # List federation issuers.
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
    ) : FederationIssuerListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_archived", include_archived)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/federation_issuers", query, beta: @beta)
      FederationIssuerListResponse.from_json(response.body)
    end

    # Archive a federation issuer (idempotent).
    def archive(federation_issuer_id : String) : FederationIssuer
      response = @client.post(
        "/v1/organizations/federation_issuers/#{Anthropic.encode_path_segment(federation_issuer_id)}/archive",
        {} of String => JSON::Any,
        beta: @beta
      )
      FederationIssuer.from_json(response.body)
    end
  end

  class BetaOrganizationFederationIssuers < OrganizationFederationIssuers
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Federation rules.
  class OrganizationFederationRules
    def initialize(@client : Client, @beta : Bool = false)
    end

    def workspaces : OrganizationFederationRuleWorkspaces
      OrganizationFederationRuleWorkspaces.new(@client, beta: @beta)
    end

    # Create a federation rule.
    def create(
      issuer_id : String,
      match : BetaFederationRuleMatch | Hash(String, JSON::Any),
      name : String,
      oauth_scope : String,
      target : JSON::Any | Hash(String, JSON::Any),
      applies_to_all_workspaces : Bool? = nil,
      attributes : Hash(String, String)? = nil,
      description : String? = nil,
      token_lifetime_seconds : Int64? = nil,
      workspace_id : String? = nil,
    ) : FederationRule
      body = {} of String => JSON::Any
      body["issuer_id"] = JSON::Any.new(issuer_id)
      body["match"] = JSON.parse(match.to_json)
      body["name"] = JSON::Any.new(name)
      body["oauth_scope"] = JSON::Any.new(oauth_scope)
      body["target"] = JSON.parse(target.to_json)
      apply_optional_rule_fields(body, applies_to_all_workspaces, attributes, description, token_lifetime_seconds, workspace_id)

      response = @client.post("/v1/organizations/federation_rules", body, beta: @beta)
      FederationRule.from_json(response.body)
    end

    # Retrieve a federation rule by ID.
    def retrieve(federation_rule_id : String) : FederationRule
      response = @client.get("/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}", beta: @beta)
      FederationRule.from_json(response.body)
    end

    # Update a federation rule.
    def update(
      federation_rule_id : String,
      applies_to_all_workspaces : Bool? = nil,
      attributes : Hash(String, String)? = nil,
      description : String? = nil,
      match : BetaFederationRuleMatch | Hash(String, JSON::Any)? = nil,
      name : String? = nil,
      oauth_scope : String? = nil,
      target : JSON::Any | Hash(String, JSON::Any)? = nil,
      token_lifetime_seconds : Int64? = nil,
      workspace_id : String? = nil,
    ) : FederationRule
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_any(body, "match", match)
      OrganizationHelpers.set_json_opt(body, "name", name)
      OrganizationHelpers.set_json_opt(body, "oauth_scope", oauth_scope)
      OrganizationHelpers.set_json_any(body, "target", target)
      apply_optional_rule_fields(body, applies_to_all_workspaces, attributes, description, token_lifetime_seconds, workspace_id)

      response = @client.post("/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}", body, beta: @beta)
      FederationRule.from_json(response.body)
    end

    # List federation rules.
    def list(
      include_archived : Bool? = nil,
      issuer_id : String? = nil,
      limit : Int32 = 20,
      page : String? = nil,
    ) : FederationRuleListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_archived", include_archived)
      OrganizationHelpers.set_query(query, "issuer_id", issuer_id)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/federation_rules", query, beta: @beta)
      FederationRuleListResponse.from_json(response.body)
    end

    # Archive a federation rule.
    def archive(federation_rule_id : String) : FederationRule
      response = @client.post(
        "/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}/archive",
        {} of String => JSON::Any,
        beta: @beta
      )
      FederationRule.from_json(response.body)
    end

    private def apply_optional_rule_fields(
      body : Hash(String, JSON::Any),
      applies_to_all_workspaces : Bool?,
      attributes : Hash(String, String)?,
      description : String?,
      token_lifetime_seconds : Int64?,
      workspace_id : String?,
    ) : Nil
      OrganizationHelpers.set_json_opt(body, "applies_to_all_workspaces", applies_to_all_workspaces)
      OrganizationHelpers.set_json_any(body, "attributes", attributes)
      OrganizationHelpers.set_json_opt(body, "description", description)
      OrganizationHelpers.set_json_opt(body, "token_lifetime_seconds", token_lifetime_seconds)
      OrganizationHelpers.set_json_opt(body, "workspace_id", workspace_id)
    end
  end

  class BetaOrganizationFederationRules < OrganizationFederationRules
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Workspaces a workload identity federation rule is enabled for.
  #
  # Access via `client.organization.federation.rules.workspaces` or
  # `client.beta.organization.federation.rules.workspaces`.
  class OrganizationFederationRuleWorkspaces
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List the workspaces a federation rule is enabled for.
    def list(
      federation_rule_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : FederationRuleWorkspaceListResponse
      query = {"limit" => limit.to_s} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}/workspaces",
        query,
        OrganizationHelpers.beta_headers(extra_betas: betas),
        beta: @beta
      )
      FederationRuleWorkspaceListResponse.from_json(response.body)
    end

    # Enable a federation rule for a workspace.
    #
    # Idempotent; re-enabling returns the existing enablement.
    def add(
      federation_rule_id : String,
      workspace_id : String,
      betas : Array(String) = [] of String,
    ) : FederationRuleWorkspace
      body = {"workspace_id" => JSON::Any.new(workspace_id)}
      response = @client.post(
        "/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}/workspaces",
        body,
        OrganizationHelpers.beta_headers(extra_betas: betas),
        beta: @beta
      )
      FederationRuleWorkspace.from_json(response.body)
    end

    # Disable a federation rule for a workspace.
    #
    # Idempotent; succeeds even if the enablement was already removed.
    def remove(
      federation_rule_id : String,
      workspace_id : String,
      betas : Array(String) = [] of String,
    ) : DeletedFederationRuleWorkspace
      response = @client.delete(
        "/v1/organizations/federation_rules/#{Anthropic.encode_path_segment(federation_rule_id)}/workspaces/#{Anthropic.encode_path_segment(workspace_id)}",
        OrganizationHelpers.beta_headers(extra_betas: betas),
        beta: @beta
      )
      DeletedFederationRuleWorkspace.from_json(response.body)
    end
  end

  class BetaOrganizationFederationRuleWorkspaces < OrganizationFederationRuleWorkspaces
    def initialize(client : Client)
      super(client, beta: true)
    end
  end
end
