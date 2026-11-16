module Anthropic
  # Union of values accepted for `external_user_details` on user profile create/update.
  alias UserProfileExternalUserDetailsParamLike = UserProfileExternalUserDetails | BetaUserProfileExternalUserDetails | Hash(String, JSON::Any) | JSON::Any

  # :nodoc:
  # Shared request-shaping helpers for GA and Beta user profile resources.
  module UserProfileRequestHelper
    def self.build_write_body(
      access_type : String | JSON::Any | Nil = nil,
      external_id : String? = nil,
      external_user_details : UserProfileExternalUserDetailsParamLike? = nil,
      external_user_onboarded_at : String? = nil,
      metadata : Hash(String, String)? = nil,
      name : String | JSON::Any | Nil = nil,
    ) : Hash(String, JSON::Any)
      body = {} of String => JSON::Any
      body["external_id"] = JSON::Any.new(external_id) if external_id
      body["metadata"] = JSON.parse(metadata.to_json) if metadata
      append_json_or_string(body, "access_type", access_type)
      append_json_or_string(body, "name", name)
      if onboarded = external_user_onboarded_at
        body["external_user_onboarded_at"] = JSON::Any.new(onboarded)
      end
      body["external_user_details"] = JSON.parse(external_user_details.to_json) if external_user_details
      body
    end

    def self.build_list_query(
      limit : Int32,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      enforcement_status : Array(String)? = nil,
    ) : Hash(String, Client::QueryParamValue)
      query = {} of String => Client::QueryParamValue
      query["limit"] = limit.to_s
      query["order"] = order if order
      query["order_by"] = order_by if order_by
      query["page"] = page if page
      query["enforcement_status"] = enforcement_status if enforcement_status
      query
    end

    private def self.append_json_or_string(
      body : Hash(String, JSON::Any),
      key : String,
      value : String | JSON::Any | Nil,
    ) : Nil
      case value
      when String
        body[key] = JSON::Any.new(value)
      when JSON::Any
        body[key] = value
      end
    end
  end

  # Action URLs sub-resource for GA `UserProfiles` (`client.user_profiles.action_urls`).
  class UserProfileActionURLs
    def initialize(@client : Client)
    end

    # Create an action URL (for example end-user enrollment) for a user profile.
    def create(
      user_profile_id : String,
      action : UserProfileEnrollEndUserAction | BetaUserProfileEnrollEndUserAction | Hash(String, String) | Hash(String, JSON::Any) | JSON::Any,
      workspace_id : String? = nil,
    ) : UserProfileActionURL
      body = {"action" => JSON.parse(action.to_json)}
      response = @client.post(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}/action_urls",
        body,
        Anthropic.merge_workspace_header(nil, workspace_id)
      )
      UserProfileActionURL.from_json(response.body)
    end
  end

  # GA User Profiles API (`client.user_profiles`) for creating and managing
  # per-end-user profiles, enforcement state, and program enrollments.
  class UserProfiles
    def initialize(@client : Client)
    end

    # Access action URLs sub-resource (`client.user_profiles.action_urls`).
    def action_urls : UserProfileActionURLs
      UserProfileActionURLs.new(@client)
    end

    # Create a new GA user profile.
    def create(
      access_type : String? = nil,
      external_user_details : UserProfileExternalUserDetailsParamLike? = nil,
      metadata : Hash(String, String)? = nil,
      name : String? = nil,
      workspace_id : String? = nil,
    ) : UserProfile
      body = UserProfileRequestHelper.build_write_body(
        access_type: access_type,
        external_user_details: external_user_details,
        metadata: metadata,
        name: name
      )
      response = @client.post("/v1/user_profiles", body, Anthropic.merge_workspace_header(nil, workspace_id))
      UserProfile.from_json(response.body)
    end

    # Retrieve a GA user profile by ID.
    def retrieve(
      user_profile_id : String,
      workspace_id : String? = nil,
    ) : UserProfile
      response = @client.get(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}",
        nil,
        Anthropic.merge_workspace_header(nil, workspace_id)
      )
      UserProfile.from_json(response.body)
    end

    # Update an existing GA user profile.
    def update(
      user_profile_id : String,
      access_type : String | JSON::Any | Nil = nil,
      external_user_details : UserProfileExternalUserDetailsParamLike? = nil,
      metadata : Hash(String, String)? = nil,
      name : String | JSON::Any | Nil = nil,
      workspace_id : String? = nil,
    ) : UserProfile
      body = UserProfileRequestHelper.build_write_body(
        access_type: access_type,
        external_user_details: external_user_details,
        metadata: metadata,
        name: name
      )
      response = @client.post(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}",
        body,
        Anthropic.merge_workspace_header(nil, workspace_id)
      )
      UserProfile.from_json(response.body)
    end

    # List GA user profiles with optional `enforcement_status` filter and pagination.
    def list(
      enforcement_status : Array(String)? = nil,
      limit : Int32 = 20,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      workspace_id : String? = nil,
    ) : UserProfileListResponse
      query = UserProfileRequestHelper.build_list_query(
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
        enforcement_status: enforcement_status
      )
      response = @client.get("/v1/user_profiles", query, Anthropic.merge_workspace_header(nil, workspace_id))
      UserProfileListResponse.from_json(response.body)
    end

    # Delete a GA user profile.
    def delete(
      user_profile_id : String,
      workspace_id : String? = nil,
    ) : DeletedUserProfile
      response = @client.delete(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}",
        Anthropic.merge_workspace_header(nil, workspace_id)
      )
      DeletedUserProfile.from_json(response.body)
    end
  end

  # Action URLs sub-resource for Beta `BetaUserProfiles`
  # (`client.beta.user_profiles.action_urls`).
  class BetaUserProfileActionURLs
    def initialize(@client : Client)
    end

    # Create an action URL for a user profile (beta).
    def create(
      user_profile_id : String,
      action : BetaUserProfileEnrollEndUserAction | UserProfileEnrollEndUserAction | Hash(String, String) | Hash(String, JSON::Any) | JSON::Any,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfileActionURL
      merged = betas.dup
      merged << USER_PROFILES_BETA unless merged.includes?(USER_PROFILES_BETA)
      headers = Anthropic.merge_workspace_header({"anthropic-beta" => merged.join(",")}, workspace_id) || {} of String => String
      body = {"action" => JSON.parse(action.to_json)}

      response = @client.post(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}/action_urls",
        body,
        headers,
        beta: true
      )
      BetaUserProfileActionURL.from_json(response.body)
    end
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

    # Access action URLs sub-resource (`client.beta.user_profiles.action_urls`).
    def action_urls : BetaUserProfileActionURLs
      BetaUserProfileActionURLs.new(@client)
    end

    # Create a new user profile.
    #
    # `external_user_details` is accepted under the
    # `user-profiles-2026-09-04` beta only (attached automatically when
    # the details are present); under that revision send
    # `external_user_details.reference_id` instead of `external_id`.
    def create(
      external_id : String? = nil,
      metadata : Hash(String, String)? = nil,
      access_type : String? = nil,
      name : String? = nil,
      external_user_onboarded_at : String? = nil,
      external_user_details : UserProfileExternalUserDetailsParamLike? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfile
      body = UserProfileRequestHelper.build_write_body(
        access_type: access_type,
        external_id: external_id,
        external_user_details: external_user_details,
        external_user_onboarded_at: external_user_onboarded_at,
        metadata: metadata,
        name: name
      )

      response = @client.post("/v1/user_profiles", body, beta_headers(!external_user_details.nil?, betas, workspace_id), beta: true)
      BetaUserProfile.from_json(response.body)
    end

    # Retrieve a user profile by ID.
    def retrieve(
      user_profile_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfile
      response = @client.get("/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}", nil, beta_headers(false, betas, workspace_id), beta: true)
      BetaUserProfile.from_json(response.body)
    end

    # Update metadata, name, access_type, or external details for an existing user profile.
    #
    # To remove a metadata key, set its value to an empty string. Keys not
    # provided are left unchanged.
    #
    # `external_user_details` is accepted under the
    # `user-profiles-2026-09-04` beta only (attached automatically when
    # the details are present); under that revision send
    # `external_user_details.reference_id` instead of `external_id`.
    def update(
      user_profile_id : String,
      external_id : String? = nil,
      metadata : Hash(String, String)? = nil,
      access_type : String | JSON::Any | Nil = nil,
      name : String | JSON::Any | Nil = nil,
      external_user_onboarded_at : String? = nil,
      external_user_details : UserProfileExternalUserDetailsParamLike? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfile
      body = UserProfileRequestHelper.build_write_body(
        access_type: access_type,
        external_id: external_id,
        external_user_details: external_user_details,
        external_user_onboarded_at: external_user_onboarded_at,
        metadata: metadata,
        name: name
      )

      response = @client.post("/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}", body, beta_headers(!external_user_details.nil?, betas, workspace_id), beta: true)
      BetaUserProfile.from_json(response.body)
    end

    # List user profiles with optional `enforcement_status` filter and pagination.
    #
    # `order` may be `"asc"` or `"desc"`. `order_by` selects the sort key
    # (e.g. `"name"`).
    def list(
      limit : Int32 = 20,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      enforcement_status : Array(String)? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfileListResponse
      query = UserProfileRequestHelper.build_list_query(
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
        enforcement_status: enforcement_status
      )

      response = @client.get("/v1/user_profiles", query, beta_headers(false, betas, workspace_id), beta: true)
      BetaUserProfileListResponse.from_json(response.body)
    end

    # Delete a user profile (beta).
    def delete(
      user_profile_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaDeletedUserProfile
      response = @client.delete(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}",
        beta_headers(false, betas, workspace_id),
        beta: true
      )
      BetaDeletedUserProfile.from_json(response.body)
    end

    # Create an enrollment URL for the given user profile.
    #
    # Send the returned URL to the end user so they can complete enrollment.
    def create_enrollment_url(
      user_profile_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : BetaUserProfileEnrollmentURL
      response = @client.post(
        "/v1/user_profiles/#{Anthropic.encode_path_segment(user_profile_id)}/enrollment_url",
        {} of String => JSON::Any,
        beta_headers(false, betas, workspace_id),
        beta: true
      )
      BetaUserProfileEnrollmentURL.from_json(response.body)
    end

    private def beta_headers(
      include_details_revision : Bool = false,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged = betas.dup
      merged << BETA_HEADER unless merged.includes?(BETA_HEADER)
      if include_details_revision
        merged << USER_PROFILES_2026_09_04_BETA unless merged.includes?(USER_PROFILES_2026_09_04_BETA)
      end
      Anthropic.merge_workspace_header({"anthropic-beta" => merged.join(",")}, workspace_id) || {} of String => String
    end
  end
end
