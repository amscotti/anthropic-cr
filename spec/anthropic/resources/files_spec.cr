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
  end

  describe Anthropic::FileListResponse do
    it "parses file list response" do
      list = Anthropic::FileListResponse.from_json(Fixtures::Responses::FILE_LIST)

      list.data.size.should eq(2)
      list.has_more?.should be_false
      list.first_id.should eq("file_01abc123")
      list.last_id.should eq("file_02xyz456")
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

    it "handles pagination with has_more" do
      json = %({"data":[{"id":"file_01","type":"file","filename":"test.pdf","mime_type":"application/pdf","size_bytes":100,"created_at":"2025-01-01T00:00:00Z","downloadable":false}],"has_more":true,"first_id":"file_01","last_id":"file_01"})
      list = Anthropic::FileListResponse.from_json(json)

      list.has_more?.should be_true
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

describe Anthropic::BetaFiles do
  describe "#list" do
    it "makes correct request to list files" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=20")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list

      files.data.size.should eq(2)
    end

    it "passes limit parameter" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=5")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list(limit: 5)

      files.should be_a(Anthropic::FileListResponse)
    end

    it "passes pagination parameters" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=10&after_id=file_abc")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_LIST)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      files = client.beta.files.list(limit: 10, after_id: "file_abc")

      files.should be_a(Anthropic::FileListResponse)
    end
  end

  describe "#retrieve" do
    it "makes correct request to retrieve file metadata" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01abc123")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: Fixtures::Responses::FILE_METADATA)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      file = client.beta.files.retrieve("file_01abc123")

      file.id.should eq("file_01abc123")
      file.filename.should eq("document.pdf")
    end
  end

  describe "#delete" do
    it "makes correct request to delete file" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_01abc123")
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
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01abc123/content")
        .with(headers: {"anthropic-beta" => "files-api-2025-04-14"})
        .to_return(body: "Hello, this is file content!")

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      content = client.beta.files.download("file_01abc123")

      content.should be_a(IO::Memory)
      content.to_s.should eq("Hello, this is file content!")
    end
  end
end
