require "../src/anthropic-cr"
require "dotenv"

# User Profiles API example (beta)
#
# User profiles scope per-end-user state (memory, trust grants, etc.) to a
# specific user of your application. Once you have a profile id you can
# pass it via `user_profile_id:` on beta `messages.create` calls so that
# per-user features attach to the right end user.
#
# Requires the beta header `user-profiles-2026-03-24`, which the SDK adds
# automatically when you call `client.beta.user_profiles` or pass
# `user_profile_id:` to a beta message call.
#
# Run with:
#   crystal run examples/36_user_profiles.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "User Profiles"
puts "=" * 60
puts

# NOTE: The User Profiles API is rolling out progressively. Accounts that
# haven't been enabled yet receive a 404. We catch that case and report it
# cleanly so the example stays runnable everywhere.
begin
  # --- 1. Create a profile ---
  puts "1. Create a user profile"
  puts "-" * 60
  puts

  profile = client.beta.user_profiles.create(
    external_id: "user-#{Random.new.hex(4)}",
    metadata: {"plan" => "pro", "beta_cohort" => "opus-4-7"}
  )

  puts "Created: #{profile.id}"
  puts "External ID: #{profile.external_id}"
  puts "Metadata: #{profile.metadata}"
  puts

  # --- 2. Generate an enrollment URL ---
  puts "2. Enrollment URL"
  puts "-" * 60
  puts

  enrollment = client.beta.user_profiles.create_enrollment_url(profile.id)
  puts "Send this URL to the end user:"
  puts enrollment.url
  puts "(Expires at: #{enrollment.expires_at})"
  puts

  # --- 3. Send a message scoped to the profile ---
  puts "3. Message scoped to the profile"
  puts "-" * 60
  puts

  message = client.beta.messages.create(
    model: Anthropic::Model::CLAUDE_OPUS_4_7,
    max_tokens: 512,
    user_profile_id: profile.id,
    messages: [
      {role: "user", content: "Say hi to our newly-enrolled user."},
    ]
  )

  puts message.text
  puts

  # --- 4. Retrieve, then delete is not yet GA — list instead ---
  puts "4. List profiles"
  puts "-" * 60
  puts

  listing = client.beta.user_profiles.list(limit: 5)
  listing.data.each { |entry| puts "- #{entry.id} (external_id=#{entry.external_id})" }
rescue ex : Anthropic::NotFoundError
  puts "User Profiles API is not yet enabled on this account (HTTP 404)."
  puts "Error: #{ex.message}"
rescue ex : Anthropic::BadRequestError
  puts "User Profiles API rejected the request: #{ex.message}"
end

puts
puts "=" * 60
puts "Done!"
