module Anthropic
  # Skill response from the Skills API
  struct SkillResponse
    include JSON::Serializable

    getter id : String
    getter type : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "display_title")]
    getter display_title : String?

    @[JSON::Field(key: "latest_version")]
    getter latest_version : String?

    getter source : String
  end

  # Response from deleting a skill
  struct SkillDeleteResponse
    include JSON::Serializable

    getter id : String
    getter type : String # "skill_deleted"
  end

  # Paginated list of skills
  struct SkillListResponse
    include JSON::Serializable

    getter data : Array(SkillResponse)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Skill version response
  struct SkillVersionResponse
    include JSON::Serializable

    getter id : String
    getter type : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter description : String?
    getter directory : String?
    getter name : String?

    @[JSON::Field(key: "skill_id")]
    getter skill_id : String

    getter version : String
  end

  # Response from deleting a skill version
  struct SkillVersionDeleteResponse
    include JSON::Serializable

    getter id : String
    getter type : String # "skill_version_deleted"
  end

  # Paginated list of skill versions
  struct SkillVersionListResponse
    include JSON::Serializable

    getter data : Array(SkillVersionResponse)

    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Skills API for managing skills (Beta)
  #
  # Access via `client.beta.skills`.
  #
  # ```
  # # List skills
  # skills = client.beta.skills.list
  # skills.data.each { |s| puts s.id }
  #
  # # Retrieve a skill
  # skill = client.beta.skills.retrieve("skill_abc123")
  #
  # # Delete a skill
  # client.beta.skills.delete("skill_abc123")
  # ```
  class BetaSkills
    BETA_HEADER = SKILLS_BETA

    def initialize(@client : Client)
    end

    # Create a skill by uploading files
    #
    # Using FileUpload struct:
    # ```
    # skill = client.beta.skills.create(
    #   files: [
    #     Anthropic::FileUpload.new(
    #       io: File.open("tool.py"),
    #       filename: "tool.py",
    #       content_type: "text/x-python"
    #     ),
    #   ],
    #   display_title: "My Skill"
    # )
    # ```
    #
    # Using convenience method (auto-detects content type):
    # ```
    # skill = client.beta.skills.create(
    #   files: [
    #     Anthropic::FileUpload.from_path(
    #       "src/tool.py",
    #       filename: "my-skill/tool.py"
    #     ),
    #   ],
    #   display_title: "My Skill"
    # )
    # ```
    def create(
      files : Array(FileUpload),
      display_title : String? = nil,
    ) : SkillResponse
      form_fields = display_title ? {"display_title" => display_title} : nil

      response = @client.post_multipart_files(
        "/v1/skills?beta=true",
        files,
        form_fields,
        beta_headers
      )
      SkillResponse.from_json(response.body)
    end

    # List skills
    #
    # ```
    # skills = client.beta.skills.list(limit: 10)
    # skills.data.each { |s| puts s.display_title }
    # ```
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      source : String? = nil,
    ) : SkillListResponse
      params = {"limit" => limit.to_s}
      params["page"] = page if page
      params["source"] = source if source

      path = "/v1/skills?beta=true"
      params.each { |k, v| path += "&#{k}=#{URI.encode_path_segment(v)}" }

      response = @client.get(path, nil, beta_headers)
      SkillListResponse.from_json(response.body)
    end

    # Retrieve a skill by ID
    def retrieve(skill_id : String) : SkillResponse
      response = @client.get("/v1/skills/#{skill_id}?beta=true", nil, beta_headers)
      SkillResponse.from_json(response.body)
    end

    # Delete a skill
    def delete(skill_id : String) : SkillDeleteResponse
      response = @client.delete("/v1/skills/#{skill_id}?beta=true", beta_headers)
      SkillDeleteResponse.from_json(response.body)
    end

    # Access skill versions sub-resource
    def versions : BetaSkillVersions
      BetaSkillVersions.new(@client)
    end

    private def beta_headers : Hash(String, String)
      {"anthropic-beta" => BETA_HEADER}
    end
  end

  # Skill Versions API for managing skill versions (Beta)
  #
  # Access via `client.beta.skills.versions`.
  class BetaSkillVersions
    BETA_HEADER = SKILLS_BETA

    def initialize(@client : Client)
    end

    # Create a new skill version by uploading files
    #
    # ```
    # version = client.beta.skills.versions.create(
    #   skill_id: "skill_abc123",
    #   files: [
    #     Anthropic::FileUpload.new(
    #       io: File.open("tool.py"),
    #       filename: "skill-name/tool.py",
    #       content_type: "text/x-python"
    #     ),
    #   ]
    # )
    # ```
    def create(
      skill_id : String,
      files : Array(FileUpload),
    ) : SkillVersionResponse
      response = @client.post_multipart_files(
        "/v1/skills/#{skill_id}/versions?beta=true",
        files,
        nil,
        beta_headers
      )
      SkillVersionResponse.from_json(response.body)
    end

    # List versions for a skill
    def list(
      skill_id : String,
      limit : Int32 = 20,
      page : String? = nil,
    ) : SkillVersionListResponse
      path = "/v1/skills/#{skill_id}/versions?beta=true"
      path += "&limit=#{limit}"
      path += "&page=#{URI.encode_path_segment(page)}" if page

      response = @client.get(path, nil, beta_headers)
      SkillVersionListResponse.from_json(response.body)
    end

    # Retrieve a specific skill version
    def retrieve(skill_id : String, version : String) : SkillVersionResponse
      response = @client.get("/v1/skills/#{skill_id}/versions/#{version}?beta=true", nil, beta_headers)
      SkillVersionResponse.from_json(response.body)
    end

    # Delete a specific skill version
    def delete(skill_id : String, version : String) : SkillVersionDeleteResponse
      response = @client.delete("/v1/skills/#{skill_id}/versions/#{version}?beta=true", beta_headers)
      SkillVersionDeleteResponse.from_json(response.body)
    end

    private def beta_headers : Hash(String, String)
      {"anthropic-beta" => BETA_HEADER}
    end
  end
end
