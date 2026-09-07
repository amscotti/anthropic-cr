module Anthropic
  # Organization Admin API (beta).
  #
  # Access via `client.beta.organization`. Retrieve organization details
  # with `#retrieve`, then manage API keys, external keys, invites, users,
  # workspaces, service accounts, federation, rate limits, and compliance
  # settings through the sub-resources below.
  #
  # ```
  # org = client.beta.organization.retrieve
  # puts org.name
  #
  # keys = client.beta.organization.api_keys.list(limit: 10)
  # ```
  class BetaOrganizations
    def initialize(@client : Client)
    end

    # Retrieve information about the organization associated with the
    # authenticated API key.
    def retrieve : BetaOrganization
      response = @client.get("/v1/organizations/me?beta=true")
      BetaOrganization.from_json(response.body)
    end

    def api_keys : BetaOrganizationAPIKeys
      BetaOrganizationAPIKeys.new(@client)
    end

    def external_keys : BetaOrganizationExternalKeys
      BetaOrganizationExternalKeys.new(@client)
    end

    def invites : BetaOrganizationInvites
      BetaOrganizationInvites.new(@client)
    end

    def users : BetaOrganizationUsers
      BetaOrganizationUsers.new(@client)
    end

    def workspaces : BetaOrganizationWorkspaces
      BetaOrganizationWorkspaces.new(@client)
    end

    def service_accounts : BetaOrganizationServiceAccounts
      BetaOrganizationServiceAccounts.new(@client)
    end

    def federation : BetaOrganizationFederation
      BetaOrganizationFederation.new(@client)
    end

    def rate_limits : BetaOrganizationRateLimits
      BetaOrganizationRateLimits.new(@client)
    end

    def compliance_settings : BetaOrganizationComplianceSettings
      BetaOrganizationComplianceSettings.new(@client)
    end
  end

  # Organization API keys.
  class BetaOrganizationAPIKeys
    def initialize(@client : Client)
    end

    # Retrieve an API key by ID.
    def retrieve(api_key_id : String) : BetaAPIKey
      response = @client.get("/v1/organizations/api_keys/#{api_key_id}?beta=true")
      BetaAPIKey.from_json(response.body)
    end

    # Update an API key's name or status (`"active"`, `"archived"`, or `"inactive"`).
    def update(
      api_key_id : String,
      name : String? = nil,
      status : String? = nil,
    ) : BetaAPIKey
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name) if name
      body["status"] = JSON::Any.new(status) if status

      response = @client.post("/v1/organizations/api_keys/#{api_key_id}?beta=true", body)
      BetaAPIKey.from_json(response.body)
    end

    # List API keys with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaAPIKeyListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/api_keys?beta=true", query)
      BetaAPIKeyListResponse.from_json(response.body)
    end
  end

  # Organization external (BYO-cloud) keys.
  #
  # `provider_config` accepts the raw provider configuration object
  # (AWS/GCP shapes); it is sent through untouched.
  class BetaOrganizationExternalKeys
    def initialize(@client : Client)
    end

    # Create an external key.
    def create(
      provider_config : JSON::Any | Hash(String, JSON::Any),
      display_name : String? = nil,
      geo : String? = nil,
    ) : BetaExternalKey
      body = {} of String => JSON::Any
      body["provider_config"] = JSON.parse(provider_config.to_json)
      body["display_name"] = JSON::Any.new(display_name) if display_name
      body["geo"] = JSON::Any.new(geo) if geo

      response = @client.post("/v1/organizations/external_keys?beta=true", body)
      BetaExternalKey.from_json(response.body)
    end

    # Retrieve an external key by ID.
    def retrieve(external_key_id : String) : BetaExternalKey
      response = @client.get("/v1/organizations/external_keys/#{external_key_id}?beta=true")
      BetaExternalKey.from_json(response.body)
    end

    # Update an external key.
    def update(
      external_key_id : String,
      display_name : String? = nil,
      geo : String? = nil,
      provider_config : JSON::Any | Hash(String, JSON::Any)? = nil,
    ) : BetaExternalKey
      body = {} of String => JSON::Any
      body["display_name"] = JSON::Any.new(display_name) if display_name
      body["geo"] = JSON::Any.new(geo) if geo
      body["provider_config"] = JSON.parse(provider_config.to_json) if provider_config

      response = @client.post("/v1/organizations/external_keys/#{external_key_id}?beta=true", body)
      BetaExternalKey.from_json(response.body)
    end

    # List external keys with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaExternalKeyListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/external_keys?beta=true", query)
      BetaExternalKeyListResponse.from_json(response.body)
    end

    # Delete an external key.
    def delete(external_key_id : String) : BetaDeletedExternalKey
      response = @client.delete("/v1/organizations/external_keys/#{external_key_id}?beta=true")
      BetaDeletedExternalKey.from_json(response.body)
    end

    # Validate an external key's credentials.
    def validate(external_key_id : String) : BetaExternalKeyValidation
      response = @client.post(
        "/v1/organizations/external_keys/#{external_key_id}/validate?beta=true",
        {} of String => JSON::Any
      )
      BetaExternalKeyValidation.from_json(response.body)
    end
  end

  # Organization invites.
  class BetaOrganizationInvites
    def initialize(@client : Client)
    end

    # Invite a user by email with an organization role.
    def create(
      email : String,
      role : String,
      rbac_group_ids : Array(String)? = nil,
    ) : BetaOrganizationInvite
      body = {} of String => JSON::Any
      body["email"] = JSON::Any.new(email)
      body["role"] = JSON::Any.new(role)
      body["rbac_group_ids"] = JSON.parse(rbac_group_ids.to_json) if rbac_group_ids

      response = @client.post("/v1/organizations/invites?beta=true", body)
      BetaOrganizationInvite.from_json(response.body)
    end

    # Retrieve an invite by ID.
    def retrieve(invite_id : String) : BetaOrganizationInvite
      response = @client.get("/v1/organizations/invites/#{invite_id}?beta=true")
      BetaOrganizationInvite.from_json(response.body)
    end

    # List invites with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaOrganizationInviteListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/invites?beta=true", query)
      BetaOrganizationInviteListResponse.from_json(response.body)
    end

    # Delete (revoke) an invite.
    def delete(invite_id : String) : BetaDeletedInvite
      response = @client.delete("/v1/organizations/invites/#{invite_id}?beta=true")
      BetaDeletedInvite.from_json(response.body)
    end
  end

  # Organization users.
  class BetaOrganizationUsers
    def initialize(@client : Client)
    end

    # Retrieve a user by ID.
    def retrieve(user_id : String) : BetaOrganizationUser
      response = @client.get("/v1/organizations/users/#{user_id}?beta=true")
      BetaOrganizationUser.from_json(response.body)
    end

    # Update a user's organization role.
    def update(user_id : String, role : String) : BetaOrganizationUser
      body = {"role" => JSON::Any.new(role)}

      response = @client.post("/v1/organizations/users/#{user_id}?beta=true", body)
      BetaOrganizationUser.from_json(response.body)
    end

    # List users with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaOrganizationUserListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/users?beta=true", query)
      BetaOrganizationUserListResponse.from_json(response.body)
    end

    # Remove a user from the organization.
    def remove(user_id : String) : BetaDeletedOrganizationUser
      response = @client.delete("/v1/organizations/users/#{user_id}?beta=true")
      BetaDeletedOrganizationUser.from_json(response.body)
    end
  end

  # Organization rate limits (read-only, with pagination on list).
  class BetaOrganizationRateLimits
    def initialize(@client : Client)
    end

    # List rate limits, optionally filtered by group type or model.
    def list(
      group_type : String? = nil,
      limit : Int32 = 20,
      model : String? = nil,
      page : String? = nil,
    ) : BetaOrganizationRateLimitListResponse
      query = {"limit" => limit.to_s}
      query["group_type"] = group_type if group_type
      query["model"] = model if model
      query["page"] = page if page

      response = @client.get("/v1/organizations/rate_limits?beta=true", query)
      BetaOrganizationRateLimitListResponse.from_json(response.body)
    end
  end

  # Organization compliance settings.
  class BetaOrganizationComplianceSettings
    def initialize(@client : Client)
    end

    # Retrieve the current compliance settings.
    def retrieve : BetaComplianceSettings
      response = @client.get("/v1/organizations/compliance_settings?beta=true")
      BetaComplianceSettings.from_json(response.body)
    end

    # Update compliance settings.
    #
    # `state` is `{type: "enabled", ...}` or `{type: "disabled"}`.
    def update(state : JSON::Any | Hash(String, JSON::Any)) : BetaComplianceSettings
      body = {"state" => JSON.parse(state.to_json)}

      response = @client.post("/v1/organizations/compliance_settings?beta=true", body)
      BetaComplianceSettings.from_json(response.body)
    end
  end

  # Organization workspaces.
  class BetaOrganizationWorkspaces
    def initialize(@client : Client)
    end

    def members : BetaOrganizationWorkspaceMembers
      BetaOrganizationWorkspaceMembers.new(@client)
    end

    def rate_limits : BetaOrganizationWorkspaceRateLimits
      BetaOrganizationWorkspaceRateLimits.new(@client)
    end

    def service_accounts : BetaOrganizationWorkspaceServiceAccounts
      BetaOrganizationWorkspaceServiceAccounts.new(@client)
    end

    # Create a workspace.
    def create(
      name : String,
      data_residency : BetaDataResidency | Hash(String, JSON::Any)? = nil,
      display_color : String? = nil,
      external_key_id : String? = nil,
      tags : Hash(String, String)? = nil,
    ) : BetaWorkspace
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name)
      body["data_residency"] = JSON.parse(data_residency.to_json) if data_residency
      body["display_color"] = JSON::Any.new(display_color) if display_color
      body["external_key_id"] = JSON::Any.new(external_key_id) if external_key_id
      body["tags"] = JSON.parse(tags.to_json) if tags

      response = @client.post("/v1/organizations/workspaces?beta=true", body)
      BetaWorkspace.from_json(response.body)
    end

    # Retrieve a workspace by ID.
    def retrieve(workspace_id : String) : BetaWorkspace
      response = @client.get("/v1/organizations/workspaces/#{workspace_id}?beta=true")
      BetaWorkspace.from_json(response.body)
    end

    # Update a workspace. Pass `tags: nil` explicitly to leave tags
    # unchanged; other omitted fields are left unchanged.
    def update(
      workspace_id : String,
      name : String? = nil,
      data_residency : BetaDataResidency | Hash(String, JSON::Any)? = nil,
      display_color : String? = nil,
      external_key_id : String? = nil,
      tags : Hash(String, String)? = nil,
    ) : BetaWorkspace
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name) if name
      body["data_residency"] = JSON.parse(data_residency.to_json) if data_residency
      body["display_color"] = JSON::Any.new(display_color) if display_color
      body["external_key_id"] = JSON::Any.new(external_key_id) if external_key_id
      body["tags"] = JSON.parse(tags.to_json) if tags

      response = @client.post("/v1/organizations/workspaces/#{workspace_id}?beta=true", body)
      BetaWorkspace.from_json(response.body)
    end

    # List workspaces with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaWorkspaceListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/workspaces?beta=true", query)
      BetaWorkspaceListResponse.from_json(response.body)
    end

    # Archive a workspace.
    def archive(workspace_id : String) : BetaWorkspace
      response = @client.post(
        "/v1/organizations/workspaces/#{workspace_id}/archive?beta=true",
        {} of String => JSON::Any
      )
      BetaWorkspace.from_json(response.body)
    end
  end

  # Workspace members (user memberships).
  class BetaOrganizationWorkspaceMembers
    def initialize(@client : Client)
    end

    # Retrieve a member by workspace and user ID.
    def retrieve(workspace_id : String, user_id : String) : BetaWorkspaceMember
      response = @client.get(
        "/v1/organizations/workspaces/#{workspace_id}/members/#{user_id}?beta=true"
      )
      BetaWorkspaceMember.from_json(response.body)
    end

    # Update a member's workspace role.
    def update(workspace_id : String, user_id : String, workspace_role : String) : BetaWorkspaceMember
      body = {"workspace_role" => JSON::Any.new(workspace_role)}

      response = @client.post(
        "/v1/organizations/workspaces/#{workspace_id}/members/#{user_id}?beta=true",
        body
      )
      BetaWorkspaceMember.from_json(response.body)
    end

    # List members of a workspace.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaWorkspaceMemberListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get(
        "/v1/organizations/workspaces/#{workspace_id}/members?beta=true",
        query
      )
      BetaWorkspaceMemberListResponse.from_json(response.body)
    end

    # Add a user to a workspace.
    def add(workspace_id : String, user_id : String, workspace_role : String) : BetaWorkspaceMember
      body = {
        "user_id"        => JSON::Any.new(user_id),
        "workspace_role" => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/workspaces/#{workspace_id}/members?beta=true",
        body
      )
      BetaWorkspaceMember.from_json(response.body)
    end

    # Remove a user from a workspace.
    def remove(workspace_id : String, user_id : String) : BetaDeletedWorkspaceMember
      response = @client.delete(
        "/v1/organizations/workspaces/#{workspace_id}/members/#{user_id}?beta=true"
      )
      BetaDeletedWorkspaceMember.from_json(response.body)
    end
  end

  # Workspace rate limits (read-only).
  class BetaOrganizationWorkspaceRateLimits
    def initialize(@client : Client)
    end

    # List rate limits for a workspace.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaOrganizationRateLimitListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get(
        "/v1/organizations/workspaces/#{workspace_id}/rate_limits?beta=true",
        query
      )
      BetaOrganizationRateLimitListResponse.from_json(response.body)
    end
  end

  # Service accounts attached to a workspace.
  class BetaOrganizationWorkspaceServiceAccounts
    def initialize(@client : Client)
    end

    # Retrieve a workspace service account by workspace and account ID.
    def retrieve(workspace_id : String, service_account_id : String) : BetaServiceAccountWorkspaceMember
      response = @client.get(
        "/v1/organizations/workspaces/#{workspace_id}/service_accounts/#{service_account_id}?beta=true"
      )
      BetaServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Update a workspace service account's role.
    def update(
      workspace_id : String,
      service_account_id : String,
      workspace_role : String,
    ) : BetaServiceAccountWorkspaceMember
      body = {"workspace_role" => JSON::Any.new(workspace_role)}

      response = @client.post(
        "/v1/organizations/workspaces/#{workspace_id}/service_accounts/#{service_account_id}?beta=true",
        body
      )
      BetaServiceAccountWorkspaceMember.from_json(response.body)
    end

    # List service accounts attached to a workspace.
    def list(
      workspace_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaServiceAccountWorkspaceMemberListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get(
        "/v1/organizations/workspaces/#{workspace_id}/service_accounts?beta=true",
        query
      )
      BetaServiceAccountWorkspaceMemberListResponse.from_json(response.body)
    end

    # Attach a service account to a workspace.
    def add(
      workspace_id : String,
      service_account_id : String,
      workspace_role : String,
    ) : BetaServiceAccountWorkspaceMember
      body = {
        "service_account_id" => JSON::Any.new(service_account_id),
        "workspace_role"     => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/workspaces/#{workspace_id}/service_accounts?beta=true",
        body
      )
      BetaServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Remove a service account from a workspace.
    def remove(workspace_id : String, service_account_id : String) : BetaDeletedServiceAccountWorkspaceMember
      response = @client.delete(
        "/v1/organizations/workspaces/#{workspace_id}/service_accounts/#{service_account_id}?beta=true"
      )
      BetaDeletedServiceAccountWorkspaceMember.from_json(response.body)
    end
  end

  # Organization service accounts.
  class BetaOrganizationServiceAccounts
    def initialize(@client : Client)
    end

    def workspaces : BetaOrganizationServiceAccountWorkspaces
      BetaOrganizationServiceAccountWorkspaces.new(@client)
    end

    # Create a service account.
    def create(
      name : String,
      description : String? = nil,
      organization_role : String | JSON::Any? = nil,
    ) : BetaServiceAccount
      body = {} of String => JSON::Any
      body["name"] = JSON::Any.new(name)
      body["description"] = JSON::Any.new(description) if description
      case role = organization_role
      when JSON::Any then body["organization_role"] = role
      when String    then body["organization_role"] = JSON::Any.new(role)
      end

      response = @client.post("/v1/organizations/service_accounts?beta=true", body)
      BetaServiceAccount.from_json(response.body)
    end

    # Retrieve a service account by ID.
    def retrieve(service_account_id : String) : BetaServiceAccount
      response = @client.get("/v1/organizations/service_accounts/#{service_account_id}?beta=true")
      BetaServiceAccount.from_json(response.body)
    end

    # Update a service account's description or organization role.
    def update(
      service_account_id : String,
      description : String? = nil,
      organization_role : String | JSON::Any? = nil,
    ) : BetaServiceAccount
      body = {} of String => JSON::Any
      body["description"] = JSON::Any.new(description) if description
      case role = organization_role
      when JSON::Any then body["organization_role"] = role
      when String    then body["organization_role"] = JSON::Any.new(role)
      end

      response = @client.post("/v1/organizations/service_accounts/#{service_account_id}?beta=true", body)
      BetaServiceAccount.from_json(response.body)
    end

    # List service accounts with optional pagination.
    def list(
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaServiceAccountListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get("/v1/organizations/service_accounts?beta=true", query)
      BetaServiceAccountListResponse.from_json(response.body)
    end

    # Archive a service account.
    def archive(service_account_id : String) : BetaServiceAccount
      response = @client.post(
        "/v1/organizations/service_accounts/#{service_account_id}/archive?beta=true",
        {} of String => JSON::Any
      )
      BetaServiceAccount.from_json(response.body)
    end
  end

  # Workspaces attached to a service account.
  class BetaOrganizationServiceAccountWorkspaces
    def initialize(@client : Client)
    end

    # List workspaces a service account belongs to.
    def list(
      service_account_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaServiceAccountWorkspaceMemberListResponse
      query = {"limit" => limit.to_s}
      query["page"] = page if page

      response = @client.get(
        "/v1/organizations/service_accounts/#{service_account_id}/workspaces?beta=true",
        query
      )
      BetaServiceAccountWorkspaceMemberListResponse.from_json(response.body)
    end

    # Attach a service account to a workspace.
    def add(
      service_account_id : String,
      workspace_id : String,
      workspace_role : String,
    ) : BetaServiceAccountWorkspaceMember
      body = {
        "workspace_id"   => JSON::Any.new(workspace_id),
        "workspace_role" => JSON::Any.new(workspace_role),
      }

      response = @client.post(
        "/v1/organizations/service_accounts/#{service_account_id}/workspaces?beta=true",
        body
      )
      BetaServiceAccountWorkspaceMember.from_json(response.body)
    end

    # Remove a service account from a workspace.
    def remove(service_account_id : String, workspace_id : String) : BetaDeletedServiceAccountWorkspaceMember
      response = @client.delete(
        "/v1/organizations/service_accounts/#{service_account_id}/workspaces/#{workspace_id}?beta=true"
      )
      BetaDeletedServiceAccountWorkspaceMember.from_json(response.body)
    end
  end

  # Workload-identity federation (issuers and rules).
  class BetaOrganizationFederation
    def initialize(@client : Client)
    end

    def issuers : BetaOrganizationFederationIssuers
      BetaOrganizationFederationIssuers.new(@client)
    end

    def rules : BetaOrganizationFederationRules
      BetaOrganizationFederationRules.new(@client)
    end
  end

  # Federation issuers.
  class BetaOrganizationFederationIssuers
    def initialize(@client : Client)
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
    ) : BetaFederationIssuer
      body = {} of String => JSON::Any
      body["issuer_url"] = JSON::Any.new(issuer_url)
      body["name"] = JSON::Any.new(name)
      body["check_jti"] = JSON::Any.new(check_jti) unless check_jti.nil?
      body["jwks"] = JSON.parse(jwks.to_json) if jwks
      max_jwt_lifetime_seconds.try { |secs| body["max_jwt_lifetime_seconds"] = JSON::Any.new(secs) }

      response = @client.post("/v1/organizations/federation_issuers?beta=true", body)
      BetaFederationIssuer.from_json(response.body)
    end

    # Retrieve a federation issuer by ID.
    def retrieve(federation_issuer_id : String) : BetaFederationIssuer
      response = @client.get("/v1/organizations/federation_issuers/#{federation_issuer_id}?beta=true")
      BetaFederationIssuer.from_json(response.body)
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
    ) : BetaFederationIssuer
      body = {} of String => JSON::Any
      body["check_jti"] = JSON::Any.new(check_jti) unless check_jti.nil?
      body["issuer_url"] = JSON::Any.new(issuer_url) if issuer_url
      body["jwks"] = JSON.parse(jwks.to_json) if jwks
      body["jwks_polling_disabled"] = JSON::Any.new(jwks_polling_disabled) unless jwks_polling_disabled.nil?
      max_jwt_lifetime_seconds.try { |secs| body["max_jwt_lifetime_seconds"] = JSON::Any.new(secs) }
      body["name"] = JSON::Any.new(name) if name

      response = @client.post("/v1/organizations/federation_issuers/#{federation_issuer_id}?beta=true", body)
      BetaFederationIssuer.from_json(response.body)
    end

    # List federation issuers.
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaFederationIssuerListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s unless include_archived.nil?
      query["page"] = page if page

      response = @client.get("/v1/organizations/federation_issuers?beta=true", query)
      BetaFederationIssuerListResponse.from_json(response.body)
    end

    # Archive a federation issuer (idempotent).
    def archive(federation_issuer_id : String) : BetaFederationIssuer
      response = @client.post(
        "/v1/organizations/federation_issuers/#{federation_issuer_id}/archive?beta=true",
        {} of String => JSON::Any
      )
      BetaFederationIssuer.from_json(response.body)
    end
  end

  # Federation rules.
  class BetaOrganizationFederationRules
    def initialize(@client : Client)
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
    ) : BetaFederationRule
      body = {} of String => JSON::Any
      body["issuer_id"] = JSON::Any.new(issuer_id)
      body["match"] = JSON.parse(match.to_json)
      body["name"] = JSON::Any.new(name)
      body["oauth_scope"] = JSON::Any.new(oauth_scope)
      body["target"] = JSON.parse(target.to_json)
      body["applies_to_all_workspaces"] = JSON::Any.new(applies_to_all_workspaces) unless applies_to_all_workspaces.nil?
      body["attributes"] = JSON.parse(attributes.to_json) if attributes
      body["description"] = JSON::Any.new(description) if description
      token_lifetime_seconds.try { |secs| body["token_lifetime_seconds"] = JSON::Any.new(secs) }
      body["workspace_id"] = JSON::Any.new(workspace_id) if workspace_id

      response = @client.post("/v1/organizations/federation_rules?beta=true", body)
      BetaFederationRule.from_json(response.body)
    end

    # Retrieve a federation rule by ID.
    def retrieve(federation_rule_id : String) : BetaFederationRule
      response = @client.get("/v1/organizations/federation_rules/#{federation_rule_id}?beta=true")
      BetaFederationRule.from_json(response.body)
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
    ) : BetaFederationRule
      body = {} of String => JSON::Any
      body["applies_to_all_workspaces"] = JSON::Any.new(applies_to_all_workspaces) unless applies_to_all_workspaces.nil?
      body["attributes"] = JSON.parse(attributes.to_json) if attributes
      body["description"] = JSON::Any.new(description) if description
      body["match"] = JSON.parse(match.to_json) if match
      body["name"] = JSON::Any.new(name) if name
      body["oauth_scope"] = JSON::Any.new(oauth_scope) if oauth_scope
      body["target"] = JSON.parse(target.to_json) if target
      token_lifetime_seconds.try { |secs| body["token_lifetime_seconds"] = JSON::Any.new(secs) }
      body["workspace_id"] = JSON::Any.new(workspace_id) if workspace_id

      response = @client.post("/v1/organizations/federation_rules/#{federation_rule_id}?beta=true", body)
      BetaFederationRule.from_json(response.body)
    end

    # List federation rules.
    def list(
      include_archived : Bool? = nil,
      issuer_id : String? = nil,
      limit : Int32 = 20,
      page : String? = nil,
    ) : BetaFederationRuleListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s unless include_archived.nil?
      query["issuer_id"] = issuer_id if issuer_id
      query["page"] = page if page

      response = @client.get("/v1/organizations/federation_rules?beta=true", query)
      BetaFederationRuleListResponse.from_json(response.body)
    end

    # Archive a federation rule.
    def archive(federation_rule_id : String) : BetaFederationRule
      response = @client.post(
        "/v1/organizations/federation_rules/#{federation_rule_id}/archive?beta=true",
        {} of String => JSON::Any
      )
      BetaFederationRule.from_json(response.body)
    end
  end
end
