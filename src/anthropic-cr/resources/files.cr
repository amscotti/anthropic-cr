module Anthropic
  # Scope of a beta file: the context it was created in (e.g. a session).
  struct FileScope
    include JSON::Serializable

    # The ID of the scoping resource (e.g. the session ID).
    getter id : String

    # The type of scope (e.g. `"session"`).
    getter type : String
  end

  # File metadata returned by the Files API
  #
  # ```
  # file = client.beta.files.retrieve("file_abc123")
  # puts file.filename      # => "document.pdf"
  # puts file.size_bytes    # => 1024000
  # puts file.downloadable? # => false (uploaded files are not downloadable)
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
    getter downloadable : Bool?

    # RFC 3339 timestamp when the file expires, if it does
    @[JSON::Field(key: "expires_at")]
    getter expires_at : String?

    # The scope the file was created in (beta files only)
    @[JSON::Field(key: "scope", emit_null: false)]
    getter scope : FileScope?

    def initialize(
      @id : String,
      @type : String,
      @filename : String,
      @mime_type : String,
      @size_bytes : Int64,
      @created_at : String,
      @downloadable : Bool? = nil,
      @expires_at : String? = nil,
      @scope : FileScope? = nil,
    )
    end

    # Whether the file can be downloaded.
    def downloadable? : Bool
      !!@downloadable
    end
  end

  # Response from listing files
  struct FileListResponse
    include JSON::Serializable

    # Array of file metadata objects
    getter data : Array(FileMetadata)

    # Opaque cursor for the next page, if any
    @[JSON::Field(key: "next_page")]
    getter next_page : String?

    def initialize(
      @data : Array(FileMetadata),
      @next_page : String? = nil,
    )
    end

    # Fetch all files across all pages
    #
    # Pass the same filters the first page was listed with so follow-up
    # pages stay in scope; `beta` selects which resource paginates.
    #
    # ```
    # all_files = client.beta.files.list.auto_paging_all(client)
    # all_files = client.files.list(limit: 50).auto_paging_all(client, beta: false, limit: 50)
    # ```
    def auto_paging_all(
      client : Client,
      beta : Bool = true,
      ids : Array(String)? = nil,
      limit : Int32 = 20,
      scope_id : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : Array(FileMetadata)
      results = data.dup
      current_response = self

      while page = current_response.next_page
        current_response = if beta
                             BetaFiles.new(client).list(
                               ids: ids,
                               limit: limit,
                               page: page,
                               scope_id: scope_id,
                               betas: betas,
                               workspace_id: workspace_id
                             )
                           else
                             Files.new(client).list(
                               ids: ids,
                               limit: limit,
                               page: page,
                               workspace_id: workspace_id
                             )
                           end
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

  # Files API for uploading and managing files.
  #
  # Access via `client.files`.
  #
  # ```
  # # Upload a file
  # file = client.files.upload(Path["document.pdf"])
  #
  # # Use in a message
  # message = client.messages.create(
  #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
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
  # client.files.delete(file.id)
  # ```
  class Files
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
    # file = client.files.upload(Path["document.pdf"])
    #
    # # Upload from IO
    # file = client.files.upload(
    #   File.open("image.png"),
    #   filename: "my_image.png",
    #   content_type: "image/png"
    # )
    # ```
    def upload(
      file : Path,
      content_type : String? = nil,
      expires_in_seconds : Int32? = nil,
      workspace_id : String? = nil,
    ) : FileMetadata
      File.open(file) do |io|
        detected_type = content_type || FileUpload.content_type_for(File.extname(file.to_s))
        upload(
          io,
          filename: file.basename,
          content_type: detected_type,
          expires_in_seconds: expires_in_seconds,
          workspace_id: workspace_id
        )
      end
    end

    # :ditto:
    def upload(
      file : IO,
      filename : String = "file",
      content_type : String = "application/octet-stream",
      expires_in_seconds : Int32? = nil,
      workspace_id : String? = nil,
    ) : FileMetadata
      fields = nil
      if expires = expires_in_seconds
        fields = {"expires_in_seconds" => expires.to_s}
      end
      response = @client.post_multipart(
        "/v1/files",
        file,
        filename,
        content_type,
        Anthropic.merge_workspace_header(nil, workspace_id),
        fields
      )
      FileMetadata.from_json(response.body)
    end

    # List uploaded files
    #
    # ```
    # files = client.files.list(limit: 10)
    # files.data.each { |f| puts f.filename }
    #
    # # Pagination
    # if page = files.next_page
    #   more = client.files.list(page: page)
    # end
    #
    # # Get all files
    # all_files = files.auto_paging_all(client, beta: false)
    # ```
    def list(
      ids : Array(String)? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      workspace_id : String? = nil,
    ) : FileListResponse
      params = {} of String => String | Array(String)
      params["limit"] = limit.to_s
      params["ids"] = ids if ids
      params["page"] = page if page

      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/files", params, headers)
      FileListResponse.from_json(response.body)
    end

    # Get metadata for a specific file
    #
    # ```
    # file = client.files.retrieve_metadata("file_abc123")
    # puts file.filename
    # puts file.size_bytes
    # ```
    def retrieve_metadata(file_id : String, workspace_id : String? = nil) : FileMetadata
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.get("/v1/files/#{file_id}", nil, headers)
      FileMetadata.from_json(response.body)
    end

    # Alias for `retrieve_metadata`.
    def retrieve(file_id : String, workspace_id : String? = nil) : FileMetadata
      retrieve_metadata(file_id, workspace_id: workspace_id)
    end

    # Delete a file
    #
    # ```
    # result = client.files.delete("file_abc123")
    # puts result.id # => "file_abc123"
    # ```
    def delete(file_id : String, workspace_id : String? = nil) : DeletedFile
      headers = Anthropic.merge_workspace_header(nil, workspace_id)
      response = @client.delete("/v1/files/#{file_id}", headers)
      DeletedFile.from_json(response.body)
    end

    # Download file content
    #
    # Only files created by Claude (via code execution tool) can be downloaded.
    # Uploaded files cannot be downloaded - use the original file instead.
    #
    # ```
    # if file.downloadable
    #   content = client.files.download(file.id)
    #   File.write("output.txt", content.to_s)
    # end
    # ```
    def download(file_id : String, workspace_id : String? = nil) : IO::Memory
      headers = Anthropic.merge_workspace_header(nil, workspace_id) || {} of String => String
      headers["accept"] = "application/binary"
      @client.get_raw("/v1/files/#{file_id}/content", headers)
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
  #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
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
      expires_in_seconds : Int32? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : FileMetadata
      File.open(file) do |io|
        detected_type = content_type || FileUpload.content_type_for(File.extname(file.to_s))
        upload(
          io,
          filename: file.basename,
          content_type: detected_type,
          expires_in_seconds: expires_in_seconds,
          betas: betas,
          workspace_id: workspace_id
        )
      end
    end

    # :ditto:
    def upload(
      file : IO,
      filename : String = "file",
      content_type : String = "application/octet-stream",
      expires_in_seconds : Int32? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : FileMetadata
      fields = nil
      if expires = expires_in_seconds
        fields = {"expires_in_seconds" => expires.to_s}
      end
      response = @client.post_multipart(
        "/v1/files?beta=true",
        file,
        filename,
        content_type,
        beta_headers(betas, workspace_id),
        fields
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
    # if page = files.next_page
    #   more = client.beta.files.list(page: page)
    # end
    #
    # # Get all files
    # all_files = files.auto_paging_all(client)
    # ```
    def list(
      ids : Array(String)? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      scope_id : String? = nil,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : FileListResponse
      params = {} of String => String | Array(String)
      params["limit"] = limit.to_s
      params["ids"] = ids if ids
      params["page"] = page if page
      params["scope_id"] = scope_id if scope_id

      response = @client.get("/v1/files?beta=true", params, beta_headers(betas, workspace_id))
      FileListResponse.from_json(response.body)
    end

    # Get metadata for a specific file
    #
    # ```
    # file = client.beta.files.retrieve_metadata("file_abc123")
    # puts file.filename
    # puts file.size_bytes
    # ```
    def retrieve_metadata(
      file_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : FileMetadata
      response = @client.get("/v1/files/#{file_id}?beta=true", nil, beta_headers(betas, workspace_id))
      FileMetadata.from_json(response.body)
    end

    # Alias for `retrieve_metadata`.
    def retrieve(
      file_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : FileMetadata
      retrieve_metadata(file_id, betas: betas, workspace_id: workspace_id)
    end

    # Delete a file
    #
    # ```
    # result = client.beta.files.delete("file_abc123")
    # puts result.id # => "file_abc123"
    # ```
    def delete(
      file_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : DeletedFile
      response = @client.delete("/v1/files/#{file_id}?beta=true", beta_headers(betas, workspace_id))
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
    def download(
      file_id : String,
      betas : Array(String) = [] of String,
      workspace_id : String? = nil,
    ) : IO::Memory
      headers = beta_headers(betas, workspace_id)
      headers["accept"] = "application/binary"
      @client.get_raw("/v1/files/#{file_id}/content?beta=true", headers)
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
