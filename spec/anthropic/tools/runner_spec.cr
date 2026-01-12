require "../../spec_helper"

# Helper to create a dummy tool for testing
private def create_dummy_tool(name = "test") : Anthropic::Tool
  Anthropic.tool(
    name: name,
    description: "A test tool",
    schema: {} of String => Anthropic::Schema::Property,
    required: [] of String
  ) { |_| "result" }
end

describe Anthropic::ToolRunner do
  describe "#params" do
    it "returns current runner parameters" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      messages = [Anthropic::MessageParam.user("Hello")]
      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: messages,
        tools: tools,
        max_iterations: 5,
        system: "Be helpful"
      )

      params = runner.params
      params[:model].should eq("claude-sonnet-4-5-20250929")
      params[:max_tokens].should eq(1024)
      params[:max_iterations].should eq(5)
      params[:system].should eq("Be helpful")
      params[:iteration].should eq(0)
      params[:finished].should be_false
    end
  end

  describe "#finished?" do
    it "returns false initially" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.finished?.should be_false
    end
  end

  describe "#reset" do
    it "resets runner state" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      # Run to completion
      runner.final_message

      runner.finished?.should be_true
      runner.params[:iteration].should be > 0

      # Reset
      runner.reset

      runner.finished?.should be_false
      runner.params[:iteration].should eq(0)
    end
  end

  describe "#next_message" do
    it "returns nil when finished" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      # First call gets message
      msg = runner.next_message
      msg.should_not be_nil

      # Since MESSAGE_BASIC has no tool_use, should be finished
      runner.finished?.should be_true

      # Next call returns nil
      runner.next_message.should be_nil
    end

    it "increments iteration count" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.params[:iteration].should eq(0)
      runner.next_message
      runner.params[:iteration].should eq(1)
    end
  end

  describe "#feed_messages" do
    it "adds messages to current conversation" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      initial_count = runner.current_messages.size

      runner.feed_messages([
        Anthropic::MessageParam.assistant("Hello!"),
        Anthropic::MessageParam.user("How are you?"),
      ])

      runner.current_messages.size.should eq(initial_count + 2)
    end

    it "resets finished state when messages added" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.next_message
      runner.finished?.should be_true

      runner.feed_messages([Anthropic::MessageParam.user("More input")])
      runner.finished?.should be_false
    end
  end

  describe "#feed_message" do
    it "adds a single message" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      initial_count = runner.current_messages.size
      runner.feed_message(Anthropic::MessageParam.user("Another message"))
      runner.current_messages.size.should eq(initial_count + 1)
    end
  end

  describe "#run_until_finished" do
    it "returns all messages" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      messages = runner.run_until_finished
      messages.should be_a(Array(Anthropic::Message))
      messages.size.should be >= 1
    end
  end

  describe "#current_messages" do
    it "returns a copy of current messages" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      msgs = runner.current_messages
      msgs.should be_a(Array(Anthropic::MessageParam))
      msgs.size.should eq(1)
    end
  end

  describe "#last_response" do
    it "returns nil before any messages" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.last_response.should be_nil
    end

    it "returns last response after next_message" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.next_message
      runner.last_response.should_not be_nil
    end
  end
end

describe Anthropic::CompactionConfig do
  describe ".enabled" do
    it "creates enabled config with threshold" do
      callback_called = false

      config = Anthropic::CompactionConfig.enabled(threshold: 5000) do |_before, _after|
        callback_called = true
      end

      config.enabled?.should be_true
      config.context_token_threshold.should eq(5000)
      config.on_compact.should_not be_nil
    end
  end

  describe "#enabled?" do
    it "defaults to false" do
      config = Anthropic::CompactionConfig.new
      config.enabled?.should be_false
    end
  end

  describe "#context_token_threshold" do
    it "defaults to 10000" do
      config = Anthropic::CompactionConfig.new
      config.context_token_threshold.should eq(10000)
    end
  end
end
