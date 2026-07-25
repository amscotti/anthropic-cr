require "../../spec_helper"

describe Anthropic::Model do
  it "exposes CLAUDE_OPUS_5 for long-running agents and coding" do
    Anthropic::Model::CLAUDE_OPUS_5.should eq("claude-opus-5")
  end

  it "rolls CLAUDE_OPUS to Opus 5 while keeping precise 4.8 available" do
    Anthropic::Model::CLAUDE_OPUS.should eq("claude-opus-5")
    Anthropic::Model::CLAUDE_OPUS_4_8.should eq("claude-opus-4-8")
    Anthropic.model_name(:opus).should eq(Anthropic::Model::CLAUDE_OPUS_5)
    Anthropic.model_name(:opus_5).should eq(Anthropic::Model::CLAUDE_OPUS_5)
    Anthropic.model_name(:opus_4_8).should eq(Anthropic::Model::CLAUDE_OPUS_4_8)
  end
end

describe Anthropic::RefusalStopDetails do
  it "parses general_harms refusal category" do
    json = %({"type":"refusal","category":"general_harms","explanation":"Related to a restricted topic."})
    details = Anthropic::RefusalStopDetails.from_json(json)
    details.category.should eq("general_harms")
    details.explanation.should eq("Related to a restricted topic.")
  end
end

describe Anthropic::Message do
  it "accepts model_context_window_exceeded as a stop_reason" do
    json = %({"id":"msg_mcwe","type":"message","role":"assistant","content":[{"type":"text","text":"partial"}],"model":"claude-opus-5","stop_reason":"model_context_window_exceeded","stop_sequence":null,"usage":{"input_tokens":100,"output_tokens":10}})
    message = Anthropic::Message.from_json(json)
    message.stop_reason.should eq("model_context_window_exceeded")
    message.refusal?.should be_false
  end
end
