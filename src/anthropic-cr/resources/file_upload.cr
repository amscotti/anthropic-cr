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
  #   display_name: "My Skill"
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

    # Extension to content-type mapping for uploads.
    CONTENT_TYPES = {
      ".py"   => "text/x-python",
      ".js"   => "text/javascript",
      ".mjs"  => "text/javascript",
      ".ts"   => "text/typescript",
      ".rb"   => "text/x-ruby",
      ".cr"   => "text/x-crystal",
      ".md"   => "text/markdown",
      ".txt"  => "text/plain",
      ".json" => "application/json",
      ".yaml" => "text/yaml",
      ".yml"  => "text/yaml",
      ".html" => "text/html",
      ".htm"  => "text/html",
      ".css"  => "text/css",
      ".xml"  => "application/xml",
      ".sh"   => "text/x-shellscript",
      ".pdf"  => "application/pdf",
      ".csv"  => "text/csv",
      ".jpg"  => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png"  => "image/png",
      ".gif"  => "image/gif",
      ".webp" => "image/webp",
    }

    # Infer content type from a file extension
    def self.content_type_for(extension : String) : String
      CONTENT_TYPES[extension.downcase]? || "application/octet-stream"
    end
  end
end
