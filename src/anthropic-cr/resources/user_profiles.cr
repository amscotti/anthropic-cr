module Anthropic
  # Trust grant attached to a `BetaUserProfile`.
  #
  # `status` is one of `"active"`, `"pending"`, or `"rejected"`.
  struct BetaUserProfileTrustGrant
    include JSON::Serializable

    getter status : String

    def initialize(@status : String)
    end
  end

  # A user profile scopes per-user state (memory, trust grants, etc.) to a
  # specific end user of your application. Accessible via
  # `client.beta.user_profiles`.
  #
  # Requires the beta header `user-profiles-2026-03-24`. When the resource
  # methods are called, the header is applied automatically.
  struct BetaUserProfile
    include JSON::Serializable

    # Unique identifier prefixed `uprof_`.
    getter id : String

    # Object type. Always `"user_profile"`.
    getter type : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    # Free-form metadata attached to the profile.
    getter metadata : Hash(String, String)

    # Trust grants keyed by grant name. Keys omitted when no grant is active.
    @[JSON::Field(key: "trust_grants")]
    getter trust_grants : Hash(String, BetaUserProfileTrustGrant)

    # Optional platform-assigned external identifier (not enforced unique).
    @[JSON::Field(key: "external_id", emit_null: false)]
    getter external_id : String?

    # How the platform uses the API on behalf of the entity this profile
    # represents: `"application"` or `"passthrough"`.
    @[JSON::Field(key: "access_type", emit_null: false)]
    getter access_type : String?

    # Real-world name of the entity this profile represents.
    @[JSON::Field(emit_null: false)]
    getter name : String?

    # RFC 3339 timestamp recording when the end user completed onboarding.
    @[JSON::Field(key: "external_user_onboarded_at", emit_null: false)]
    getter external_user_onboarded_at : String?
  end

  # Access-type values for `BetaUserProfile#access_type`.
  module UserProfileAccessType
    APPLICATION = "application"
    PASSTHROUGH = "passthrough"
  end

  # Enrollment URL response for a user profile.
  struct BetaUserProfileEnrollmentURL
    include JSON::Serializable

    getter type : String

    @[JSON::Field(key: "expires_at")]
    getter expires_at : String

    getter url : String
  end

  # Paginated list of user profiles.
  struct BetaUserProfileListResponse
    include JSON::Serializable

    getter data : Array(BetaUserProfile)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    @[JSON::Field(key: "last_id")]
    getter last_id : String?
  end

  # User Profiles API (beta) for creating and managing per-end-user state.
  #
  # Access via `client.beta.user_profiles`.
  #
  # ```
  # profile = client.beta.user_profiles.create(
  #   external_id: "user-123",
  #   metadata: {"plan" => "pro"}
  # )
  #
  # enrollment = client.beta.user_profiles.create_enrollment_url(profile.id)
  # puts enrollment.url
  #
  # # Pass the profile id when creating a message so the API applies
  # # per-user state like memory.
  # client.beta.messages.create(
  #   model: Anthropic::Model::CLAUDE_OPUS_4_7,
  #   max_tokens: 1024,
  #   messages: [Anthropic::MessageParam.user("Hi!")],
  #   user_profile_id: profile.id
  # )
  # ```
  class BetaUserProfiles
    BETA_HEADER = USER_PROFILES_BETA

    def initialize(@client : Client)
    end

    # Create a new user profile.
    def create(
      external_id : String? = nil,
      metadata : Hash(String, String)? = nil,
      access_type : String? = nil,
      name : String? = nil,
      external_user_onboarded_at : String? = nil,
    ) : BetaUserProfile
      body = {} of String => JSON::Any
      body["external_id"] = JSON::Any.new(external_id) if external_id
      body["metadata"] = JSON.parse(metadata.to_json) if metadata
      body["access_type"] = JSON::Any.new(access_type) if access_type
      body["name"] = JSON::Any.new(name) if name
      if onboarded = external_user_onboarded_at
        body["external_user_onboarded_at"] = JSON::Any.new(onboarded)
      end

      response = @client.post("/v1/user_profiles?beta=true", body, beta_headers)
      BetaUserProfile.from_json(response.body)
    end

    # Retrieve a user profile by ID.
    def retrieve(user_profile_id : String) : BetaUserProfile
      response = @client.get("/v1/user_profiles/#{user_profile_id}?beta=true", nil, beta_headers)
      BetaUserProfile.from_json(response.body)
    end

    # Update metadata or external_id for an existing user profile.
    #
    # To remove a metadata key, set its value to an empty string. Keys not
    # provided are left unchanged.
    def update(
      user_profile_id : String,
      external_id : String? = nil,
      metadata : Hash(String, String)? = nil,
      access_type : String? = nil,
      name : String? = nil,
      external_user_onboarded_at : String? = nil,
    ) : BetaUserProfile
      body = {} of String => JSON::Any
      body["external_id"] = JSON::Any.new(external_id) if external_id
      body["metadata"] = JSON.parse(metadata.to_json) if metadata
      body["access_type"] = JSON::Any.new(access_type) if access_type
      body["name"] = JSON::Any.new(name) if name
      if onboarded = external_user_onboarded_at
        body["external_user_onboarded_at"] = JSON::Any.new(onboarded)
      end

      response = @client.post("/v1/user_profiles/#{user_profile_id}?beta=true", body, beta_headers)
      BetaUserProfile.from_json(response.body)
    end

    # List user profiles with optional pagination.
    #
    # `order` may be `"asc"` or `"desc"`. `order_by` selects the sort key
    # (e.g. `"name"`).
    def list(
      limit : Int32 = 20,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
    ) : BetaUserProfileListResponse
      path = "/v1/user_profiles?beta=true&limit=#{limit}"
      path += "&order=#{URI.encode_path_segment(order)}" if order
      path += "&order_by=#{URI.encode_path_segment(order_by)}" if order_by
      path += "&page=#{URI.encode_path_segment(page)}" if page

      response = @client.get(path, nil, beta_headers)
      BetaUserProfileListResponse.from_json(response.body)
    end

    # Create an enrollment URL for the given user profile.
    #
    # Send the returned URL to the end user so they can complete enrollment.
    def create_enrollment_url(user_profile_id : String) : BetaUserProfileEnrollmentURL
      response = @client.post(
        "/v1/user_profiles/#{user_profile_id}/enrollment_url?beta=true",
        {} of String => JSON::Any,
        beta_headers
      )
      BetaUserProfileEnrollmentURL.from_json(response.body)
    end

    private def beta_headers : Hash(String, String)
      {"anthropic-beta" => BETA_HEADER}
    end
  end
end
