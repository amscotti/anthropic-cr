require "../src/anthropic-cr"
require "dotenv"

# HTTP Middleware example.
#
# Middleware lets you inspect, rewrite, or short-circuit requests and responses
# around the SDK's terminal HTTP send. The chain runs once per attempt inside
# the retry loop. This example wires up a logging middleware and a header
# injection middleware, both of which run against the live API.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/40_middleware.cr

Dotenv.load if File.exists?(".env")

# A middleware that logs every request/response as it flows through the chain.
class LoggingMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    puts "[middleware] -> #{request.method} #{request.path}"
    response = nxt.call(request)
    puts "[middleware] <- HTTP #{response.status} (#{response.body.size} bytes)"
    response
  end
end

# A middleware that injects a custom request header on every call.
class AddHeaderMiddleware
  include Anthropic::Middleware

  def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
    new_headers = request.headers.dup
    new_headers["x-demo-request-source"] = "anthropic-cr-example"
    nxt.call(request.with(headers: new_headers))
  end
end

client = Anthropic::Client.new(middleware: [
  LoggingMiddleware.new,
  AddHeaderMiddleware.new,
])

puts "HTTP Middleware"
puts "=" * 60
puts

puts "1. A request through the middleware chain (live)"
puts "-" * 60
puts

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_5,
  max_tokens: 64,
  messages: [{role: "user", content: "Reply with the single word: ok"}],
)

puts
puts "Model used: #{message.model}"
puts "Response: #{message.text}"
puts
puts "=" * 60
puts "Done!"
