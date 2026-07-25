require "../src/anthropic-cr"
require "dotenv"

# Dreams API Example (beta / research preview)
#
# Dreams are asynchronous memory-consolidation jobs: they read a memory store
# plus session transcripts and write consolidated memories into a new output
# memory store. The input store is never modified.
#
# Access:
#   Research preview — request access via Claude Managed Agents:
#   https://claude.com/form/claude-managed-agents
#   Without access, list/create return 404 NotFoundError.
#
# Headers (auto-attached by the SDK):
#   managed-agents-2026-04-01,dreaming-2026-04-21
#
# Requires:
#   ANTHROPIC_API_KEY
# Optional:
#   DREAM_MEMORY_STORE_ID  — existing memory store to read from
#   DREAM_SESSION_IDS      — comma-separated session ids (e.g. sesn_1,sesn_2)
#   DREAM_MODEL            — model id (default claude-opus-4-8; see docs for
#                            supported preview models)
#   DREAM_INSTRUCTIONS     — optional synthesis guidance
#   ARCHIVE_DREAM=1        — archive the created dream after retrieve
#   CANCEL_DREAM=1         — cancel instead of archiving (if still pending)
#
# Docs: https://platform.claude.com/docs/en/managed-agents/dreams
#
# Run with:
#   crystal run examples/43_dreams.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Dreams API Example (research preview)"
puts "=" * 60
puts "Betas (auto): #{Anthropic::MANAGED_AGENTS_BETA},#{Anthropic::DREAMING_BETA}"
puts "Docs: https://platform.claude.com/docs/en/managed-agents/dreams"
puts "Access form: https://claude.com/form/claude-managed-agents"
puts

memory_store_id = ENV["DREAM_MEMORY_STORE_ID"]?
session_ids = ENV["DREAM_SESSION_IDS"]?.try(&.split(',').map(&.strip).reject(&.empty?))
model = ENV["DREAM_MODEL"]? || "claude-opus-4-8"

# 1. List existing dreams
puts "1. Listing dreams:"
puts "-" * 60
begin
  listed = client.beta.dreams.list(limit: 5)
  puts "Found #{listed.data.size} dream(s) on this page."
  listed.data.each do |dream|
    puts " - #{dream.id} status=#{dream.status} created_at=#{dream.created_at}"
  end
  puts "next_page=#{listed.next_page.inspect}" if listed.next_page
rescue ex : Anthropic::NotFoundError
  puts "List failed: #{ex.message} (HTTP #{ex.status})"
  puts
  puts "  Dreams is a gated research preview. If you see 404, your workspace"
  puts "  likely does not have access yet — request it at the form above."
  puts "  Paths and headers match the official API; this is not an SDK bug."
rescue ex : Anthropic::APIError
  puts "List failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
end
puts

# 2. Create a dream (needs inputs)
unless memory_store_id
  puts "2. Skipping create: set DREAM_MEMORY_STORE_ID to create a dream."
  puts "   Optionally set DREAM_SESSION_IDS=sesn_1,sesn_2"
  puts "   (If you only have sessions, create an empty memory store first.)"
  exit 0
end

inputs = [] of Anthropic::BetaDreamInput
inputs << Anthropic::BetaDreamMemoryStoreInput.new(memory_store_id)
if session_ids && !session_ids.empty?
  inputs << Anthropic::BetaDreamSessionsInput.new(session_ids)
end

puts "2. Creating dream:"
puts "-" * 60
puts "  memory_store: #{memory_store_id}"
puts "  sessions:     #{session_ids.inspect}"
puts "  model:        #{model}"

begin
  dream = client.beta.dreams.create(
    inputs: inputs,
    model: model,
    instructions: ENV["DREAM_INSTRUCTIONS"]? || "Consolidate lasting project facts and preferences.",
  )
  puts "Created dream #{dream.id} status=#{dream.status}"
  puts "  outputs: #{dream.outputs.map(&.memory_store_id)}"
  puts

  # 3. Retrieve
  puts "3. Retrieving dream:"
  puts "-" * 60
  dream = client.beta.dreams.retrieve(dream.id)
  puts "  id=#{dream.id} status=#{dream.status} usage.input=#{dream.usage.input_tokens}"
  if err = dream.error
    puts "  error: #{err.type}: #{err.message}"
  end
  puts

  # 4. Optional cancel / archive (destructive; opt-in)
  if ENV["CANCEL_DREAM"]? == "1"
    puts "4. Canceling dream (CANCEL_DREAM=1):"
    dream = client.beta.dreams.cancel(dream.id)
    puts "  status=#{dream.status}"
  elsif ENV["ARCHIVE_DREAM"]? == "1"
    puts "4. Archiving dream (ARCHIVE_DREAM=1):"
    dream = client.beta.dreams.archive(dream.id)
    puts "  archived_at=#{dream.archived_at}"
  else
    puts "4. Skipping cancel/archive (set CANCEL_DREAM=1 or ARCHIVE_DREAM=1 to opt in)."
  end
rescue ex : Anthropic::APIError
  puts "Create/retrieve failed: #{ex.class.name}: #{ex.message} (HTTP #{ex.status})"
  puts "  Check access, memory_store_id, and session ids."
end

puts
puts "Done."
