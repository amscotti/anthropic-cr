require "../src/anthropic-cr"
require "dotenv"

# Auto-pagination example: Iterate through all pages automatically
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/10_pagination.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Example 1: Manual pagination through batches"
puts "=" * 60
puts

page = 1
batch_list = client.messages.batches.list(limit: 2)

loop do
  puts "Page #{page}:"
  batch_list.data.each do |batch|
    puts "  - #{batch.id} (#{batch.processing_status})"
  end

  break unless batch_list.has_more?

  # Get next page
  last_id = batch_list.last_id
  break unless last_id

  batch_list = client.messages.batches.list(limit: 2, after_id: last_id)
  page += 1
  puts
end

puts
puts "=" * 60
puts

# Auto-pagination (easier!)
puts "Example 2: Auto-pagination (simplified)"
puts "=" * 60
puts

all_batches = client.messages.batches.list(limit: 2).auto_paging_all(client)
all_batches.each_with_index do |batch, index|
  puts "#{index + 1}. #{batch.id} - #{batch.processing_status}"
end

puts
puts "Total batches found: #{all_batches.size}"
puts
puts "=" * 60
puts

# Models auto-pagination
puts "Example 3: Auto-paginating through all models"
puts "=" * 60
puts

all_models = client.models.list.auto_paging_all(client)
all_models.each_with_index do |model, index|
  puts "#{index + 1}. #{model.display_name} (#{model.id})"
end

puts
puts "Total models: #{all_models.size}"
