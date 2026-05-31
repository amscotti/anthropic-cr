require "../src/anthropic-cr"
require "dotenv"

# Stateful Managed Agents API Example
#
# Demonstrates using the stateful Managed Agents APIs (beta) to manage environments,
# memory stores, agent configurations, secure credentials vaults, and webhooks.
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
  puts "Webhook successfully verified. Payload is untampered."
  puts "   Payload Event ID: #{verified_payload.id}"
  puts "   Event Type:       #{verified_payload.type}"
rescue ex : Exception
  puts "Webhook verification failed: #{ex.message}."
end
puts

# 2. Environments and Memory Stores
puts "2. Listing Environments and Memory Stores:"
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
  puts "Error details: #{ex.message}."
rescue ex : Exception
  puts "System Error: #{ex.message}."
end
puts

# 3. Agents Management
puts "3. Managing Agent Definitions:"
puts "-" * 60

begin
  # Check current agents
  puts "Listing active agents..."
  agents_list = client.beta.agents.list(limit: 5)
  puts "Found #{agents_list.data.size} agents."
  agents_list.data.each do |agent|
    puts " - ID: #{agent.id}, Name: #{agent.name}, Model: #{agent.model["id"]? || agent.model}"
  end

  # Showcase how to create an agent configuration (wrapped in a conditional/dry run logic)
  puts
  puts "Example workflow for creating a new agent definition:"
  puts "  client.beta.agents.create("
  puts "    model: :sonnet,"
  puts "    name: \"Development Assistant\","
  puts "    description: \"Agent configured to assist with programming tasks.\""
  puts "  )"
rescue ex : Anthropic::APIError
  puts "Note: Managing agents requires appropriate beta permissions."
  puts "Error details: #{ex.message}."
rescue ex : Exception
  puts "System Error: #{ex.message}."
end
puts

# 4. Secure Credentials Vaults
puts "4. Managing Secure Vaults & Credentials:"
puts "-" * 60

begin
  # Check current vaults
  puts "Listing secure vaults..."
  vaults_list = client.beta.vaults.list(limit: 5)
  puts "Found #{vaults_list.data.size} vaults."
  vaults_list.data.each do |vault|
    puts " - ID: #{vault.id}, Name: #{vault.display_name}"
  end

  # Showcase credential management
  puts
  puts "Example workflow for registering credentials inside a vault:"
  puts "  client.beta.vaults.credentials.create("
  puts "    vault_id: \"vault_123\","
  puts "    name: \"GitHub Token\","
  puts "    type: \"secret\","
  puts "    secret: \"github_pat_...\""
  puts "  )"
rescue ex : Anthropic::APIError
  puts "Note: Vault operations require authorized credentials access."
  puts "Error details: #{ex.message}."
rescue ex : Exception
  puts "System Error: #{ex.message}."
end

# 5. Full End-to-End Integration Test (Create, List, Talk, and Archive/Delete)
puts "5. Full End-to-End Integration Test:"
puts "-" * 60

created_env_id = nil
created_agent_id = nil
created_session_id = nil

begin
  puts "Creating a temporary testing environment..."
  packages = Anthropic::BetaPackages.new(apt: ["curl"])
  net_config = Anthropic::BetaUnrestrictedNetwork.new
  config = Anthropic::BetaCloudConfig.new(net_config, packages)

  env = client.beta.environments.create(
    name: "temp-integration-env",
    config: config,
    description: "Temporary environment for integration test.",
    scope: "organization"
  )
  created_env_id = env.id
  puts "Environment created: #{env.id}"

  puts "Creating an agent definition..."
  agent = client.beta.agents.create(
    model: :sonnet,
    name: "Integration Test Agent",
    description: "Temporary agent for integration testing.",
    system: "You are a helpful assistant."
  )
  created_agent_id = agent.id
  puts "Agent created: #{agent.id}"

  puts "Listing active agent definitions..."
  agents = client.beta.agents.list(limit: 10)
  found = agents.data.any? { |agt| agt.id == agent.id }
  puts "   Agent #{agent.id} in list: #{found ? "Yes" : "No"}"

  puts "Starting a stateful session to talk to the agent..."
  session = client.beta.sessions.create(
    environment_id: env.id,
    agent: agent.id
  )
  created_session_id = session.id
  puts "Session created: #{session.id}"

  puts "Retrieving stateful session events to check agent execution status..."
  events_data = client.beta.sessions.events.list(session_id: session.id, limit: 5)
  puts "Retrieved session events count: #{events_data["data"]?.try(&.as_a.size) || 0}"
  puts "End-to-end integration test completed successfully."
rescue ex : Anthropic::APIError
  puts "Note: Full end-to-end integration test skipped."
  puts "      This requires authorized Managed Agents beta billing/access permissions on your Anthropic account."
  puts "      Error details: #{ex.message}."
rescue ex : Exception
  puts "System Error: #{ex.message}."
ensure
  if created_env_id || created_agent_id || created_session_id
    puts "Cleaning up resources..."
    if sid = created_session_id
      client.beta.sessions.delete(session_id: sid)
      puts "Session cleaned up"
    end
    if aid = created_agent_id
      client.beta.agents.archive(aid)
      puts "Agent cleaned up"
    end
    if eid = created_env_id
      client.beta.environments.delete(eid)
      puts "Environment cleaned up"
    end
  end
end

puts
puts "=" * 60
puts "Managed Agents API example completed."
