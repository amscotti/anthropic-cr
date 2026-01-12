require "../src/anthropic"
require "dotenv"

# Batches API example: Process multiple messages in a single batch
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/08_batches.cr
#
# Note: Batches can take up to 24 hours to complete. This example shows
# how to create a batch and check its status.

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Creating a message batch with multiple requests..."
puts "=" * 60
puts

# Create batch requests
requests = [
  Anthropic::BatchRequest.new(
    custom_id: "request-1",
    params: Anthropic::BatchRequestParams.new(
      model: Anthropic::Model::CLAUDE_HAIKU_4_5,
      max_tokens: 100,
      messages: [Anthropic::MessageParam.user("What is 2+2?")]
    )
  ),
  Anthropic::BatchRequest.new(
    custom_id: "request-2",
    params: Anthropic::BatchRequestParams.new(
      model: Anthropic::Model::CLAUDE_HAIKU_4_5,
      max_tokens: 100,
      messages: [Anthropic::MessageParam.user("What is the capital of France?")]
    )
  ),
  Anthropic::BatchRequest.new(
    custom_id: "request-3",
    params: Anthropic::BatchRequestParams.new(
      model: Anthropic::Model::CLAUDE_HAIKU_4_5,
      max_tokens: 100,
      messages: [Anthropic::MessageParam.user("Name a primary color.")]
    )
  ),
]

# Create the batch
batch = client.messages.batches.create(requests: requests)

puts "Batch created successfully!"
puts "  Batch ID: #{batch.id}"
puts "  Status: #{batch.processing_status}"
puts "  Created: #{batch.created_at}"
puts "  Expires: #{batch.expires_at}"
puts

puts "Request counts:"
puts "  Processing: #{batch.request_counts.processing}"
puts "  Succeeded: #{batch.request_counts.succeeded}"
puts "  Errored: #{batch.request_counts.errored}"
puts

puts "-" * 60
puts

# Retrieve batch status
puts "Retrieving batch status..."
retrieved = client.messages.batches.retrieve(batch.id)
puts "  Status: #{retrieved.processing_status}"
puts "  Processing: #{retrieved.request_counts.processing}"
puts "  Succeeded: #{retrieved.request_counts.succeeded}"
puts

# List all batches
puts "Listing all recent batches:"
puts "-" * 60

list = client.messages.batches.list(limit: 5)
list.data.each do |batch_item|
  puts "Batch: #{batch_item.id}"
  puts "  Status: #{batch_item.processing_status}"
  puts "  Succeeded: #{batch_item.request_counts.succeeded}/#{batch_item.request_counts.processing + batch_item.request_counts.succeeded + batch_item.request_counts.errored}"
  puts
end

puts "=" * 60
puts
puts "Note: Batches are processed asynchronously and may take time to complete."
puts "Check the batch status periodically with retrieve() to see when it's done."
puts
puts "When status is 'ended', you can stream results with:"
puts "  client.messages.batches.results(batch_id) { |result| ... }"
puts
puts "You can also cancel or delete batches:"
puts "  client.messages.batches.cancel(batch_id)"
puts "  client.messages.batches.delete(batch_id)"
