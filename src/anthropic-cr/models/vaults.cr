require "json"

module Anthropic
  # Stateful Vault for storing credentials securely (beta)
  struct BetaVault
    include JSON::Serializable

    # Unique vault identifier
    getter id : String

    # Human-readable name for the vault
    @[JSON::Field(key: "display_name")]
    getter display_name : String

    # Type of resource (always "vault")
    getter type : String = "vault"

    # Arbitrary key-value metadata attached to the vault
    getter metadata : Hash(String, String)?

    # Timestamp when the vault was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Timestamp when the vault was last updated
    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Timestamp when the vault was archived, or nil if active
    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  # Response for deleting a vault
  struct BetaVaultDeleteResponse
    include JSON::Serializable

    # Unique vault identifier deleted
    getter id : String

    # Type of delete action (always "vault_deleted")
    getter type : String = "vault_deleted"
  end

  # Response for listing vaults
  struct BetaVaultListResponse
    include JSON::Serializable

    # Array of retrieved vaults
    getter data : Array(BetaVault)

    # Whether there are more pages available
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?
  end

  # Credential stored securely inside a Vault (beta)
  struct BetaCredential
    include JSON::Serializable

    # Unique credential identifier
    getter id : String

    # Unique vault identifier this credential belongs to
    @[JSON::Field(key: "vault_id")]
    getter vault_id : String

    # Human-readable name for the credential
    @[JSON::Field(key: "display_name")]
    getter display_name : String?

    # Type of resource (always "credential")
    getter type : String = "credential"

    # Authentication details (e.g. static token, oauth details)
    getter auth : JSON::Any

    # Arbitrary key-value metadata attached to the credential
    getter metadata : Hash(String, String)?

    # Timestamp when the credential was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Timestamp when the credential was last updated
    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Timestamp when the credential was archived, or nil if active
    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  # Response for deleting a credential
  struct BetaCredentialDeleteResponse
    include JSON::Serializable

    # Unique credential identifier deleted
    getter id : String

    # Type of delete action (always "credential_deleted")
    getter type : String = "credential_deleted"
  end

  # Response for listing credentials
  struct BetaCredentialListResponse
    include JSON::Serializable

    # Array of retrieved credentials
    getter data : Array(BetaCredential)

    # Whether there are more pages available
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool?
  end

  # Result of credential validation (e.g. OAuth validity)
  struct BetaCredentialValidation
    include JSON::Serializable

    # Validation status (e.g. "valid", "invalid")
    getter status : String

    # Validation error details, if any
    @[JSON::Field(key: "error_message")]
    getter error_message : String?
  end
end
