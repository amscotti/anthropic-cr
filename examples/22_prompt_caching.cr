require "../src/anthropic-cr"
require "dotenv"

# Prompt Caching Example
#
# Prompt caching reduces costs by up to 90% and latency by up to 85%
# for prompts with large amounts of repeated content.
#
# Cache Types:
# - Ephemeral (5-minute): 1.25x write cost, 0.1x read cost
# - Extended (1-hour): 2x write cost, 0.1x read cost (requires beta header)
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/22_prompt_caching.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Prompt Caching Example"
puts "=" * 60
puts

# Create a large context that benefits from caching
# (In production, this would be documentation, code, or other large content)
large_context = <<-CONTEXT
# Comprehensive API Documentation

## Overview
This API provides a complete set of endpoints for managing users, products,
orders, and inventory in an e-commerce platform.

## Authentication
All API requests require a Bearer token in the Authorization header.
Tokens are obtained via the /auth/login endpoint.

## Rate Limiting
- Standard tier: 100 requests per minute
- Premium tier: 1000 requests per minute

## Endpoints

### Users
- GET /users - List all users (admin only)
- GET /users/:id - Get user by ID
- POST /users - Create new user
- PUT /users/:id - Update user
- DELETE /users/:id - Delete user

### Products
- GET /products - List products with pagination
- GET /products/:id - Get product details
- POST /products - Create product (admin)
- PUT /products/:id - Update product (admin)
- DELETE /products/:id - Delete product (admin)

### Orders
- GET /orders - List user's orders
- GET /orders/:id - Get order details
- POST /orders - Create new order
- PUT /orders/:id/status - Update order status
- POST /orders/:id/cancel - Cancel order

### Inventory
- GET /inventory - Check stock levels
- PUT /inventory/:product_id - Update stock

## Error Codes
- 400: Bad Request - Invalid input
- 401: Unauthorized - Invalid or expired token
- 403: Forbidden - Insufficient permissions
- 404: Not Found - Resource doesn't exist
- 429: Too Many Requests - Rate limit exceeded
- 500: Internal Server Error
CONTEXT

puts "Example 1: Basic Caching with TextContent"
puts "-" * 60

# Create cacheable content using TextContent with cache_control
cached_doc = Anthropic::TextContent.new(
  text: large_context,
  cache_control: Anthropic::CacheControl.ephemeral
)

# First request - will create cache
message1 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 256,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        cached_doc.as(Anthropic::ContentBlock),
        Anthropic::TextContent.new(text: "Based on this API documentation, how do I authenticate?").as(Anthropic::ContentBlock),
      ]
    ),
  ]
)

puts "First request (cache write):"
puts "  Input tokens: #{message1.usage.input_tokens}"
puts "  Cache creation: #{message1.usage.cache_creation_input_tokens || 0}"
puts "  Cache read: #{message1.usage.cache_read_input_tokens || 0}"
puts
puts "Response: #{message1.text[0, 200]}..."
puts

# Second request with same cached content - should read from cache
message2 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 256,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        cached_doc.as(Anthropic::ContentBlock),
        Anthropic::TextContent.new(text: "How do I create a new order?").as(Anthropic::ContentBlock),
      ]
    ),
  ]
)

puts "Second request (cache read):"
puts "  Input tokens: #{message2.usage.input_tokens}"
puts "  Cache creation: #{message2.usage.cache_creation_input_tokens || 0}"
puts "  Cache read: #{message2.usage.cache_read_input_tokens || 0}"
puts
puts "Response: #{message2.text[0, 200]}..."
puts

# Example 2: Caching system prompts
puts "Example 2: Caching System Prompts"
puts "-" * 60

system_prompt = Anthropic::TextContent.new(
  text: "You are an expert API support assistant. You have deep knowledge of REST APIs, " \
        "authentication patterns, rate limiting, and best practices for API design. " \
        "Always provide clear, concise answers with code examples when relevant.",
  cache_control: Anthropic::CacheControl.ephemeral
)

message3 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 256,
  system: [system_prompt],
  messages: [{role: "user", content: "What's the best way to handle API pagination?"}]
)

puts "With cached system prompt:"
puts "  Input tokens: #{message3.usage.input_tokens}"
puts "  Cache creation: #{message3.usage.cache_creation_input_tokens || 0}"
puts "  Cache read: #{message3.usage.cache_read_input_tokens || 0}"
puts

# Example 3: Extended 1-hour cache (beta)
puts "Example 3: Extended 1-Hour Cache (Beta)"
puts "-" * 60
puts "Note: Extended cache requires beta header: #{Anthropic::EXTENDED_CACHE_TTL_BETA}"
puts

# For 1-hour cache, use the beta.messages API
extended_cache_doc = Anthropic::TextContent.new(
  text: large_context,
  cache_control: Anthropic::CacheControl.one_hour
)

puts "CacheControl.one_hour TTL: #{Anthropic::CacheControl.one_hour.ttl} seconds"
puts

# To use extended cache:
# message = client.beta.messages.create(
#   betas: [Anthropic::EXTENDED_CACHE_TTL_BETA],
#   model: Anthropic::Model::CLAUDE_SONNET_4_5,
#   max_tokens: 256,
#   messages: [...]
# )

puts "=" * 60
puts
puts "Caching Tips:"
puts "- Cache large, static content (documentation, code, context)"
puts "- Place cached content at the beginning of messages"
puts "- Minimum cacheable size is ~1024 tokens"
puts "- Cache is per-prompt prefix, not global"
puts "- Use 1-hour cache for long-running agents"
