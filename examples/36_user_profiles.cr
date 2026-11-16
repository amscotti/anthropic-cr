require "../src/anthropic-cr"
require "dotenv"

# User Profiles API example (GA `client.user_profiles` + beta `client.beta.user_profiles`)
#
# User profiles scope per-end-user state (memory, trust grants, etc.) to a
# specific user of your application. As of v0.12.0 (`2026-10-21`), core User
# Profiles management and `action_urls` are GA via `client.user_profiles`, while
# `client.beta.user_profiles` (`user-profiles-2026-08-18` / `2026-09-04`)
# preserves legacy `external_id` and `create_enrollment_url` helpers.
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
    metadata: {"plan" => "pro", "beta_cohort" => "opus-4-8"}
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
    model: Anthropic::Model::CLAUDE_OPUS_4_8,
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
