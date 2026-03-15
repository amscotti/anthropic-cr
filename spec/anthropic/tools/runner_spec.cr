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

private def streaming_event(event_type : String, data : String) : String
  (["event: #{event_type}", "data: #{data}"]).join("\n")
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
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: messages,
        tools: tools,
        max_iterations: 5,
        system: "Be helpful"
      )

      params = runner.params
      params[:model].should eq("claude-sonnet-4-6")
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
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
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      runner.next_message
      runner.last_response.should_not be_nil
    end
  end

  describe "#each_streaming" do
    it "collects streamed tool use content without hash-style block access" do
      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |_request|
        request_count += 1

        body = if request_count == 1
                 [
                   streaming_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
                   streaming_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_stream_01","name":"test","input":{}}})),
                   streaming_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}})),
                   streaming_event("content_block_stop", %({"type":"content_block_stop","index":0})),
                   streaming_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":10}})),
                   streaming_event("message_stop", %({"type":"message_stop"})),
                 ].join("\n\n")
               else
                 [
                   streaming_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_02","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":20,"output_tokens":0}}})),
                   streaming_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})),
                   streaming_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done"}})),
                   streaming_event("content_block_stop", %({"type":"content_block_stop","index":0})),
                   streaming_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}})),
                   streaming_event("message_stop", %({"type":"message_stop"})),
                 ].join("\n\n")
               end

        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          body_io: IO::Memory.new(body)
        )
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      tools = [create_dummy_tool] of Anthropic::Tool

      runner = Anthropic::ToolRunner.new(
        client: client,
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: tools
      )

      events = [] of Anthropic::AnyStreamEvent
      runner.each_streaming { |event| events << event }

      runner.finished?.should be_true
      request_count.should eq(2)
      events.any?(Anthropic::ContentBlockDeltaEvent).should be_true

      tool_result_message = runner.current_messages.last
      blocks = tool_result_message.content.as(Array(Anthropic::ContentBlock))
      tool_result = blocks.first.as(Anthropic::ToolResultContent)
      tool_result.tool_use_id.should eq("toolu_stream_01")
      tool_result.content.should eq("result")
    end
  end

  describe "container propagation" do
    it "reuses returned beta container ids on subsequent tool-calling requests" do
      request_bodies = [] of String
      request_count = 0

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        request_bodies << request.body.to_s
        request_count += 1

        body = if request_count == 1
                 %({"id":"msg_container_01","type":"message","role":"assistant","container":{"id":"cont_123","expires_at":"2026-03-14T12:00:00Z","skills":[{"skill_id":"skill_123","type":"anthropic","version":"latest"}]},"content":[{"type":"tool_use","id":"toolu_01xyz","name":"test","input":{}}],"model":"claude-sonnet-4-6","stop_reason":"tool_use","stop_sequence":null,"usage":{"input_tokens":50,"output_tokens":80}})
               else
                 Fixtures::Responses::MESSAGE_BASIC
               end

        HTTP::Client::Response.new(200, body: body, headers: HTTP::Headers{"Content-Type" => "application/json"})
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: [create_dummy_tool] of Anthropic::Tool,
        container: Anthropic::ContainerConfig.new(
          skills: [Anthropic::ContainerSkill.new(skill_id: "skill_123", version: "latest")]
        )
      )

      runner.run_until_finished

      request_bodies.size.should eq(2)

      first_request = JSON.parse(request_bodies[0])
      first_request["container"]["skills"][0]["skill_id"].as_s.should eq("skill_123")

      second_request = JSON.parse(request_bodies[1])
      second_request["container"].as_s.should eq("cont_123")
    end

    it "reuses streamed beta container ids on subsequent tool-calling requests" do
      request_bodies = [] of String
      request_count = 0

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        request_bodies << request.body.to_s
        request_count += 1

        body = if request_count == 1
                 [
                   streaming_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})),
                   streaming_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_stream_01","name":"test","input":{}}})),
                   streaming_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}})),
                   streaming_event("content_block_stop", %({"type":"content_block_stop","index":0})),
                   streaming_event("message_delta", %({"type":"message_delta","delta":{"container":{"id":"cont_stream_123","expires_at":"2026-03-14T12:00:00Z"},"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":10}})),
                   streaming_event("message_stop", %({"type":"message_stop"})),
                 ].join("\n\n")
               else
                 [
                   streaming_event("message_start", %({"type":"message_start","message":{"id":"msg_stream_02","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":20,"output_tokens":0}}})),
                   streaming_event("content_block_start", %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})),
                   streaming_event("content_block_delta", %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done"}})),
                   streaming_event("content_block_stop", %({"type":"content_block_stop","index":0})),
                   streaming_event("message_delta", %({"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}})),
                   streaming_event("message_stop", %({"type":"message_stop"})),
                 ].join("\n\n")
               end

        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          body_io: IO::Memory.new(body)
        )
      end

      client = Anthropic::Client.new(api_key: "sk-ant-test")
      runner = client.beta.messages.tool_runner(
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        messages: [Anthropic::MessageParam.user("Hi")],
        tools: [create_dummy_tool] of Anthropic::Tool,
        container: Anthropic::ContainerConfig.new(
          skills: [Anthropic::ContainerSkill.new(skill_id: "skill_123", version: "latest")]
        )
      )

      runner.each_streaming { |_event| }

      request_bodies.size.should eq(2)
      second_request = JSON.parse(request_bodies[1])
      second_request["container"].as_s.should eq("cont_stream_123")
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
