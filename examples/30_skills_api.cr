require "../src/anthropic-cr"
require "dotenv"

# Skills API Example
#
# The Skills API allows managing reusable skills that can be attached
# to containers for agentic workflows. Skills are uploaded as files
# and can have multiple versions.
#
# Each skill requires a SKILL.md file with YAML frontmatter (name,
# description) and can include additional scripts and resources.
#
# Note: The Skills API is in beta and requires the skills-2025-10-02 beta header.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/30_skills_api.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Skills API Example"
puts "=" * 60
puts

# Create a sample skill directory with required SKILL.md
skill_dir = "/tmp/greeting-skill"
Dir.mkdir_p(skill_dir)

skill_md = <<-MARKDOWN
---
name: greeting-skill
description: A simple greeting skill that generates personalized greetings.
---

# Greeting Skill

This skill generates personalized greetings for users.

## Usage

Call the `greet` function with a name to get a greeting.
MARKDOWN

greet_py = <<-PYTHON
def greet(name: str) -> str:
    """Greet a user by name."""
    return f"Hello, {name}! Welcome to the Skills API demo."
PYTHON

skill_md_path = File.join(skill_dir, "SKILL.md")
greet_py_path = File.join(skill_dir, "greet.py")
File.write(skill_md_path, skill_md)
File.write(greet_py_path, greet_py)
puts "Created sample skill files in #{skill_dir}"
puts

skill_id : String? = nil

begin
  # ============================================================================
  # 1. Create a skill
  # ============================================================================
  puts "1. Creating a skill..."
  puts "-" * 60

  # Using FileUpload struct for cleaner API
  skill_md_io = File.open(skill_md_path)
  greet_py_io = File.open(greet_py_path)

  # Add timestamp to avoid duplicate display_title errors
  timestamp = Time.utc.to_s("%Y%m%d%H%M%S")

  skill = client.beta.skills.create(
    files: [
      Anthropic::FileUpload.new(
        io: skill_md_io,
        filename: "greeting-skill/SKILL.md",
        content_type: "text/markdown"
      ),
      Anthropic::FileUpload.new(
        io: greet_py_io,
        filename: "greeting-skill/greet.py",
        content_type: "text/x-python"
      ),
    ],
    display_title: "Greeting Tool #{timestamp}"
  )

  skill_md_io.close
  greet_py_io.close

  skill_id = skill.id

  puts "Skill created!"
  puts "  ID: #{skill.id}"
  puts "  Type: #{skill.type}"
  puts "  Display title: #{skill.display_title}"
  puts "  Source: #{skill.source}"
  puts "  Latest version: #{skill.latest_version}"
  puts "  Created at: #{skill.created_at}"
  puts

  # ============================================================================
  # 2. List skills
  # ============================================================================
  puts "2. Listing skills..."
  puts "-" * 60

  skills_list = client.beta.skills.list(limit: 10)
  puts "Found #{skills_list.data.size} skill(s) (has_more: #{skills_list.has_more?})"
  skills_list.data.each do |item|
    puts "  - #{item.id}: #{item.display_title || "(untitled)"} (source: #{item.source})"
  end
  puts

  # ============================================================================
  # 3. Retrieve a skill
  # ============================================================================
  puts "3. Retrieving skill..."
  puts "-" * 60

  retrieved = client.beta.skills.retrieve(skill.id)
  puts "Retrieved: #{retrieved.id}"
  puts "  Display title: #{retrieved.display_title}"
  puts "  Latest version: #{retrieved.latest_version}"
  puts "  Updated at: #{retrieved.updated_at}"
  puts

  # ============================================================================
  # 4. List versions
  # ============================================================================
  puts "4. Listing skill versions..."
  puts "-" * 60

  versions_list = client.beta.skills.versions.list(skill_id: skill.id)
  puts "Found #{versions_list.data.size} version(s)"
  versions_list.data.each do |ver|
    puts "  - #{ver.id}: version=#{ver.version} (#{ver.created_at})"
  end
  puts

  # ============================================================================
  # 5. Retrieve a specific version
  # ============================================================================
  if first_version = versions_list.data.first?
    puts "5. Retrieving version #{first_version.version}..."
    puts "-" * 60

    retrieved_version = client.beta.skills.versions.retrieve(
      skill_id: skill.id,
      version: first_version.version
    )
    puts "Retrieved version: #{retrieved_version.version}"
    puts "  Name: #{retrieved_version.name}"
    puts "  Description: #{retrieved_version.description}"
    puts "  Directory: #{retrieved_version.directory}"
    puts
  end

  # ============================================================================
  # 6. Using a skill with ContainerConfig in messages
  # ============================================================================
  puts "6. Using skill with ContainerConfig..."
  puts "-" * 60

  container = Anthropic::ContainerConfig.new(
    skills: [Anthropic::ContainerSkill.new(skill_id: skill.id, type: "custom")]
  )
  puts "Container config: #{container.to_json}"
  puts
  puts "Usage with beta messages:"
  puts "  client.beta.messages.create("
  puts "    betas: [Anthropic::CODE_EXECUTION_BETA, Anthropic::SKILLS_BETA],"
  puts "    model: Anthropic::Model::CLAUDE_OPUS_4_6,"
  puts "    max_tokens: 4096,"
  puts "    container: container,"
  puts "    server_tools: [Anthropic::CodeExecutionTool.new],"
  puts "    messages: [...]"
  puts "  )"
  puts

  # ============================================================================
  # 7. Cleanup: delete versions then skill
  # ============================================================================
  puts "7. Cleaning up..."
  puts "-" * 60

  # Must delete all versions before deleting the skill
  versions_list = client.beta.skills.versions.list(skill_id: skill.id)
  versions_list.data.each do |ver|
    deleted_ver = client.beta.skills.versions.delete(skill_id: skill.id, version: ver.version)
    puts "  Deleted version: #{deleted_ver.id} (#{deleted_ver.type})"
  end

  deleted = client.beta.skills.delete(skill.id)
  puts "  Deleted skill: #{deleted.id} (#{deleted.type})"
  puts

  puts "=" * 60
  puts "Skills API demo complete!"
rescue ex : Anthropic::APIError
  puts "API Error: #{ex.message}"
  puts "Status: #{ex.status}"
  puts "Body: #{ex.body}"

  # Attempt cleanup on error
  if sid = skill_id
    puts "\nAttempting cleanup..."
    begin
      versions = client.beta.skills.versions.list(skill_id: sid)
      versions.data.each do |ver|
        client.beta.skills.versions.delete(skill_id: sid, version: ver.version)
      end
      client.beta.skills.delete(sid)
      puts "Cleanup successful."
    rescue
      puts "Cleanup failed — manual deletion may be needed for skill #{sid}"
    end
  end
ensure
  # Clean up temp files
  File.delete(skill_md_path) if File.exists?(skill_md_path)
  File.delete(greet_py_path) if File.exists?(greet_py_path)
  Dir.delete(skill_dir) if Dir.exists?(skill_dir)
end
