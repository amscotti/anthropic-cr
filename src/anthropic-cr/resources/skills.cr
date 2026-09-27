module Anthropic
  # Where a skill comes from.
  struct SkillSource
    include JSON::Serializable

    # `"custom"`, `"anthropic"`, `"anthropic_example"`, or `"plugin"`.
    getter type : String
  end

  # Skill response from the Skills API
  struct SkillResponse
    include JSON::Serializable

    getter id : String
    getter type : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "updated_at")]
    getter updated_at : String

    @[JSON::Field(key: "display_name")]
    getter display_name : String

    @[JSON::Field(key: "latest_version_id")]
    getter latest_version_id : String

    getter source : SkillSource
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

    # Opaque cursor for the next page, if any
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

    getter description : String
    getter name : String

    @[JSON::Field(key: "skill_id")]
    getter skill_id : String
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

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?
  end

  # Skills API for managing skills.
  #
  # Access via `client.skills`.
  #
  # ```
  # # List skills
  # skills = client.skills.list
  # skills.data.each { |s| puts s.id }
  #
  # # Retrieve a skill
  # skill = client.skills.retrieve("skill_abc123")
  #
  # # Delete a skill
  # client.skills.delete("skill_abc123")
  # ```
  class Skills
    def initialize(@client : Client)
    end

    # Create a skill by uploading files
    #
    # ```
    # skill = client.skills.create(
    #   files: [
    #     Anthropic::FileUpload.new(
    #       io: File.open("SKILL.md"),
    #       filename: "my-skill/SKILL.md",
    #       content_type: "text/markdown"
    #     ),
    #   ],
    #   display_name: "My Skill"
    # )
    # ```
    def create(
      files : Array(FileUpload),
      display_name : String? = nil,
      workspace_id : String? = nil,
    ) : SkillResponse
      form_fields = display_name ? {"display_name" => display_name} : nil

      response = @client.post_multipart_files(
        "/v1/skills",
        files,
        form_fields,
        Anthropic.merge_workspace_header(nil, workspace_id)
      )
      SkillResponse.from_json(response.body)
    end

    # List skills
    #
    # ```
    # skills = client.skills.list(limit: 10)
    # skills.data.each { |s| puts s.display_name }
    # ```
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      source : String? = nil,
      workspace_id : String? = nil,
    ) : SkillListResponse
      params = {"limit" => limit.to_s}
      params["page"] = page if page
      params["source"] = source if source

      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/skills", params, headers)
      SkillListResponse.from_json(response.body)
    end

    # Retrieve a skill by ID
    def retrieve(skill_id : String, workspace_id : String? = nil) : SkillResponse
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/skills/#{skill_id}", nil, headers)
      SkillResponse.from_json(response.body)
    end

    # Delete a skill
    def delete(skill_id : String, workspace_id : String? = nil) : SkillDeleteResponse
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.delete("/v1/skills/#{skill_id}", headers)
      SkillDeleteResponse.from_json(response.body)
    end

    # Access skill versions sub-resource
    def versions : SkillVersions
      SkillVersions.new(@client)
    end
  end

  # Skill Versions API for managing skill versions.
  #
  # Access via `client.skills.versions`.
  class SkillVersions
    def initialize(@client : Client)
    end

    # Create a new skill version by uploading files
    #
    # ```
    # version = client.skills.versions.create(
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
      workspace_id : String? = nil,
    ) : SkillVersionResponse
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.post_multipart_files(
        "/v1/skills/#{skill_id}/versions",
        files,
        nil,
        headers
      )
      SkillVersionResponse.from_json(response.body)
    end

    # List versions for a skill
    def list(
      skill_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      workspace_id : String? = nil,
    ) : SkillVersionListResponse
      params = {"limit" => limit.to_s}
      params["page"] = page if page

      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/skills/#{skill_id}/versions", params, headers)
      SkillVersionListResponse.from_json(response.body)
    end

    # Retrieve a specific skill version
    def retrieve(skill_id : String, version : String, workspace_id : String? = nil) : SkillVersionResponse
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/skills/#{skill_id}/versions/#{version}", nil, headers)
      SkillVersionResponse.from_json(response.body)
    end

    # Delete a specific skill version
    def delete(skill_id : String, version : String, workspace_id : String? = nil) : SkillVersionDeleteResponse
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.delete("/v1/skills/#{skill_id}/versions/#{version}", headers)
      SkillVersionDeleteResponse.from_json(response.body)
    end
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
    #   display_name: "My Skill"
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
    #   display_name: "My Skill"
    # )
    # ```
    def create(
      files : Array(FileUpload),
      display_name : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillResponse
      form_fields = display_name ? {"display_name" => display_name} : nil

      response = @client.post_multipart_files(
        "/v1/skills?beta=true",
        files,
        form_fields,
        beta_headers(betas, workspace_id)
      )
      SkillResponse.from_json(response.body)
    end

    # List skills
    #
    # ```
    # skills = client.beta.skills.list(limit: 10)
    # skills.data.each { |s| puts s.display_name }
    # ```
    def list(
      limit : Int32 = 20,
      page : String? = nil,
      source : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillListResponse
      params = {"limit" => limit.to_s}
      params["page"] = page if page
      params["source"] = source if source

      response = @client.get("/v1/skills?beta=true", params, beta_headers(betas, workspace_id))
      SkillListResponse.from_json(response.body)
    end

    # Retrieve a skill by ID
    def retrieve(
      skill_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillResponse
      response = @client.get("/v1/skills/#{skill_id}?beta=true", nil, beta_headers(betas, workspace_id))
      SkillResponse.from_json(response.body)
    end

    # Delete a skill
    def delete(
      skill_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillDeleteResponse
      response = @client.delete("/v1/skills/#{skill_id}?beta=true", beta_headers(betas, workspace_id))
      SkillDeleteResponse.from_json(response.body)
    end

    # Access skill versions sub-resource
    def versions : BetaSkillVersions
      BetaSkillVersions.new(@client)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged = betas.dup
      merged << BETA_HEADER unless merged.includes?(BETA_HEADER)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged.join(",")}, workspace_id) || {} of String => String
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
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillVersionResponse
      response = @client.post_multipart_files(
        "/v1/skills/#{skill_id}/versions?beta=true",
        files,
        nil,
        beta_headers(betas, workspace_id)
      )
      SkillVersionResponse.from_json(response.body)
    end

    # List versions for a skill
    def list(
      skill_id : String,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillVersionListResponse
      params = {"limit" => limit.to_s}
      params["page"] = page if page

      response = @client.get("/v1/skills/#{skill_id}/versions?beta=true", params, beta_headers(betas, workspace_id))
      SkillVersionListResponse.from_json(response.body)
    end

    # Retrieve a specific skill version
    def retrieve(
      skill_id : String,
      version : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillVersionResponse
      response = @client.get("/v1/skills/#{skill_id}/versions/#{version}?beta=true", nil, beta_headers(betas, workspace_id))
      SkillVersionResponse.from_json(response.body)
    end

    # Delete a specific skill version
    def delete(
      skill_id : String,
      version : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : SkillVersionDeleteResponse
      response = @client.delete("/v1/skills/#{skill_id}/versions/#{version}?beta=true", beta_headers(betas, workspace_id))
      SkillVersionDeleteResponse.from_json(response.body)
    end

    # Download a skill version archive
    #
    # ```
    # archive = client.beta.skills.versions.download("skill_abc123", "sv_01abc")
    # File.write("skill.tgz", archive.to_s)
    # ```
    def download(
      skill_id : String,
      version : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : IO::Memory
      headers = beta_headers(betas, workspace_id)
      headers["accept"] = "application/binary"
      @client.get_raw("/v1/skills/#{skill_id}/versions/#{version}/content?beta=true", headers)
    end

    private def beta_headers(
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Hash(String, String)
      merged = betas.dup
      merged << BETA_HEADER unless merged.includes?(BETA_HEADER)
      Anthropic.merge_workspace_header({"anthropic-beta" => merged.join(",")}, workspace_id) || {} of String => String
    end
  end
end
