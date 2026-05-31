require "../src/anthropic-cr"
require "dotenv"

# Stateful Managed Agents API Example
#
# Demonstrates using the stateful Managed Agents APIs (beta) to manage environments,
# sessions, and memory stores, as well as verifying secure webhook signatures.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file.
#
# Run with:
#   crystal run examples/34_managed_agents.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Stateful Managed Agents Example"
puts "=" * 60
puts

# 1. Secure Webhook Signature Verification
# Managed Agents send webhooks on events. You must verify their signatures.
puts "1. Demonstrating Webhook Signature Verification:"
puts "-" * 60

webhook_secret = "whsec_54321/abcde12345=="
payload_body = %({"id":"evt_123","created_at":"2026-05-24T12:00:00Z","type":"event","data":{"id":"sess_123","organization_id":"org_123","type":"session.created","workspace_id":"ws_123"}})
timestamp = Time.utc.to_unix.to_s
msg_id = "msg_id_999"

# Compute the secure HMAC signature block using standard webhook specifications:
# id.timestamp.body
key_clean = webhook_secret[6..-1]
key_bytes = Base64.decode(key_clean)
message_to_sign = "#{msg_id}.#{timestamp}.#{payload_body}"
hmac = Base64.strict_encode(OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key_bytes, message_to_sign))
signature_header = "v1,#{hmac}"

begin
  # Use the secure signature verification helper in beta.webhooks.unwrap
  verified_payload = client.beta.webhooks.unwrap(
    payload: payload_body,
    headers: {
      "webhook-id"          => msg_id,
      "webhook-timestamp"   => timestamp,
      "X-Webhook-Signature" => signature_header,
    },
    key: webhook_secret
  )
  puts "✅ Webhook successfully verified! Payload is untampered."
  puts "   Payload Event ID: #{verified_payload.id}"
  puts "   Event Type:       #{verified_payload.type}"
rescue ex : Exception
  puts "❌ Webhook verification failed: #{ex.message}"
end
puts

# 2. Environments and Sessions CRUD operations (Defensive/Standard execution)
puts "2. Managing Environments and Sessions:"
puts "-" * 60

begin
  # Check current environments
  puts "Listing existing environments..."
  environments_list = client.beta.environments.list(limit: 5)
  puts "Found #{environments_list.data.size} environments."
  environments_list.data.each do |env|
    puts " - ID: #{env.id}, Name: #{env.name}, Status: #{env.archived_at ? "Archived" : "Active"}"
  end

  # Check memory stores
  puts
  puts "Listing memory stores..."
  memory_stores = client.beta.memory_stores.list(limit: 5)
  puts "Found #{memory_stores.data.size} memory stores."
  memory_stores.data.each do |store|
    puts " - ID: #{store.id}, Name: #{store.name}"
  end
rescue ex : Anthropic::APIError
  puts "Note: Managed Agents API requires authorized account permissions."
  puts "Error details: #{ex.message}"
rescue ex : Exception
  puts "System Error: #{ex.message}"
end

puts
puts "=" * 60
puts "Managed Agents API example completed."
