require "spec"
require "webmock"
require "vcr"
require "../src/anthropic"

# Load fixtures
require "./fixtures/responses"

# Configure WebMock
Spec.before_each do
  WebMock.reset
end

# Configure VCR
VCR.configure do |settings|
  settings.cassette_library_dir = "#{__DIR__}/fixtures/cassettes"

  # Filter sensitive data from recordings
  settings.filter_sensitive_data["ANTHROPIC_API_KEY"] = "<FILTERED_API_KEY>"
  settings.filter_sensitive_data[ENV["ANTHROPIC_API_KEY"]? || ""] = "<FILTERED_API_KEY>"
end

# Test helper to create a client with a fake API key
# def test_client(api_key : String = "sk-ant-test-key-12345") : Anthropic::Client
#   Anthropic::Client.new(api_key: api_key)
# end

# Helper to capture request details
class RequestCapture
  property body : String?
  property headers : HTTP::Headers?
  property path : String?
  property method : String?

  def initialize
  end
end

def stub_and_capture(method : Symbol, url : String, response_body : String) : RequestCapture
  capture = RequestCapture.new

  WebMock.stub(method, url).to_return do |request|
    capture.body = request.body.to_s
    capture.headers = request.headers
    capture.path = request.resource
    capture.method = request.method
    HTTP::Client::Response.new(200, body: response_body, headers: HTTP::Headers{"Content-Type" => "application/json"})
  end

  capture
end
