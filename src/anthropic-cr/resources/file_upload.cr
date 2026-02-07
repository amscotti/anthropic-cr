module Anthropic
  # Represents a file to be uploaded to the Skills API
  #
  # ```
  # file = Anthropic::FileUpload.new(
  #   io: File.open("tool.py"),
  #   filename: "tool.py",
  #   content_type: "text/x-python"
  # )
  #
  # skill = client.beta.skills.create(
  #   files: [file],
  #   display_title: "My Skill"
  # )
  # ```
  struct FileUpload
    getter io : IO
    getter filename : String
    getter content_type : String

    def initialize(@io : IO, @filename : String, @content_type : String)
    end

    # Create from a file path with auto-detected content type
    #
    # Content type is inferred from the file extension. You can override
    # it explicitly, or provide a custom filename for the upload.
    #
    # ```
    # # Auto-detect content type from extension
    # file = Anthropic::FileUpload.from_path("src/tool.py")
    #
    # # Override filename (e.g. for skill directory structure)
    # file = Anthropic::FileUpload.from_path(
    #   "src/tool.py",
    #   filename: "skill-name/tool.py"
    # )
    #
    # # Override content type explicitly
    # file = Anthropic::FileUpload.from_path(
    #   "data/config",
    #   content_type: "application/json"
    # )
    # ```
    def self.from_path(path : String, content_type : String? = nil, filename : String? = nil) : self
      actual_filename = filename || File.basename(path)
      actual_content_type = content_type || content_type_for(File.extname(path))
      io = IO::Memory.new
      File.open(path) { |file| IO.copy(file, io) }
      io.rewind
      new(io, actual_filename, actual_content_type)
    end

    # Infer content type from a file extension
    def self.content_type_for(extension : String) : String
      case extension.downcase
      when ".py"           then "text/x-python"
      when ".js", ".mjs"   then "text/javascript"
      when ".ts"           then "text/typescript"
      when ".rb"           then "text/x-ruby"
      when ".cr"           then "text/x-crystal"
      when ".md"           then "text/markdown"
      when ".txt"          then "text/plain"
      when ".json"         then "application/json"
      when ".yaml", ".yml" then "text/yaml"
      when ".html", ".htm" then "text/html"
      when ".css"          then "text/css"
      when ".xml"          then "application/xml"
      when ".sh"           then "text/x-shellscript"
      else                      "application/octet-stream"
      end
    end
  end
end
