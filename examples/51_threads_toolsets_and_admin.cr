require "../src/anthropic-cr"
require "dotenv"

# v0.12.0 Parity Highlights (2026-10-21)
#
# Showcases:
#   1. New 5.5 / 5.2 models and ModelInfo lifecycle filtering
#   2. BetaMessageThread (`client.beta.messages.thread`) with fork & tool_runner
#   3. BrowserToolset20260801 / ComputerToolset20260801 and BrowserStateContent
#   4. GA User Profiles (`client.user_profiles` + `action_urls.create`)
#   5. GA Organization Admin (`client.organization`) and beta extensions
#
# Run with:
#   crystal run examples/51_threads_toolsets_and_admin.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "1. Claude 5.5 / 5.2 Models & Lifecycle Filtering"
puts "-" * 60
puts "  Sonnet 5.5: #{Anthropic::Model::CLAUDE_SONNET_5_5} (#{Anthropic.model_name(:sonnet_5_5)})"
puts "  Haiku 5.5:  #{Anthropic::Model::CLAUDE_HAIKU_5_5} (#{Anthropic.model_name(:haiku_5_5)})"
puts "  Fable 5.2:  #{Anthropic::Model::CLAUDE_FABLE_5_2} (#{Anthropic.model_name(:fable_5_2)})"
puts "  Mythos 5.2: #{Anthropic::Model::CLAUDE_MYTHOS_5_2} (#{Anthropic.model_name(:mythos_5_2)})"

begin
  active_models = client.models.list(lifecycle: [Anthropic::ModelLifecycle::ACTIVE], limit: 5)
  active_models.data.each do |model|
    puts "  - #{model.id} (lifecycle=#{model.lifecycle}, line=#{model.line || "n/a"})"
  end
rescue ex : Anthropic::APIError
  puts "  Skipped live models.list: #{ex.message}"
end
puts

puts "2. Beta Message Threads (message-threads-2026-08-12)"
puts "-" * 60

begin
  thread = client.beta.messages.thread(
    model: Anthropic::Model::CLAUDE_SONNET_5_5,
    max_tokens: 256,
    system: "Keep replies concise.",
    thinking: Anthropic::ThinkingConfig.between_tools,
  )

  reply = thread.send(Anthropic::MessageParam.user("Remember the secret code: CRYSTAL-012."))
  puts "  Turn 1 (#{thread.previous_message_id}): #{reply.text}"

  branch = thread.fork
  followup = branch.send(Anthropic::MessageParam.user("What was the secret code?"))
  puts "  Forked Turn 2 (#{branch.previous_message_id}): #{followup.text}"
rescue ex : Anthropic::APIError
  puts "  Skipped live thread demo: #{ex.message}"
end
puts

puts "3. Browser & Computer Toolsets (20260801)"
puts "-" * 60

browser_toolset = Anthropic::BrowserToolset20260801.new(
  configs: Anthropic::BrowserToolsetConfigs.new(
    navigate: Anthropic::ToolsetMemberConfig.new(enabled: true),
    javascript_exec: Anthropic::ToolsetMemberConfig.new(enabled: false),
  )
)
computer_toolset = Anthropic::ComputerToolset20260801.new(
  configs: Anthropic::ComputerToolsetConfigs.new(
    screenshot: Anthropic::ToolsetMemberConfig.new(enabled: true),
  )
)

puts "  Configured #{browser_toolset.type} and #{computer_toolset.type}"

sample_state = Anthropic::BrowserStateContent.new(
  tabs: [
    Anthropic::BrowserStateTabEntry.new(
      tab_id: "tab_1",
      title: "Crystal Lang",
      url: "https://crystal-lang.org",
      active: true,
    ),
  ],
  state_changes: [
    Anthropic::BrowserStateChangeTabOpened.new(tab_id: "tab_1").as(Anthropic::BrowserStateChange),
  ],
)
puts "  Sample BrowserStateContent JSON: #{sample_state.to_json}"

begin
  toolset_msg = client.beta.messages.create(
    model: Anthropic::Model::CLAUDE_SONNET_5_5,
    max_tokens: 256,
    server_tools: [browser_toolset] of Anthropic::ServerTool,
    messages: [{role: "user", content: "Open https://crystal-lang.org"}],
  )
  toolset_msg.tool_use_blocks.each do |tool_use|
    if parsed = Anthropic::BrowserToolUse.parse?(tool_use)
      puts "  Parsed browser action: #{parsed.class.name} (toolset=#{tool_use.toolset_name})"
    end
  end
rescue ex : Anthropic::APIError
  puts "  Skipped live toolset call: #{ex.message}"
end
puts

puts "4. GA User Profiles (client.user_profiles)"
puts "-" * 60

begin
  profile = client.user_profiles.create(
    access_type: Anthropic::UserProfileAccessType::PASSTHROUGH,
    name: "Demo End User",
    external_user_details: Anthropic::UserProfileExternalUserDetails.new(
      reference_id: "demo-#{Random.new.hex(4)}",
    ),
  )
  puts "  Created profile #{profile.id} (status=#{profile.enforcement_status})"

  action_url = client.user_profiles.action_urls.create(
    profile.id,
    action: Anthropic::UserProfileEnrollEndUserAction.new,
  )
  puts "  Action URL: #{action_url.url}"

  deleted = client.user_profiles.delete(profile.id)
  puts "  Deleted: #{deleted.id} (#{deleted.type})"
rescue ex : Anthropic::APIError
  puts "  Skipped live user_profiles call: #{ex.message}"
end
puts

puts "5. GA Organization Admin & Beta Extensions"
puts "-" * 60

begin
  org = client.organization.retrieve
  puts "  Organization: #{org.name} (#{org.id})"

  groups = client.organization.rbac_groups.list(limit: 5)
  puts "  RBAC groups: #{groups.data.size}"

  effective = client.organization.spend_limits.effective.list(limit: 5)
  puts "  Effective spend limit summaries: #{effective.data.size}"

  summaries = client.organization.analytics.summaries.list(starting_date: "2026-10-01", limit: 3)
  puts "  Analytics summaries: #{summaries.data.size}"

  plugins = client.beta.organization.plugins.list(limit: 5)
  puts "  Beta plugins: #{plugins.data.size}"

  destinations = client.beta.organization.telemetry_destinations.list(limit: 5)
  puts "  Beta telemetry destinations: #{destinations.data.size}"

  webhooks = client.beta.organization.webhooks.list(limit: 5)
  puts "  Beta org webhooks: #{webhooks.data.size}"

  bundles = client.beta.organization.claude_tag.bundles.list(limit: 5)
  puts "  Beta Claude Tag bundles: #{bundles.data.size}"
rescue ex : Anthropic::APIError
  puts "  Skipped live organization call (requires admin key): #{ex.message}"
end
