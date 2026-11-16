module Anthropic
  # Organization RBAC groups (GA and beta).
  class OrganizationRbacGroups
    def initialize(@client : Client, @beta : Bool = false)
    end

    def members : OrganizationRbacGroupMembers
      OrganizationRbacGroupMembers.new(@client, beta: @beta)
    end

    # Create an RBAC group.
    def create(name : String) : RbacGroup
      body = {"name" => JSON::Any.new(name)}
      response = @client.post("/v1/organizations/rbac_groups", body, beta: @beta)
      RbacGroup.from_json(response.body)
    end

    # Retrieve an RBAC group by ID.
    def retrieve(rbac_group_id : String) : RbacGroup
      response = @client.get("/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}", beta: @beta)
      RbacGroup.from_json(response.body)
    end

    # Update an RBAC group's name.
    def update(rbac_group_id : String, name : String? = nil) : RbacGroup
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "name", name)

      response = @client.post("/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}", body, beta: @beta)
      RbacGroup.from_json(response.body)
    end

    # List RBAC groups with optional cursor pagination.
    def list(limit : Int32? = nil, page : String? = nil) : RbacGroupListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/rbac_groups", query, beta: @beta)
      RbacGroupListResponse.from_json(response.body)
    end

    # Delete an RBAC group.
    def delete(rbac_group_id : String) : DeletedRbacGroup
      response = @client.delete("/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}", beta: @beta)
      DeletedRbacGroup.from_json(response.body)
    end
  end

  alias OrganizationRBACGroups = OrganizationRbacGroups

  class BetaOrganizationRbacGroups < OrganizationRbacGroups
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  alias BetaOrganizationRBACGroups = BetaOrganizationRbacGroups

  # Members of an organization RBAC group (GA and beta).
  class OrganizationRbacGroupMembers
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List members of an RBAC group.
    def list(
      rbac_group_id : String,
      limit : Int32? = nil,
      page : String? = nil,
    ) : RbacGroupMemberListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}/members",
        query,
        beta: @beta
      )
      RbacGroupMemberListResponse.from_json(response.body)
    end

    # Add a user to an RBAC group.
    def add(rbac_group_id : String, user_id : String) : RbacGroupMember
      body = {"user_id" => JSON::Any.new(user_id)}
      response = @client.post(
        "/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}/members",
        body,
        beta: @beta
      )
      RbacGroupMember.from_json(response.body)
    end

    # Remove a user from an RBAC group.
    def remove(rbac_group_id : String, user_id : String) : DeletedRbacGroupMember
      response = @client.delete(
        "/v1/organizations/rbac_groups/#{Anthropic.encode_path_segment(rbac_group_id)}/members/#{Anthropic.encode_path_segment(user_id)}",
        beta: @beta
      )
      DeletedRbacGroupMember.from_json(response.body)
    end
  end

  alias OrganizationRBACGroupMembers = OrganizationRbacGroupMembers

  class BetaOrganizationRbacGroupMembers < OrganizationRbacGroupMembers
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  alias BetaOrganizationRBACGroupMembers = BetaOrganizationRbacGroupMembers

  # Organization RBAC roles (GA and beta).
  class OrganizationRbacRoles
    def initialize(@client : Client, @beta : Bool = false)
    end

    def permissions : OrganizationRbacRolePermissions
      OrganizationRbacRolePermissions.new(@client, beta: @beta)
    end

    # Retrieve an RBAC role by ID.
    def retrieve(rbac_role_id : String) : RbacRole
      response = @client.get("/v1/organizations/rbac_roles/#{Anthropic.encode_path_segment(rbac_role_id)}", beta: @beta)
      RbacRole.from_json(response.body)
    end

    # List RBAC roles with optional cursor pagination.
    def list(limit : Int32? = nil, page : String? = nil) : RbacRoleListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get("/v1/organizations/rbac_roles", query, beta: @beta)
      RbacRoleListResponse.from_json(response.body)
    end
  end

  alias OrganizationRBACRoles = OrganizationRbacRoles

  class BetaOrganizationRbacRoles < OrganizationRbacRoles
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  alias BetaOrganizationRBACRoles = BetaOrganizationRbacRoles

  # Permissions attached to an RBAC role (GA and beta).
  class OrganizationRbacRolePermissions
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List permissions granted by an RBAC role.
    def list(
      rbac_role_id : String,
      limit : Int32? = nil,
      page : String? = nil,
    ) : RbacRolePermissionListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      response = @client.get(
        "/v1/organizations/rbac_roles/#{Anthropic.encode_path_segment(rbac_role_id)}/permissions",
        query,
        beta: @beta
      )
      RbacRolePermissionListResponse.from_json(response.body)
    end
  end

  alias OrganizationRBACRolePermissions = OrganizationRbacRolePermissions

  class BetaOrganizationRbacRolePermissions < OrganizationRbacRolePermissions
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  alias BetaOrganizationRBACRolePermissions = BetaOrganizationRbacRolePermissions
end
