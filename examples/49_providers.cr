require "../src/anthropic-cr"
require "dotenv"

# Alternate providers example (non-Azure)
#
# Run Claude through the AWS gateway, Google Cloud gateway, or Vertex AI
# instead of the first-party API. Each client mirrors the official
# Python/Ruby/TypeScript provider clients.
#
# AWS gateway (SigV4 with default chain, or ANTHROPIC_AWS_API_KEY):
#   export AWS_REGION=us-east-1
#
# Google Cloud gateway (ADC, access token, or token provider):
#   export ANTHROPIC_GOOGLE_CLOUD_PROJECT=my-project
#   export ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID=ws_123
#   gcloud auth application-default login
#
# Vertex AI (ADC, access token, or token provider):
#   export CLOUD_ML_REGION=us-central1
#   export ANTHROPIC_VERTEX_PROJECT_ID=my-project
#
# Run with (uncomment the provider to try):
#   crystal run examples/49_providers.cr

Dotenv.load if File.exists?(".env")

# AWS gateway — full first-party API through aws-external-anthropic.
# aws_client = Anthropic::AWS::Client.new(aws_region: ENV["AWS_REGION"]? || "us-east-1")

# Google Cloud gateway — full first-party API through claude.googleapis.com.
# gcp_client = Anthropic::GoogleCloud::Client.new(
#   project: ENV["ANTHROPIC_GOOGLE_CLOUD_PROJECT"]?,
#   location: ENV["ANTHROPIC_GOOGLE_CLOUD_LOCATION"]? || "global",
#   workspace_id: ENV["ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID"]?
# )

# Vertex AI — publisher-model API (messages and count_tokens).
vertex_client = Anthropic::Vertex::Client.new(
  region: ENV["CLOUD_ML_REGION"]? || "us-central1",
  project_id: ENV["ANTHROPIC_VERTEX_PROJECT_ID"]?,
  access_token: ENV["VERTEX_ACCESS_TOKEN"]?
)

message = vertex_client.messages.create(
  model: "claude-haiku-4-5-20251001",
  max_tokens: 128,
  messages: [{role: "user", content: "Hello from Crystal!"}]
)

puts message.text
