require "../src/anthropic-cr"
require "dotenv"

# MCP Tunnels API Example (beta / research preview)
#
# Tunnels allocate a hostname for routing MCP traffic through Anthropic so
# Claude (Managed Agents or Messages MCP connector) can reach private MCP
# servers without inbound firewall holes.
#
# IMPORTANT — Auth for tunnel *management* (this example):
#   All /v1/tunnels management endpoints require a bearer token with the
#   `workspace:manage_tunnels` scope from Workload Identity Federation (WIF).
#   Standard ANTHROPIC_API_KEY / admin API keys are NOT accepted and return 401.
#   See: https://platform.claude.com/docs/en/agents-and-tools/mcp-tunnels/reference
#
#   Using a tunnel URL from Messages (`mcp_servers`) is separate and uses a
#   normal workspace API key + the MCP client beta — that is not this example.
#
# Access:
#   Research preview — https://claude.com/form/claude-managed-agents
#
# Optional env (after WIF is configured on the Client):
#   TUNNEL_DISPLAY_NAME     — display name for create (default crystal-sdk-demo)
#   TUNNEL_CA_CERT_PEM      — PEM string (or path via TUNNEL_CA_CERT_FILE)
#   TUNNEL_CA_CERT_FILE     — path to PEM file for certificate create
#   REVEAL_TOKEN=1          — reveal connector token (sensitive)
#   ROTATE_TOKEN=1          — rotate connector token (disruptive)
#   ARCHIVE_TUNNEL=1        — archive tunnel (irreversible)
#   ARCHIVE_CERTIFICATE=1   — archive a certificate after create
#
# Docs:
#   https://platform.claude.com/docs/en/agents-and-tools/mcp-tunnels/overview
#
# Run with:
#   crystal run examples/44_tunnels.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "MCP Tunnels API Example (research preview)"
puts "=" * 60
puts "Beta (auto): #{Anthropic::MCP_TUNNELS_BETA}"
puts "Docs: https://platform.claude.com/docs/en/agents-and-tools/mcp-tunnels/overview"
puts "Access form: https://claude.com/form/claude-managed-agents"
puts
puts "Auth note: management calls need WIF + workspace:manage_tunnels."
puts "           Plain API keys return 401 Authentication failed."
puts

# 1. List tunnels
puts "1. Listing tunnels:"
puts "-" * 60
begin
  listed = client.beta.tunnels.list(limit: 5)
  puts "Found #{listed.data.size} tunnel(s) on this page."
  listed.data.each do |tunnel|
    status = tunnel.archived? ? "archived" : "active"
    puts " - #{tunnel.id} domain=#{tunnel.domain} name=#{tunnel.display_name.inspect} (#{status})"
  end
rescue ex : Anthropic::AuthenticationError
  puts "List failed: #{ex.message} (HTTP #{ex.status})"
  puts
  puts "  Expected with a standard API key. Configure Workload Identity"
  puts "  Federation with scope workspace:manage_tunnels, then re-run with"
  puts "  a Client that uses that bearer token."
  puts "  See: https://platform.claude.com/docs/en/manage-claude/workload-identity-federation"
  puts
  puts "Skipping create/retrieve/token steps (same auth requirement)."
  exit 0
rescue ex : Anthropic::APIError
  puts "List failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  puts "Skipping further management calls."
  exit 1
end
puts

# 2. Create tunnel
display_name = ENV["TUNNEL_DISPLAY_NAME"]? || "crystal-sdk-demo"
puts "2. Creating tunnel display_name=#{display_name.inspect}:"
puts "-" * 60
tunnel = begin
  created = client.beta.tunnels.create(display_name: display_name)
  puts "Created #{created.id}"
  puts "  domain=#{created.domain}"
  puts "  created_at=#{created.created_at}"
  created
rescue ex : Anthropic::APIError
  puts "Create failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  exit 1
end
puts

# 3. Retrieve
puts "3. Retrieving tunnel:"
puts "-" * 60
begin
  tunnel = client.beta.tunnels.retrieve(tunnel.id)
  puts "  id=#{tunnel.id} domain=#{tunnel.domain}"
rescue ex : Anthropic::APIError
  puts "Retrieve failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  exit 1
end
puts

# 4. Optional certificate registration
pem = ENV["TUNNEL_CA_CERT_PEM"]?
if pem.nil? && (path = ENV["TUNNEL_CA_CERT_FILE"]?)
  pem = File.read(path)
end

if pem
  puts "4. Registering CA certificate:"
  puts "-" * 60
  begin
    cert = client.beta.tunnels.certificates.create(tunnel.id, ca_certificate_pem: pem)
    puts "  cert id=#{cert.id} fingerprint=#{cert.fingerprint}"
    puts "  expires_at=#{cert.expires_at.inspect}"

    certs = client.beta.tunnels.certificates.list(tunnel.id)
    puts "  certificates on tunnel: #{certs.data.size}"

    if ENV["ARCHIVE_CERTIFICATE"]? == "1"
      archived = client.beta.tunnels.certificates.archive(tunnel.id, cert.id)
      puts "  archived cert at #{archived.archived_at}"
    end
  rescue ex : Anthropic::APIError
    puts "Certificate ops failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  end
else
  puts "4. Skipping certificate create (set TUNNEL_CA_CERT_PEM or TUNNEL_CA_CERT_FILE)."
  puts "   A tunnel rejects MCP traffic until at least one CA is registered."
end
puts

# 5. Token ops (opt-in; sensitive / disruptive)
if ENV["REVEAL_TOKEN"]? == "1"
  puts "5. Revealing connector token (REVEAL_TOKEN=1):"
  puts "-" * 60
  begin
    token = client.beta.tunnels.reveal_token(tunnel.id)
    puts "  token id=#{token.id}"
    puts "  tunnel_token=#{token.tunnel_token[0..7]}… (truncated; full value not printed by default)"
  rescue ex : Anthropic::APIError
    puts "Reveal failed: #{ex.class.name}: #{ex.message}"
  end
else
  puts "5. Skipping reveal_token (set REVEAL_TOKEN=1 to opt in)."
end
puts

if ENV["ROTATE_TOKEN"]? == "1"
  puts "6. Rotating connector token (ROTATE_TOKEN=1):"
  puts "-" * 60
  begin
    token = client.beta.tunnels.rotate_token(tunnel.id, reason: "crystal sdk example")
    puts "  new token id=#{token.id}"
  rescue ex : Anthropic::APIError
    puts "Rotate failed: #{ex.class.name}: #{ex.message}"
  end
else
  puts "6. Skipping rotate_token (set ROTATE_TOKEN=1 to opt in)."
end
puts

# 7. Archive tunnel (irreversible; opt-in)
if ENV["ARCHIVE_TUNNEL"]? == "1"
  puts "7. Archiving tunnel (ARCHIVE_TUNNEL=1) — irreversible:"
  puts "-" * 60
  begin
    tunnel = client.beta.tunnels.archive(tunnel.id)
    puts "  archived_at=#{tunnel.archived_at}"
  rescue ex : Anthropic::APIError
    puts "Archive failed: #{ex.class.name}: #{ex.message}"
  end
else
  puts "7. Skipping archive (set ARCHIVE_TUNNEL=1 to opt in)."
  puts "   Tunnel left active: #{tunnel.id}"
end

puts
puts "Done."
