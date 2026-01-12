require "../src/anthropic"
require "dotenv"

# Files API example: Upload, manage, and use files with Claude
#
# The Files API allows you to upload documents and images to use across
# multiple conversations without re-uploading. Files are stored securely
# and persist until explicitly deleted.
#
# Key capabilities:
# - Upload files up to 500 MB
# - Supported formats: PDF, plain text, images (JPEG, PNG, GIF, WebP)
# - Reference files by ID in messages (no re-uploading needed)
# - Download files created by Claude (via code execution)
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/19_files_api.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Files API Example"
puts "=" * 60
puts

# Create a sample text file for upload
sample_content = <<-TEXT
# Sample Document

This is a sample document for testing the Files API.

## Section 1: Introduction
The Files API allows you to upload and manage files for use with Claude.

## Section 2: Features
- Upload files up to 500 MB
- Reference files across multiple conversations
- Supported formats: PDF, plain text, images

## Section 3: Conclusion
Using the Files API simplifies document management when working with Claude.
TEXT

sample_path = "/tmp/sample_document.txt"
File.write(sample_path, sample_content)
puts "Created sample file: #{sample_path}"
puts

# ============================================================================
# Upload a file
# ============================================================================
puts "1. Uploading file..."
puts "-" * 60

begin
  file = client.beta.files.upload(Path[sample_path])

  puts "File uploaded successfully!"
  puts "  ID: #{file.id}"
  puts "  Filename: #{file.filename}"
  puts "  MIME type: #{file.mime_type}"
  puts "  Size: #{file.size_bytes} bytes"
  puts "  Created: #{file.created_at}"
  puts "  Downloadable: #{file.downloadable?}"
  puts

  # ============================================================================
  # List files
  # ============================================================================
  puts "2. Listing files..."
  puts "-" * 60

  files = client.beta.files.list(limit: 5)
  puts "Found #{files.data.size} files (has_more: #{files.has_more?})"
  files.data.each do |file_info|
    puts "  - #{file_info.filename} (#{file_info.id})"
  end
  puts

  # ============================================================================
  # Retrieve file metadata
  # ============================================================================
  puts "3. Retrieving file metadata..."
  puts "-" * 60

  retrieved = client.beta.files.retrieve(file.id)
  puts "Retrieved: #{retrieved.filename}"
  puts "  Type: #{retrieved.type}"
  puts "  Size: #{retrieved.size_bytes} bytes"
  puts

  # ============================================================================
  # Use file in a message
  # ============================================================================
  puts "4. Using file in a message..."
  puts "-" * 60

  # Create a document reference using the file ID
  doc = Anthropic::DocumentContent.file(
    file.id,
    title: "Sample Document",
    citations: true
  )

  message = client.beta.messages.create(
    betas: [Anthropic::FILES_API_BETA],
    model: Anthropic::Model::CLAUDE_SONNET_4_5,
    max_tokens: 1024,
    messages: [
      Anthropic::MessageParam.new(
        role: Anthropic::Role::User,
        content: [
          doc,
          Anthropic::TextContent.new("Please summarize this document in 2-3 sentences."),
        ] of Anthropic::ContentBlock
      ),
    ]
  )

  puts "Response:"
  message.text_blocks.each { |block| puts block.text }
  puts

  # ============================================================================
  # Download file (only works for Claude-created files)
  # ============================================================================
  puts "5. Download check..."
  puts "-" * 60

  if file.downloadable?
    puts "File is downloadable. Downloading..."
    content = client.beta.files.download(file.id)
    puts "Downloaded #{content.size} bytes"
  else
    puts "File is not downloadable (uploaded files cannot be downloaded)."
    puts "Only files created by Claude (via code execution) can be downloaded."
  end
  puts

  # ============================================================================
  # Delete file
  # ============================================================================
  puts "6. Deleting file..."
  puts "-" * 60

  result = client.beta.files.delete(file.id)
  puts "Deleted: #{result.id} (type: #{result.type})"
  puts

  puts "=" * 60
  puts "Files API demo complete!"
rescue ex : Anthropic::APIError
  puts "API Error: #{ex.message}"
  puts "Status: #{ex.status}"
  puts "Body: #{ex.body}"
ensure
  # Clean up temp file
  File.delete(sample_path) if File.exists?(sample_path)
end
