require "../../spec_helper"

describe "Files API Types" do
  describe Anthropic::FileMetadata do
    it "parses file metadata" do
      metadata = Anthropic::FileMetadata.from_json(Fixtures::Responses::FILE_METADATA)

      metadata.id.should eq("file_01abc123")
      metadata.type.should eq("file")
      metadata.filename.should eq("document.pdf")
      metadata.mime_type.should eq("application/pdf")
      metadata.size_bytes.should eq(1_024_000_i64)
      metadata.created_at.should eq("2025-01-01T00:00:00Z")
      metadata.downloadable?.should be_false
    end

    it "handles downloadable files" do
      json = %({"id":"file_created_by_claude","type":"file","filename":"output.txt","mime_type":"text/plain","size_bytes":500,"created_at":"2025-01-01T00:00:00Z","downloadable":true})
      metadata = Anthropic::FileMetadata.from_json(json)

      metadata.downloadable?.should be_true
    end

    it "tolerates missing download and expiry fields" do
      json = %({"id":"file_01","type":"file","filename":"a.pdf","mime_type":"application/pdf","size_bytes":100,"created_at":"2025-01-01T00:00:00Z"})
      metadata = Anthropic::FileMetadata.from_json(json)

      metadata.downloadable.should be_nil
      metadata.downloadable?.should be_false
      metadata.expires_at.should be_nil
    end

    it "parses expiry timestamps" do
      json = %({"id":"file_01","type":"file","filename":"a.pdf","mime_type":"application/pdf","size_bytes":100,"created_at":"2025-01-01T00:00:00Z","expires_at":"2025-01-02T00:00:00Z"})
      metadata = Anthropic::FileMetadata.from_json(json)

      metadata.expires_at.should eq("2025-01-02T00:00:00Z")
    end

    it "parses beta scopes" do
      json = %({"id":"file_01","type":"file","filename":"a.pdf","mime_type":"application/pdf","size_bytes":100,"created_at":"2025-01-01T00:00:00Z","scope":{"id":"sess_123","type":"session"}})
      metadata = Anthropic::FileMetadata.from_json(json)

      metadata.scope.not_nil!.id.should eq("sess_123")
      metadata.scope.not_nil!.type.should eq("session")
    end
  end

  describe Anthropic::FileListResponse do
    it "parses file list response" do
      list = Anthropic::FileListResponse.from_json(Fixtures::Responses::FILE_LIST)

      list.data.size.should eq(2)
      list.next_page.should be_nil
    end

    it "parses first file in list" do
      list = Anthropic::FileListResponse.from_json(Fixtures::Responses::FILE_LIST)

      list.data[0].id.should eq("file_01abc123")
      list.data[0].filename.should eq("document.pdf")
      list.data[0].mime_type.should eq("application/pdf")
    end

    it "parses second file in list" do
      list = Anthropic::FileListResponse.from_json(Fixtures::Responses::FILE_LIST)

      list.data[1].id.should eq("file_02xyz456")
      list.data[1].filename.should eq("image.png")
      list.data[1].mime_type.should eq("image/png")
    end

    it "parses the next-page cursor" do
      json = %({"data":[{"id":"file_01","type":"file","filename":"test.pdf","mime_type":"application/pdf","size_bytes":100,"created_at":"2025-01-01T00:00:00Z","downloadable":false}],"next_page":"cursor_9"})
      list = Anthropic::FileListResponse.from_json(json)

      list.next_page.should eq("cursor_9")
    end
  end

  describe Anthropic::DeletedFile do
    it "parses deleted file response" do
      deleted = Anthropic::DeletedFile.from_json(Fixtures::Responses::FILE_DELETED)

      deleted.id.should eq("file_01abc123")
      deleted.type.should eq("file_deleted")
    end
  end
end

describe Anthropic::Files do
  describe "#list" do
    it "makes correct request to list files" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files?limit=20", Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.files.list

      files.data.size.should eq(2)
      capture.headers.not_nil!.has_key?("anthropic-beta").should be_false
    end

    it "passes ids, page, and workspace parameters" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files?limit=20&ids=file_a&ids=file_b&page=cursor_1", Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.files.list(ids: ["file_a", "file_b"], page: "cursor_1", workspace_id: "wrkspc_1")

      capture.path.not_nil!.should contain("ids=file_a&ids=file_b")
      capture.path.not_nil!.should contain("page=cursor_1")
      capture.headers.not_nil!["anthropic-workspace-id"].should eq("wrkspc_1")
    end
  end

  describe "#retrieve_metadata" do
    it "makes correct request to retrieve file metadata" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files/file_01abc123", Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = client.files.retrieve_metadata("file_01abc123", workspace_id: "wrkspc_1")

      file.id.should eq("file_01abc123")
      file.filename.should eq("document.pdf")
      capture.headers.not_nil!["anthropic-workspace-id"].should eq("wrkspc_1")
    end

    it "keeps retrieve as an alias" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01abc123")
        .to_return(body: Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.files.retrieve("file_01abc123").id.should eq("file_01abc123")
    end
  end

  describe "#delete" do
    it "makes correct request to delete file" do
      capture = stub_and_capture(:delete, "https://api.anthropic.com/v1/files/file_01abc123", Fixtures::Responses::FILE_DELETED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.files.delete("file_01abc123", workspace_id: "wrkspc_1")

      result.id.should eq("file_01abc123")
      result.type.should eq("file_deleted")
      capture.headers.not_nil!["anthropic-workspace-id"].should eq("wrkspc_1")
    end
  end

  describe "#download" do
    it "makes correct request to download file content" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files/file_01abc123/content", "Hello, this is file content!")

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      content = client.files.download("file_01abc123")

      content.should be_a(IO::Memory)
      content.to_s.should eq("Hello, this is file content!")
      capture.headers.not_nil!["accept"].should eq("application/binary")
    end
  end

  describe "#upload" do
    it "sends expiry as a multipart field" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/files", Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = client.files.upload(
        IO::Memory.new("data"),
        filename: "a.txt",
        content_type: "text/plain",
        expires_in_seconds: 3600
      )

      file.id.should eq("file_01abc123")
      capture.body.not_nil!.should contain("expires_in_seconds")
      capture.body.not_nil!.should contain("3600")
    end
  end
end

describe Anthropic::BetaFiles do
  describe "#list" do
    it "makes correct request to list files" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?beta=true&limit=20")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list

      files.data.size.should eq(2)
    end

    it "passes limit parameter" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?beta=true&limit=5")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list(limit: 5)

      files.should be_a(Anthropic::FileListResponse)
    end

    it "passes pagination parameters" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?beta=true&limit=10&page=cursor_9")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list(limit: 10, page: "cursor_9")

      files.should be_a(Anthropic::FileListResponse)
    end

    it "passes ids, page, scope, betas, and workspace parameters" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files?beta=true&limit=20&ids=file_a&page=cursor_1&scope_id=scope_1", Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.files.list(
        ids: ["file_a"],
        page: "cursor_1",
        scope_id: "scope_1",
        betas: ["custom-beta"],
        workspace_id: "wrkspc_1"
      )

      capture.path.not_nil!.should contain("beta=true")
      capture.path.not_nil!.should contain("ids=file_a")
      capture.path.not_nil!.should contain("scope_id=scope_1")
      headers = capture.headers.not_nil!
      headers["anthropic-beta"].should contain("custom-beta")
      headers["anthropic-beta"].should contain("files-api-2025-04-14")
      headers["anthropic-workspace-id"].should eq("wrkspc_1")
    end
  end

  describe "#retrieve_metadata" do
    it "makes correct request to retrieve file metadata" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01abc123?beta=true")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = client.beta.files.retrieve_metadata("file_01abc123")

      file.id.should eq("file_01abc123")
      file.filename.should eq("document.pdf")
    end

    it "keeps retrieve as an alias" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01abc123?beta=true")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.beta.files.retrieve("file_01abc123").id.should eq("file_01abc123")
    end
  end

  describe "#delete" do
    it "makes correct request to delete file" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_01abc123?beta=true")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_DELETED)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      result = client.beta.files.delete("file_01abc123")

      result.id.should eq("file_01abc123")
      result.type.should eq("file_deleted")
    end
  end

  describe "#download" do
    it "makes correct request to download file content" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/files/file_01abc123/content?beta=true", "Hello, this is file content!")

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      content = client.beta.files.download("file_01abc123")

      content.should be_a(IO::Memory)
      content.to_s.should eq("Hello, this is file content!")
      headers = capture.headers.not_nil!
      headers["accept"].should eq("application/binary")
      headers["anthropic-beta"].should contain("files-api-2025-04-14")
    end
  end

  describe "#upload" do
    it "posts to the beta endpoint with expiry" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/files?beta=true", Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = client.beta.files.upload(
        IO::Memory.new("data"),
        filename: "a.txt",
        expires_in_seconds: 60
      )

      file.id.should eq("file_01abc123")
      capture.body.not_nil!.should contain("expires_in_seconds")
      capture.headers.not_nil!["anthropic-beta"].should contain("files-api-2025-04-14")
    end
  end
end
