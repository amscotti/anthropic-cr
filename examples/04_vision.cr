require "../src/anthropic-cr"
require "dotenv"
require "base64"

# Vision example: Send an image to Claude for analysis
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/04_vision.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# Example: Using a base64-encoded image (1x1 red pixel)
puts "Analyzing a base64 image..."
puts

# Create a tiny 1x1 red PNG
red_pixel_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_HAIKU_4_5,
  max_tokens: 200,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        Anthropic::TextContent.new("What color is this pixel?"),
        Anthropic::ImageContent.base64("image/png", red_pixel_base64),
      ] of Anthropic::ContentBlock
    ),
  ]
)

puts "Response:"
puts "-" * 50
message.text_blocks.each { |block| puts block.text }
puts "-" * 50
puts
puts "Note: URL-based images can be used with ImageContent.url(\"https://...\") but require"
puts "publicly accessible URLs that Claude can download."
