require "../src/anthropic-cr"
require "dotenv"

# Advisor tool example
#
# The advisor tool delegates questions to a secondary model at runtime. It's
# useful for routing specialized sub-questions (security review, math, etc.)
# to a dedicated model without switching the primary conversation over.
#
# Requires the beta header `advisor-tool-2026-03-01`, which this SDK adds
# automatically when `AdvisorTool` is included in `server_tools`.
#
# Run with:
#   crystal run examples/35_advisor_tool.cr

Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Advisor Tool (advisor_20260301)"
puts "=" * 60
puts

# Not every model can be used as an advisor. Opus 4.5 is a known-supported
# advisor model at launch; adjust as needed for your account.
advisor = Anthropic::AdvisorTool.new(
  model: Anthropic::Model::CLAUDE_OPUS_4_5,
  max_uses: 3,
  strict: true,
)

begin
  message = client.beta.messages.create(
    model: Anthropic::Model::CLAUDE_OPUS_4_7,
    max_tokens: 2048,
    server_tools: [advisor] of Anthropic::ServerTool,
    messages: [
      {role: "user", content: "Before writing my API response, please consult the advisor about whether this payload should be rate-limited: {\"endpoint\":\"/login\",\"attempts\":500}"},
    ]
  )

  message.content.each do |block|
    case block
    when Anthropic::TextContent
      puts "Model: #{block.text}"
    when Anthropic::ServerToolUseContent
      puts "  -> calling #{block.name}(#{block.input.to_json})"
    when Anthropic::AdvisorToolResultContent
      case inner = block.content
      when Anthropic::AdvisorResultContent
        puts "  <- advisor text: #{inner.text}"
      when Anthropic::AdvisorRedactedResultContent
        puts "  <- advisor encrypted payload (#{inner.encrypted_content.bytesize} bytes)"
      when Anthropic::AdvisorToolResultErrorContent
        puts "  <- advisor error: #{inner.error_code}"
      end
    end
  end
rescue ex : Anthropic::BadRequestError
  # Surface the server's error (e.g., advisor-model compatibility) rather
  # than crashing so the example stays runnable on varied account configs.
  puts "Advisor tool request rejected: #{ex.message}"
end

puts
puts "=" * 60
puts "Done!"
