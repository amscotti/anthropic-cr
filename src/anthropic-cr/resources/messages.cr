module Anthropic
  # Union type for all tools (user-defined and server-side)
  alias AnyTool = Tool | ServerTool

  # Messages API resource
  #
  # Note: Unlike the Ruby SDK which accepts all tools in a single `tools` array,
  # this SDK uses separate `tools` and `server_tools` parameters. This design:
  # - Provides better type safety and IDE autocompletion
  # - Automatically manages required beta headers for server tools
  # - Is more explicit about tool types being used
  class Messages
    def initialize(@client : Client)
    end

    # Create a message (non-streaming)
    #
    # ```
    # # Basic message
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   messages: [{role: "user", content: "Hello!"}]
    # )
    #
    # # With extended thinking
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 4096,
    #   thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 2000),
    #   messages: [{role: "user", content: "Solve this problem..."}]
    # )
    #
    # # With web search
    # message = client.messages.create(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   tools: [Anthropic::WebSearchTool.new],
    #   messages: [{role: "user", content: "What's the latest AI news?"}]
    # )
    # ```
    def create(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      container : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      fallbacks : FallbacksParam? = nil,
      fallback_credit_token : FallbackCreditToken? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : Message
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = MessageCreateParams.new(
        model: model,
        max_tokens: max_tokens,
        messages: typed_messages,
        stream: false,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        thinking: thinking,
        cache_control: cache_control,
        container: container,
        output_config: output_config,
        inference_geo: inference_geo,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(server_tools, cache_control, diagnostics, fallbacks, fallback_credit_token, user_profile_id)

      merged = merge_user_profile_header(beta_headers, user_profile_id)
      merged = merge_extra_headers(merged, extra_headers)
      response = @client.post("/v1/messages", params, merged)
      Message.from_json(response.body)
    end

    # Stream a message with individual events
    #
    # ```
    # client.messages.stream(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   messages: [{role: "user", content: "Tell me a story"}]
    # ) do |event|
    #   case event
    #   when Anthropic::ContentBlockDeltaEvent
    #     print event.text
    #   end
    # end
    # ```
    def stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      container : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      fallbacks : FallbacksParam? = nil,
      fallback_credit_token : FallbackCreditToken? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
      &
    )
      open_stream(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tools,
        server_tools: server_tools,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        thinking: thinking,
        cache_control: cache_control,
        container: container,
        output_config: output_config,
        inference_geo: inference_geo,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        user_profile_id: user_profile_id,
        extra_headers: extra_headers,
        diagnostics: diagnostics
      ) do |stream|
        stream.each { |event| yield event }
      end
    end

    # Open a streaming response and yield a richer stream helper object.
    def open_stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Int32? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      stop_sequences : Array(String)? = nil,
      metadata : Metadata? = nil,
      service_tier : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      container : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      fallbacks : FallbacksParam? = nil,
      fallback_credit_token : FallbackCreditToken? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
      &
    )
      typed_messages = normalize_messages(messages)
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = MessageCreateParams.new(
        model: model,
        max_tokens: max_tokens,
        messages: typed_messages,
        stream: true,
        system: system,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        tools: tool_definitions,
        tool_choice: tool_choice,
        stop_sequences: stop_sequences,
        metadata: metadata,
        service_tier: service_tier,
        thinking: thinking,
        cache_control: cache_control,
        container: container,
        output_config: output_config,
        inference_geo: inference_geo,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(server_tools, cache_control, diagnostics, fallbacks, fallback_credit_token, user_profile_id)
      merged = merge_user_profile_header(beta_headers, user_profile_id)
      merged = merge_extra_headers(merged, extra_headers)

      @client.post_stream("/v1/messages", params, merged) do |response|
        yield MessageStream.new(response)
      end
    end

    # Access batches sub-resource
    def batches : Batches
      Batches.new(@client)
    end

    # Count tokens for a message without sending it
    #
    # Useful for estimating costs before making a request.
    #
    # ```
    # count = client.messages.count_tokens(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   messages: [{role: "user", content: "Hello, Claude!"}],
    #   system: "You are a helpful assistant."
    # )
    # puts "Input tokens: #{count.input_tokens}"
    # ```
    def count_tokens(
      model : String,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      system : String | Array(TextContent)? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      user_profile_id : String? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : TokenCountResponse
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      params = TokenCountParams.new(
        model: model,
        messages: typed_messages,
        system: system,
        tools: tool_definitions,
        tool_choice: tool_choice,
        thinking: thinking,
        cache_control: cache_control,
        output_config: output_config,
        inference_geo: inference_geo,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(server_tools, cache_control, diagnostics, user_profile_id: user_profile_id)

      response = @client.post("/v1/messages/count_tokens", params, merge_user_profile_header(beta_headers, user_profile_id))
      TokenCountResponse.from_json(response.body)
    end

    # Convert NamedTuple messages to MessageParam array
    private def normalize_messages(
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
    ) : Array(MessageParam)
      case messages
      when Array(MessageParam)
        messages
      else
        messages.map { |msg| MessageParam.new(role: msg[:role], content: msg[:content]) }
      end
    end

    # Build combined tool definitions from user tools and server tools
    private def build_tool_definitions(
      tools : Array(Tool)?,
      server_tools : Array(ServerTool)?,
    ) : Array(ToolDefinition | ServerTool)?
      return nil if (tools.nil? || tools.empty?) && (server_tools.nil? || server_tools.empty?)

      result = [] of ToolDefinition | ServerTool

      tools.try &.each do |tool|
        result << tool.to_definition
      end

      server_tools.try &.each do |server_tool|
        result << server_tool
      end

      result.empty? ? nil : result
    end

    # Build beta headers based on server tools used
    private def build_beta_headers(
      server_tools : Array(ServerTool)?,
      cache_control : CacheControl?,
      diagnostics : DiagnosticsParam? = nil,
      fallbacks : FallbacksParam? = nil,
      fallback_credit_token : FallbackCreditToken? = nil,
      user_profile_id : String? = nil,
    ) : Hash(String, String)?
      betas = [] of String

      # Explicit chain / "default" and bare-string credit tokens auto-attach the
      # server-side fallback beta. Object-form credit tokens need the July 2026
      # fallback-credit beta (mode support).
      if Anthropic.fallbacks_present?(fallbacks) || fallback_credit_token.is_a?(String)
        betas << SERVER_SIDE_FALLBACK_BETA unless betas.includes?(SERVER_SIDE_FALLBACK_BETA)
      end
      if fallback_credit_token.is_a?(FallbackCreditTokenParam)
        betas << FALLBACK_CREDIT_BETA_2026_07_01 unless betas.includes?(FALLBACK_CREDIT_BETA_2026_07_01)
      end

      Anthropic.resolve_beta_headers(
        betas: betas,
        server_tools: server_tools,
        cache_control: cache_control,
        diagnostics: diagnostics,
        include_user_profiles: !user_profile_id.nil?
      )
    end

    private def requires_extended_cache_beta?(cache_control : CacheControl?) : Bool
      (cache_control.try(&.ttl) || 0) > 0
    end

    # Merge the `anthropic-user-profile-id` request header into an existing
    # header hash. The API expects the user profile id as a request header
    # (not a JSON body field); it scopes memory, trust grants, and other
    # user-specific state to the referenced profile.
    private def merge_user_profile_header(headers : Hash(String, String)?, user_profile_id : String?) : Hash(String, String)?
      return headers if user_profile_id.nil?
      (headers || {} of String => String).merge({"anthropic-user-profile-id" => user_profile_id})
    end

    # Merge caller-supplied extra headers into an existing header hash. The
    # `x-stainless-helper` key uses append semantics (see StainlessHelper) so
    # multiple helpers composing on one request don't clobber each other.
    private def merge_extra_headers(headers : Hash(String, String)?, extra : Hash(String, String)?) : Hash(String, String)?
      return headers if extra.nil? || extra.empty?
      base = (headers || {} of String => String).dup
      extra.each do |key, value|
        if key.downcase == StainlessHelper::HEADER
          base = StainlessHelper.merge_helper_header(base, value)
        else
          base[key] = value
        end
      end
      base
    end
  end
end
