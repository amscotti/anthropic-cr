module Anthropic
  struct BetaManagedAgentsMemoryStore
    include JSON::Serializable

    getter id : String
    getter name : String
    getter type : String = "memory_store"
    getter description : String?
    getter metadata : Hash(String, String)?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "archived_at")]
    getter archived_at : String?
  end

  struct BetaManagedAgentsDeletedMemoryStore
    include JSON::Serializable
    getter id : String
    getter type : String = "memory_store_deleted"
  end

  struct BetaMemoryStoreListResponse
    include JSON::Serializable
    getter data : Array(BetaManagedAgentsMemoryStore)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  struct BetaManagedAgentsMemory
    include JSON::Serializable

    getter id : String
    getter type : String = "memory"
    getter path : String
    getter content : String?

    @[JSON::Field(key: "content_sha256")]
    getter content_sha256 : String

    @[JSON::Field(key: "content_size_bytes")]
    getter content_size_bytes : Int32

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    @[JSON::Field(key: "memory_version_id")]
    getter memory_version_id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String
  end

  struct BetaManagedAgentsDeletedMemory
    include JSON::Serializable
    getter id : String
    getter type : String = "memory_deleted"
  end

  struct BetaMemoryListResponse
    include JSON::Serializable
    getter data : Array(BetaManagedAgentsMemory)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  struct BetaManagedAgentsActor
    include JSON::Serializable
    getter type : String # "user" | "session" | "api"
    getter id : String?
  end

  struct BetaManagedAgentsMemoryVersion
    include JSON::Serializable

    getter id : String
    getter type : String = "memory_version"
    getter operation : String # "create" | "update" | "redact"
    getter content : String?
    getter path : String?

    @[JSON::Field(key: "memory_id")]
    getter memory_id : String

    @[JSON::Field(key: "memory_store_id")]
    getter memory_store_id : String

    @[JSON::Field(key: "content_sha256")]
    getter content_sha256 : String?

    @[JSON::Field(key: "content_size_bytes")]
    getter content_size_bytes : Int32?

    @[JSON::Field(key: "created_by")]
    getter created_by : BetaManagedAgentsActor?

    @[JSON::Field(key: "redacted_by")]
    getter redacted_by : BetaManagedAgentsActor?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "redacted_at")]
    getter redacted_at : String?
  end

  struct BetaMemoryVersionListResponse
    include JSON::Serializable
    getter data : Array(BetaManagedAgentsMemoryVersion)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end
end
