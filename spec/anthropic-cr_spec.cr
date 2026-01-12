require "./spec_helper"

describe Anthropic do
  it "has a version" do
    Anthropic::VERSION.should_not be_nil
  end

  describe "Error classes" do
    it "APIError stores status and body" do
      error = Anthropic::APIError.new("Test error", status: 500, body: "error body")
      error.message.should eq("Test error")
      error.status.should eq(500)
      error.body.should eq("error body")
    end

    it "RateLimitError stores retry_after" do
      error = Anthropic::RateLimitError.new("Rate limited", status: 429, body: "", retry_after: 30)
      error.retry_after.should eq(30)
      error.status.should eq(429)
    end

    it "RateLimitError inherits from APIError" do
      error = Anthropic::RateLimitError.new("Rate limited", status: 429, body: "")
      error.is_a?(Anthropic::APIError).should be_true
    end

    it "APIConnectionError stores cause" do
      cause = IO::Error.new("Connection refused")
      error = Anthropic::APIConnectionError.new("Failed to connect", cause)
      error.cause.should eq(cause)
    end

    it "APITimeoutError inherits from APIConnectionError" do
      error = Anthropic::APITimeoutError.new("Timed out")
      error.is_a?(Anthropic::APIConnectionError).should be_true
      error.is_a?(Anthropic::APIError).should be_true
    end
  end
end
