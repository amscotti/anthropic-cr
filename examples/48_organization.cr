require "../src/anthropic-cr"
require "dotenv"

# Organization Admin API example (beta)
#
# Manage API keys, invites, users, workspaces, service accounts,
# federation, rate limits, and compliance settings via
# `client.beta.organization`.
#
# NOTE: these endpoints require an Admin API key or an organization-scoped
# key. A standard key gets an `Anthropic::AuthenticationError`, rescued
# below so the example still exits cleanly.
#
# Run with:
#   crystal run examples/48_organization.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new
org_api = client.beta.organization

begin
  org = org_api.retrieve
  puts "Organization: #{org.name} (#{org.id})"

  keys = org_api.api_keys.list(limit: 5)
  puts "\nAPI keys:"
  keys.data.each do |key|
    puts "  - #{key.name} (#{key.status})"
  end

  users = org_api.users.list(limit: 5)
  puts "\nUsers:"
  users.data.each do |user|
    puts "  - #{user.email} (#{user.role})"
  end

  limits = org_api.rate_limits.list(limit: 5)
  puts "\nRate limits: #{limits.data.size} shown"

  settings = org_api.compliance_settings.retrieve
  puts "Compliance settings type: #{settings.type}"
rescue ex : Anthropic::AuthenticationError
  puts "Admin API not available for this key: #{ex.message}"
end
