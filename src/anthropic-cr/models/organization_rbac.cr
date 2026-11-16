module Anthropic
  # Provisioning source of an RBAC group.
  module RbacGroupSourceType
    DIRECT = "direct"
    SCIM   = "scim"
  end

  # An organization RBAC group.
  struct RbacGroup
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter name : String

    @[JSON::Field(key: "role_ids", emit_null: false)]
    getter role_ids : Array(String)?

    @[JSON::Field(key: "source_type")]
    getter source_type : String

    # Object type. Always `"rbac_group"`.
    getter type : String = "rbac_group"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  alias RBACGroup = RbacGroup
  alias BetaRbacGroup = RbacGroup
  alias BetaRBACGroup = RbacGroup

  # Paginated list of RBAC groups.
  struct RbacGroupListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(RbacGroup)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias RBACGroupListResponse = RbacGroupListResponse
  alias BetaRbacGroupListResponse = RbacGroupListResponse
  alias BetaRBACGroupListResponse = RbacGroupListResponse

  # Confirmation returned when an RBAC group is deleted.
  struct DeletedRbacGroup
    include JSON::Serializable

    getter id : String

    # Object type. Always `"rbac_group_deleted"`.
    getter type : String = "rbac_group_deleted"
  end

  alias DeletedRBACGroup = DeletedRbacGroup
  alias BetaDeletedRbacGroup = DeletedRbacGroup
  alias BetaDeletedRBACGroup = DeletedRbacGroup

  # A user's membership in an RBAC group.
  struct RbacGroupMember
    include JSON::Serializable

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter email : String

    @[JSON::Field(key: "rbac_group_id")]
    getter rbac_group_id : String

    # Object type. Always `"rbac_group_member"`.
    getter type : String = "rbac_group_member"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  alias RBACGroupMember = RbacGroupMember
  alias BetaRbacGroupMember = RbacGroupMember
  alias BetaRBACGroupMember = RbacGroupMember

  # Paginated list of RBAC group members.
  struct RbacGroupMemberListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(RbacGroupMember)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias RBACGroupMemberListResponse = RbacGroupMemberListResponse
  alias BetaRbacGroupMemberListResponse = RbacGroupMemberListResponse
  alias BetaRBACGroupMemberListResponse = RbacGroupMemberListResponse

  # Confirmation returned when a user is removed from an RBAC group.
  struct DeletedRbacGroupMember
    include JSON::Serializable

    @[JSON::Field(key: "rbac_group_id")]
    getter rbac_group_id : String

    # Object type. Always `"rbac_group_member_deleted"`.
    getter type : String = "rbac_group_member_deleted"

    @[JSON::Field(key: "user_id")]
    getter user_id : String
  end

  alias DeletedRBACGroupMember = DeletedRbacGroupMember
  alias BetaDeletedRbacGroupMember = DeletedRbacGroupMember
  alias BetaDeletedRBACGroupMember = DeletedRbacGroupMember

  # An organization RBAC role.
  struct RbacRole
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Object type. Always `"rbac_role"`.
    getter type : String = "rbac_role"

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  alias RBACRole = RbacRole
  alias BetaRbacRole = RbacRole
  alias BetaRBACRole = RbacRole

  # Paginated list of RBAC roles.
  struct RbacRoleListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(RbacRole)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias RBACRoleListResponse = RbacRoleListResponse
  alias BetaRbacRoleListResponse = RbacRoleListResponse
  alias BetaRBACRoleListResponse = RbacRoleListResponse

  # Permission resource scoped to an organization.
  struct RbacOrganizationPermissionResource
    include JSON::Serializable

    @[JSON::Field(key: "organization_id")]
    getter organization_id : String

    getter type : String = "organization"
  end

  alias RBACOrganizationPermissionResource = RbacOrganizationPermissionResource

  # Permission resource scoped to a specific connector.
  struct RbacConnectorPermissionResource
    include JSON::Serializable

    @[JSON::Field(key: "connector_id")]
    getter connector_id : String

    getter type : String = "connector"
  end

  alias RBACConnectorPermissionResource = RbacConnectorPermissionResource

  # Permission resource scoped to a connector OAuth scope.
  struct RbacConnectorScopePermissionResource
    include JSON::Serializable

    @[JSON::Field(key: "connector_id")]
    getter connector_id : String

    getter scope : String
    getter type : String = "connector_scope"
  end

  alias RBACConnectorScopePermissionResource = RbacConnectorScopePermissionResource

  # Permission resource scoped to a specific connector tool.
  struct RbacConnectorToolPermissionResource
    include JSON::Serializable

    @[JSON::Field(key: "connector_id")]
    getter connector_id : String

    @[JSON::Field(key: "tool_name")]
    getter tool_name : String

    getter type : String = "connector_tool"
  end

  alias RBACConnectorToolPermissionResource = RbacConnectorToolPermissionResource

  # Permission resource covering all connectors.
  struct RbacAllConnectorsPermissionResource
    include JSON::Serializable

    getter type : String = "all_connectors"
  end

  alias RBACAllConnectorsPermissionResource = RbacAllConnectorsPermissionResource

  # Forward-compatible fallback for unrecognized permission resource types.
  struct RbacGenericPermissionResource
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias RBACGenericPermissionResource = RbacGenericPermissionResource

  alias RbacPermissionResource = RbacOrganizationPermissionResource |
                                 RbacConnectorPermissionResource |
                                 RbacConnectorScopePermissionResource |
                                 RbacConnectorToolPermissionResource |
                                 RbacAllConnectorsPermissionResource |
                                 RbacGenericPermissionResource

  module RbacPermissionResourceConverter
    def self.from_json(pull : JSON::PullParser) : RbacPermissionResource
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "organization"
        RbacOrganizationPermissionResource.from_json(raw)
      when "connector"
        RbacConnectorPermissionResource.from_json(raw)
      when "connector_scope"
        RbacConnectorScopePermissionResource.from_json(raw)
      when "connector_tool"
        RbacConnectorToolPermissionResource.from_json(raw)
      when "all_connectors"
        RbacAllConnectorsPermissionResource.from_json(raw)
      else
        RbacGenericPermissionResource.new(type: type, raw: json)
      end
    end

    def self.to_json(value : RbacPermissionResource, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # A permission granted by an RBAC role.
  struct RbacRolePermission
    include JSON::Serializable

    getter action : String

    @[JSON::Field(converter: Anthropic::RbacPermissionResourceConverter)]
    getter resource : RbacPermissionResource

    # Object type. Always `"rbac_role_permission"`.
    getter type : String = "rbac_role_permission"
  end

  alias RBACRolePermission = RbacRolePermission
  alias BetaRbacRolePermission = RbacRolePermission
  alias BetaRBACRolePermission = RbacRolePermission

  # Paginated list of RBAC role permissions.
  struct RbacRolePermissionListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(RbacRolePermission)

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  alias RBACRolePermissionListResponse = RbacRolePermissionListResponse
  alias BetaRbacRolePermissionListResponse = RbacRolePermissionListResponse
  alias BetaRBACRolePermissionListResponse = RbacRolePermissionListResponse
end
