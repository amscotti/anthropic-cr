require "../../spec_helper"

describe Anthropic::SkillResponse do
  it "parses from JSON" do
    skill = Anthropic::SkillResponse.from_json(Fixtures::Responses::SKILL_RESPONSE)

    skill.id.should eq("skill_01abc")
    skill.type.should eq("skill")
    skill.created_at.should eq("2025-10-01T00:00:00Z")
    skill.updated_at.should eq("2025-10-01T00:00:00Z")
    skill.display_title.should eq("My Skill")
    skill.latest_version.should eq("v1")
    skill.source.should eq("upload")
  end
end

describe Anthropic::SkillListResponse do
  it "parses from JSON" do
    list = Anthropic::SkillListResponse.from_json(Fixtures::Responses::SKILL_LIST)

    list.data.size.should eq(2)
    list.has_more?.should be_false
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
    version.directory.should eq("/tools")
    version.name.should eq("my_tool")
    version.skill_id.should eq("skill_01abc")
    version.version.should eq("v1")
  end
end

describe Anthropic::SkillVersionListResponse do
  it "parses from JSON" do
    list = Anthropic::SkillVersionListResponse.from_json(Fixtures::Responses::SKILL_VERSION_LIST)

    list.data.size.should eq(1)
    list.has_more?.should be_false
    list.next_page.should be_nil
    list.data[0].version.should eq("v1")
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
      display_title: "My Skill"
    )

    skill.id.should eq("skill_01abc")
    skill.display_title.should eq("My Skill")
  end
end

describe Anthropic::BetaSkillVersions do
  it "lists versions" do
    capture = stub_and_capture(:get, "https://api.anthropic.com/v1/skills/skill_01abc/versions?beta=true&limit=20", Fixtures::Responses::SKILL_VERSION_LIST)

    client = Anthropic::Client.new(api_key: "sk-ant-test")
    result = client.beta.skills.versions.list(skill_id: "skill_01abc")

    result.data.size.should eq(1)
    result.data[0].version.should eq("v1")
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
    version.version.should eq("v1")
  end
end
