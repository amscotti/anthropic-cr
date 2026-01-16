require "../src/anthropic-cr"
require "dotenv"

# Models API example: List and retrieve model information
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/07_list_models.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Listing all available Claude models:"
puts "=" * 60
puts

response = client.models.list

response.each do |model|
  puts "#{model.display_name}"
  puts "  ID: #{model.id}"
  puts "  Type: #{model.type}"
  puts "  Created: #{model.created_at}" if model.created_at
  puts
end

puts "=" * 60
puts "Total models: #{response.data.size}"
puts "Has more pages: #{response.has_more?}"
puts

# Retrieve specific model
puts "\nRetrieving specific model information:"
puts "-" * 60

model = client.models.retrieve(Anthropic::Model::CLAUDE_SONNET_4_5)
puts "Model: #{model.display_name}"
puts "ID: #{model.id}"
puts "Type: #{model.type}"
puts "Created: #{model.created_at}"
