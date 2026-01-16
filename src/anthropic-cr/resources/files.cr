module Anthropic
  # File metadata returned by the Files API
  #
  # ```
  # file = client.beta.files.retrieve("file_abc123")
  # puts file.filename     # => "document.pdf"
  # puts file.size_bytes   # => 1024000
  # puts file.downloadable # => false (uploaded files are not downloadable)
  # ```
  struct FileMetadata
    include JSON::Serializable

    # Unique identifier for this file
    getter id : String

    # Object type, always "file"
    getter type : String

    # Original filename
    getter filename : String

    # MIME type of the file
    @[JSON::Field(key: "mime_type")]
    getter mime_type : String

    # File size in bytes
    @[JSON::Field(key: "size_bytes")]
    getter size_bytes : Int64

    # ISO 8601 timestamp when file was created
    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Whether the file can be downloaded
    # Only files created by Claude (via code execution) are downloadable
    getter? downloadable : Bool

    def initialize(
      @id : String,
      @type : String,
      @filename : String,
      @mime_type : String,
      @size_bytes : Int64,
      @created_at : String,
      @downloadable : Bool,
    )
    end
  end

  # Response from listing files
  struct FileListResponse
    include JSON::Serializable

    # Array of file metadata objects
    getter data : Array(FileMetadata)

    # Whether there are more files to fetch
    @[JSON::Field(key: "has_more")]
    getter? has_more : Bool

    # ID of first file (for backward pagination)
    @[JSON::Field(key: "first_id")]
    getter first_id : String?

    # ID of last file (for forward pagination)
    @[JSON::Field(key: "last_id")]
    getter last_id : String?

    def initialize(
      @data : Array(FileMetadata),
      @has_more : Bool = false,
      @first_id : String? = nil,
      @last_id : String? = nil,
    )
    end

    # Fetch all files across all pages
    #
    # ```
    # all_files = client.beta.files.list.auto_paging_all(client)
    # ```
    def auto_paging_all(client : Client) : Array(FileMetadata)
      results = data.dup
      current_response = self

      while current_response.has_more? && (last = current_response.last_id)
        current_response = BetaFiles.new(client).list(after_id: last)
        results.concat(current_response.data)
      end

      results
    end
  end

  # Response from deleting a file
  struct DeletedFile
    include JSON::Serializable

    # ID of the deleted file
    getter id : String

    # Object type, always "file_deleted"
    getter type : String

    def initialize(@id : String, @type : String = "file_deleted")
    end
  end

  # Files API for uploading and managing files (Beta)
  #
  # All methods require the beta header `files-api-2025-04-14`.
  # Access via `client.beta.files`.
  #
  # ```
  # # Upload a file
  # file = client.beta.files.upload(File.open("document.pdf"))
  #
  # # Use in a message
  # message = client.beta.messages.create(
  #   betas: [Anthropic::FILES_API_BETA],
  #   model: Anthropic::Model::CLAUDE_SONNET_4_5,
  #   max_tokens: 1024,
  #   messages: [{
  #     role:    "user",
  #     content: [
  #       {type: "text", text: "Summarize this document"},
  #       {type: "document", source: {type: "file", file_id: file.id}},
  #     ],
  #   }]
  # )
  #
  # # Clean up
  # client.beta.files.delete(file.id)
  # ```
  class BetaFiles
    BETA_HEADER = "files-api-2025-04-14"

    def initialize(@client : Client)
    end

    # Upload a file
    #
    # Supported file types:
    # - PDFs: application/pdf
    # - Plain text: text/plain
    # - Images: image/jpeg, image/png, image/gif, image/webp
    #
    # Files can be up to 500 MB in size.
    #
    # ```
    # # Upload from file path
    # file = client.beta.files.upload(Path["document.pdf"])
    #
    # # Upload from IO
    # file = client.beta.files.upload(
    #   File.open("image.png"),
    #   filename: "my_image.png",
    #   content_type: "image/png"
    # )
    # ```
    def upload(
      file : Path,
      content_type : String? = nil,
    ) : FileMetadata
      File.open(file) do |io|
        detected_type = content_type || detect_content_type(file.to_s)
        upload(io, filename: file.basename, content_type: detected_type)
      end
    end

    # :ditto:
    def upload(
      file : IO,
      filename : String = "file",
      content_type : String = "application/octet-stream",
    ) : FileMetadata
      response = @client.post_multipart(
        "/v1/files",
        file,
        filename,
        content_type,
        beta_headers
      )
      FileMetadata.from_json(response.body)
    end

    # List uploaded files
    #
    # ```
    # files = client.beta.files.list(limit: 10)
    # files.data.each { |f| puts f.filename }
    #
    # # Pagination
    # if files.has_more?
    #   more = client.beta.files.list(after_id: files.last_id)
    # end
    #
    # # Get all files
    # all_files = files.auto_paging_all(client)
    # ```
    def list(
      limit : Int32 = 20,
      before_id : String? = nil,
      after_id : String? = nil,
    ) : FileListResponse
      params = {"limit" => limit.to_s}
      params["before_id"] = before_id if before_id
      params["after_id"] = after_id if after_id

      response = @client.get("/v1/files", params, beta_headers)
      FileListResponse.from_json(response.body)
    end

    # Get metadata for a specific file
    #
    # ```
    # file = client.beta.files.retrieve("file_abc123")
    # puts file.filename
    # puts file.size_bytes
    # ```
    def retrieve(file_id : String) : FileMetadata
      response = @client.get("/v1/files/#{file_id}", nil, beta_headers)
      FileMetadata.from_json(response.body)
    end

    # Delete a file
    #
    # ```
    # result = client.beta.files.delete("file_abc123")
    # puts result.id # => "file_abc123"
    # ```
    def delete(file_id : String) : DeletedFile
      response = @client.delete("/v1/files/#{file_id}", beta_headers)
      DeletedFile.from_json(response.body)
    end

    # Download file content
    #
    # Only files created by Claude (via code execution tool) can be downloaded.
    # Uploaded files cannot be downloaded - use the original file instead.
    #
    # ```
    # if file.downloadable
    #   content = client.beta.files.download(file.id)
    #   File.write("output.txt", content.to_s)
    # end
    # ```
    def download(file_id : String) : IO::Memory
      @client.get_raw("/v1/files/#{file_id}/content", beta_headers)
    end

    private def beta_headers : Hash(String, String)
      {"anthropic-beta" => BETA_HEADER}
    end

    private def detect_content_type(filename : String) : String
      case File.extname(filename).downcase
      when ".pdf"          then "application/pdf"
      when ".txt"          then "text/plain"
      when ".json"         then "application/json"
      when ".csv"          then "text/csv"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png"          then "image/png"
      when ".gif"          then "image/gif"
      when ".webp"         then "image/webp"
      else                      "application/octet-stream"
      end
    end
  end
end
