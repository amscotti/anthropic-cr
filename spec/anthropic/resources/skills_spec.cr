require "../../spec_helper"

describe Anthropic::SkillResponse do
  it "parses from JSON" do
    skill = Anthropic::SkillResponse.from_json(Fixtures::Responses::SKILL_RESPONSE)

    skill.id.should eq("skill_01abc")
    skill.type.should eq("skill")
    skill.created_at.should eq("2025-10-01T00:00:00Z")
    skill.updated_at.should eq("2025-10-01T00:00:00Z")
    skill.display_name.should eq("My Skill")
    skill.latest_version_id.should eq("sv_01abc")
    skill.source.type.should eq("custom")
  end
end

describe Anthropic::SkillListResponse do
  it "parses from JSON" do
    list = Anthropic::SkillListResponse.from_json(Fixtures::Responses::SKILL_LIST)

    list.data.size.should eq(2)
    list.next_page.should be_nil
    list.data[0].id.should eq("skill_01abc")
    list.data[1].id.should eq("skill_02def")
  end
end

describe Anthropic::SkillDeleteResponse do
  it "parses from JSON" do
    deleted = Anthropic::SkillDeleteResponse.from_json(Fixtures::Responses::SKILL_DELETED)

    deleted.id.should eq("skill_01abc")
    deleted.type.should eq("skill_deleted")
  end
end

describe Anthropic::SkillVersionResponse do
  it "parses from JSON" do
    version = Anthropic::SkillVersionResponse.from_json(Fixtures::Responses::SKILL_VERSION_RESPONSE)

    version.id.should eq("sv_01abc")
    version.type.should eq("skill_version")
    version.created_at.should eq("2025-10-01T00:00:00Z")
    version.description.should eq("Initial version")
    version.name.should eq("my-skill")
    version.skill_id.should eq("skill_01abc")
  end
end

describe Anthropic::SkillVersionListResponse do
  it "parses from JSON" do
    list = Anthropic::SkillVersionListResponse.from_json(Fixtures::Responses::SKILL_VERSION_LIST)

    list.data.size.should eq(1)
    list.next_page.should be_nil
    list.data[0].name.should eq("my-skill")
  end
end

describe Anthropic::SkillVersionDeleteResponse do
  it "parses from JSON" do
    deleted = Anthropic::SkillVersionDeleteResponse.from_json(Fixtures::Responses::SKILL_VERSION_DELETED)

    deleted.id.should eq("sv_01abc")
    deleted.type.should eq("skill_version_deleted")
  end
end

describe Anthropic::BetaSkills do
  it "lists skills with correct path" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills?beta=true&limit=20", Fixtures::Responses::SKILL_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.list

    result.data.size.should eq(2)
    headers = capture.headers.not_nil!
    headers["anthropic-beta"].should contain("skills-2025-10-02")
  end

  it "lists skills with source filter" do
    stub_and_capture(:get, "https://api.anthropic.com/v1/skills?beta=true&limit=10&source=upload", Fixtures::Responses::SKILL_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.list(limit: 10, source: "upload")

    result.data.size.should eq(2)
  end

  it "retrieves a skill" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc?beta=true", Fixtures::Responses::SKILL_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    skill = client.beta.skills.retrieve("skill_01abc")

    skill.id.should eq("skill_01abc")
    headers = capture.headers.not_nil!
    headers["anthropic-beta"].should contain("skills-2025-10-02")
  end

  it "deletes a skill" do
    stub_and_capture(:delete, "https://api.anthropic.com/v1/skills/skill_01abc?beta=true", Fixtures::Responses::SKILL_DELETED)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.delete("skill_01abc")

    result.id.should eq("skill_01abc")
    result.type.should eq("skill_deleted")
  end

  it "creates a skill with multipart upload" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/skills?beta=true")
      .to_return(body: Fixtures::Responses::SKILL_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    io = IO::Memory.new("print('hello')")

    skill = client.beta.skills.create(
      files: [Anthropic::FileUpload.new(io: io, filename: "tool.py", content_type: "text/x-python")],
      display_name: "My Skill"
    )

    skill.id.should eq("skill_01abc")
    skill.display_name.should eq("My Skill")
  end
end

describe Anthropic::BetaSkillVersions do
  it "lists versions" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions?beta=true&limit=20", Fixtures::Responses::SKILL_VERSION_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.versions.list(skill_id: "skill_01abc")

    result.data.size.should eq(1)
    result.data[0].name.should eq("my-skill")
    headers = capture.headers.not_nil!
    headers["anthropic-beta"].should contain("skills-2025-10-02")
  end

  it "retrieves a version" do
    stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions/v1?beta=true", Fixtures::Responses::SKILL_VERSION_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    version = client.beta.skills.versions.retrieve(skill_id: "skill_01abc", version: "v1")

    version.id.should eq("sv_01abc")
    version.skill_id.should eq("skill_01abc")
  end

  it "deletes a version" do
    stub_and_capture(:delete, "https://api.anthropic.com/v1/skills/skill_01abc/versions/v1?beta=true", Fixtures::Responses::SKILL_VERSION_DELETED)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.versions.delete(skill_id: "skill_01abc", version: "v1")

    result.id.should eq("sv_01abc")
    result.type.should eq("skill_version_deleted")
  end

  it "creates a version with multipart upload" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01abc/versions?beta=true")
      .to_return(body: Fixtures::Responses::SKILL_VERSION_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    io = IO::Memory.new("print('hello v2')")

    version = client.beta.skills.versions.create(
      skill_id: "skill_01abc",
      files: [Anthropic::FileUpload.new(io: io, filename: "tool.py", content_type: "text/x-python")]
    )

    version.id.should eq("sv_01abc")
    version.name.should eq("my-skill")
  end
end

describe Anthropic::Skills do
  it "lists skills without a beta header" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills?limit=20", Fixtures::Responses::SKILL_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.skills.list

    result.data.size.should eq(2)
    result.data[0].display_name.should eq("My Skill")
    capture.headers.not_nil!.has_key?("anthropic-beta").should be_false
  end

  it "passes source and workspace parameters" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills?limit=20&source=custom", Fixtures::Responses::SKILL_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    client.skills.list(source: "custom", workspace_id: "wrkspc_1")

    capture.path.not_nil!.should contain("source=custom")
    capture.headers.not_nil!["anthropic-workspace-id"].should eq("wrkspc_1")
  end

  it "retrieves a skill" do
    WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01abc")
      .to_return(body: Fixtures::Responses::SKILL_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    skill = client.skills.retrieve("skill_01abc")

    skill.id.should eq("skill_01abc")
    skill.source.type.should eq("custom")
  end

  it "deletes a skill" do
    WebMock.stub(:delete, "https://api.anthropic.com/v1/skills/skill_01abc")
      .to_return(body: Fixtures::Responses::SKILL_DELETED)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.skills.delete("skill_01abc")

    result.type.should eq("skill_deleted")
  end

  it "creates a skill with multipart upload" do
    capture = stub_and_capture(:post, "https://api.anthropic.com/v1/skills", Fixtures::Responses::SKILL_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    io = IO::Memory.new("print('hello')")

    skill = client.skills.create(
      files: [Anthropic::FileUpload.new(io: io, filename: "tool.py", content_type: "text/x-python")],
      display_name: "My Skill"
    )

    skill.id.should eq("skill_01abc")
    capture.body.not_nil!.should contain("display_name")
  end
end

describe Anthropic::SkillVersions do
  it "manages versions without a beta header" do
    stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions?limit=20", Fixtures::Responses::SKILL_VERSION_LIST)
    stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions/sv_01abc", Fixtures::Responses::SKILL_VERSION_RESPONSE)
    stub_and_capture(:delete, "https://api.anthropic.com/v1/skills/skill_01abc/versions/sv_01abc", Fixtures::Responses::SKILL_VERSION_DELETED)

    client = Anthropic::Client.new(api_key: "sk-ant-test")

    result = client.skills.versions.list(skill_id: "skill_01abc")
    result.data.size.should eq(1)

    version = client.skills.versions.retrieve(skill_id: "skill_01abc", version: "sv_01abc")
    version.name.should eq("my-skill")

    deleted = client.skills.versions.delete(skill_id: "skill_01abc", version: "sv_01abc")
    deleted.type.should eq("skill_version_deleted")
  end

  it "creates a version with multipart upload" do
    WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01abc/versions")
      .to_return(body: Fixtures::Responses::SKILL_VERSION_RESPONSE)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    io = IO::Memory.new("print('hello v2')")

    version = client.skills.versions.create(
      skill_id: "skill_01abc",
      files: [Anthropic::FileUpload.new(io: io, filename: "tool.py", content_type: "text/x-python")]
    )

    version.id.should eq("sv_01abc")
  end
end

describe "Anthropic::BetaSkillVersions download" do
  it "downloads a version archive as binary" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions/sv_01abc/content?beta=true", "archive-bytes")

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    archive = client.beta.skills.versions.download(skill_id: "skill_01abc", version: "sv_01abc")

    archive.to_s.should eq("archive-bytes")
    headers = capture.headers.not_nil!
    headers["accept"].should eq("application/binary")
    headers["anthropic-beta"].should contain("skills-2025-10-02")
  end
end
