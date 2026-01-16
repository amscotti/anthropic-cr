require "../src/anthropic-cr"
require "dotenv"

# Error handling example: Demonstrates the SDK's error handling
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/06_error_handling.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

# Example 1: Handle rate limiting gracefully
puts "Example 1: Handling different error types"
puts "-" * 50

begin
  # This will work normally
  message = client.messages.create(
    model: Anthropic::Model::CLAUDE_HAIKU_4_5,
    max_tokens: 50,
    messages: [{role: "user", content: "Hi!"}]
  )
  text = message.text_blocks.first?.try(&.text) || ""
  puts "Success: #{text[0..50]}..."
rescue ex : Anthropic::RateLimitError
  puts "Rate limited! Retry after #{ex.retry_after} seconds"
rescue ex : Anthropic::AuthenticationError
  puts "Authentication failed: #{ex.message}"
rescue ex : Anthropic::BadRequestError
  puts "Bad request: #{ex.message}"
rescue ex : Anthropic::APIError
  puts "API error (#{ex.status}): #{ex.message}"
end

puts
puts "-" * 50
puts

# Example 2: Invalid request triggers BadRequestError
puts "Example 2: Triggering a BadRequestError (invalid max_tokens)"
puts "-" * 50

begin
  # This will fail because max_tokens is 0
  message = client.messages.create(
    model: Anthropic::Model::CLAUDE_SONNET_4_5,
    max_tokens: 0, # Invalid!
    messages: [{role: "user", content: "Hello"}]
  )
rescue ex : Anthropic::BadRequestError
  puts "Caught BadRequestError as expected:"
  puts "  Message: #{ex.message}"
  puts "  Status: #{ex.status}"
end

puts
puts "-" * 50
puts

# Example 3: Connection errors
puts "Example 3: Automatic retries on server errors"
puts "-" * 50
puts "The SDK automatically retries on:"
puts "  - 408 (Request Timeout)"
puts "  - 409 (Conflict)"
puts "  - 429 (Rate Limit)"
puts "  - 500+ (Server Errors)"
puts
puts "Exponential backoff with jitter is applied between retries."
puts "Default max_retries: 2"
puts
puts "You can configure retries when creating the client:"
puts "  client = Anthropic::Client.new(max_retries: 5)"
