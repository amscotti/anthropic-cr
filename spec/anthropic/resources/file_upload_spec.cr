require "../../spec_helper"

describe Anthropic::FileUpload do
  describe ".content_type_for" do
    it "detects Python" do
      Anthropic::FileUpload.content_type_for(".py").should eq("text/x-python")
    end

    it "detects JavaScript" do
      Anthropic::FileUpload.content_type_for(".js").should eq("text/javascript")
      Anthropic::FileUpload.content_type_for(".mjs").should eq("text/javascript")
    end

    it "detects TypeScript" do
      Anthropic::FileUpload.content_type_for(".ts").should eq("text/typescript")
    end

    it "detects Ruby" do
      Anthropic::FileUpload.content_type_for(".rb").should eq("text/x-ruby")
    end

    it "detects Crystal" do
      Anthropic::FileUpload.content_type_for(".cr").should eq("text/x-crystal")
    end

    it "detects Markdown" do
      Anthropic::FileUpload.content_type_for(".md").should eq("text/markdown")
    end

    it "detects JSON" do
      Anthropic::FileUpload.content_type_for(".json").should eq("application/json")
    end

    it "detects YAML" do
      Anthropic::FileUpload.content_type_for(".yaml").should eq("text/yaml")
      Anthropic::FileUpload.content_type_for(".yml").should eq("text/yaml")
    end

    it "detects HTML" do
      Anthropic::FileUpload.content_type_for(".html").should eq("text/html")
      Anthropic::FileUpload.content_type_for(".htm").should eq("text/html")
    end

    it "detects shell scripts" do
      Anthropic::FileUpload.content_type_for(".sh").should eq("text/x-shellscript")
    end

    it "is case-insensitive" do
      Anthropic::FileUpload.content_type_for(".PY").should eq("text/x-python")
      Anthropic::FileUpload.content_type_for(".JSON").should eq("application/json")
    end

    it "falls back to octet-stream for unknown extensions" do
      Anthropic::FileUpload.content_type_for(".xyz").should eq("application/octet-stream")
      Anthropic::FileUpload.content_type_for("").should eq("application/octet-stream")
    end
  end

  describe ".from_path" do
    it "auto-detects content type from file extension" do
      path = File.tempname("test", ".py")
      File.write(path, "print('hello')")

      begin
        upload = Anthropic::FileUpload.from_path(path)
        upload.content_type.should eq("text/x-python")
        upload.filename.should eq(File.basename(path))
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "allows overriding content type" do
      path = File.tempname("test", ".txt")
      File.write(path, "{}")

      begin
        upload = Anthropic::FileUpload.from_path(path, content_type: "application/json")
        upload.content_type.should eq("application/json")
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "allows overriding filename" do
      path = File.tempname("test", ".md")
      File.write(path, "# Hello")

      begin
        upload = Anthropic::FileUpload.from_path(path, filename: "skill-name/SKILL.md")
        upload.filename.should eq("skill-name/SKILL.md")
        upload.content_type.should eq("text/markdown")
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end
end
