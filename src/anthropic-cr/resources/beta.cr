module Anthropic
  # Beta namespace for accessing beta features
  #
  # Mirrors Ruby SDK pattern:
  # ```
  # client.beta.messages.create(
  #   betas: ["structured-outputs-2025-12-15"],
  #   ...
  # )
  # ```
  class Beta
    def initialize(@client : Client)
    end

    # Access beta messages API
    def messages : BetaMessages
      BetaMessages.new(@client)
    end

    # Access beta models API
    def models : BetaModels
      BetaModels.new(@client)
    end

    # Access beta files API
    #
    # ```
    # file = client.beta.files.upload(Path["document.pdf"])
    # client.beta.files.delete(file.id)
    # ```
    def files : BetaFiles
      BetaFiles.new(@client)
    end

    # Access beta skills API
    #
    # ```
    # skills = client.beta.skills.list
    # skill = client.beta.skills.retrieve("skill_abc123")
    # ```
    def skills : BetaSkills
      BetaSkills.new(@client)
    end

    # Access beta user profiles API
    #
    # ```
    # profile = client.beta.user_profiles.create(external_id: "user-123")
    # url = client.beta.user_profiles.create_enrollment_url(profile.id)
    # ```
    def user_profiles : BetaUserProfiles
      BetaUserProfiles.new(@client)
    end

    # Access beta environments API
    def environments : BetaEnvironments
      BetaEnvironments.new(@client)
    end

    # Access beta memory stores API
    def memory_stores : BetaMemoryStores
      BetaMemoryStores.new(@client)
    end

    # Access beta sessions API
    def sessions : BetaSessions
      BetaSessions.new(@client)
    end

    # Access beta webhooks verification utility
    def webhooks : BetaWebhooks
      BetaWebhooks.new(@client)
    end

    # Access beta agents API
    def agents : BetaAgents
      BetaAgents.new(@client)
    end

    # Access beta vaults API
    def vaults : BetaVaults
      BetaVaults.new(@client)
    end

    # Access beta deployments API
    #
    # ```
    # deployment = client.beta.deployments.create(
    #   agent: "agent_123",
    #   environment_id: "env_123",
    #   name: "Nightly summary",
    #   initial_events: [{"type" => "user.message", "content" => [{"type" => "text", "text" => "Summarize the day."}]}]
    # )
    # client.beta.deployments.run(deployment.id)
    # ```
    def deployments : BetaDeployments
      BetaDeployments.new(@client)
    end

    # Access beta deployment runs API
    def deployment_runs : BetaDeploymentRuns
      BetaDeploymentRuns.new(@client)
    end
  end

  # Beta Messages API with explicit beta header support
  class BetaMessages
    def initialize(@client : Client)
    end

    def batches : BetaBatches
      BetaBatches.new(@client)
    end

    # Create a tool runner for automatic tool execution
    #
    # ```
    # runner = client.beta.messages.tool_runner(
    #   model: "claude-sonnet-4-6",
    #   max_tokens: 1024,
    #   messages: [Anthropic::MessageParam.user("What's the weather in Tokyo?")],
    #   tools: [weather_tool]
    # )
    #
    # runner.each_message { |msg| pp msg.content }
    # final = runner.final_message
    # ```
    #
    # With auto-compaction:
    # ```
    # compaction = Anthropic::CompactionConfig.enabled(threshold: 3000) { |before, after|
    #   puts "Compacted: #{before} -> #{after} tokens"
    # }
    #
    # runner = client.beta.messages.tool_runner(
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   messages: messages,
    #   tools: tools,
    #   compaction: compaction
    # )
    # ```
    def tool_runner(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam),
      tools : Array(Tool),
      betas : Array(String) = [] of String,
      max_iterations : Int32 = 10,
      system : String? = nil,
      compaction : CompactionConfig? = nil,
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      container : String | ContainerConfig? = nil,
    ) : ToolRunner
      ToolRunner.new(
        client: @client,
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        tools: tools,
        max_iterations: max_iterations,
        system: system,
        compaction: compaction,
        speed: speed,
        thinking: thinking,
        output_config: output_config,
        inference_geo: inference_geo,
        container: container,
        betas: betas,
        use_beta: true
      )
    end

    # Create a message with beta features
    #
    # ```
    # message = client.beta.messages.create(
    #   betas: ["structured-outputs-2025-12-15"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   output_schema: my_schema,
    #   messages: [{role: "user", content: "Hello"}]
    # )
    # ```
    def create(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
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
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : Message
      # Convert messages to typed MessageParam array
      typed_messages = normalize_messages(messages)

      # Build tool definitions
      tool_definitions = build_tool_definitions(tools, server_tools)

      # Build output format if schema provided
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }

      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaMessageCreateParams.new(
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
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(
        betas,
        server_tools,
        output_format,
        resolved_output_config,
        cache_control,
        diagnostics: diagnostics,
        include_user_profiles_beta: !user_profile_id.nil?,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token
      )
      merged = merge_user_profile_header(beta_headers, user_profile_id)
      merged = merge_extra_headers(merged, extra_headers)
      response = @client.post("/v1/messages", params, merged)
      Message.from_json(response.body)
    end

    # Stream a beta message with individual events
    #
    # ```
    # client.beta.messages.stream(
    #   betas: ["web-search-2025-03-05"],
    #   model: Anthropic::Model::CLAUDE_SONNET_4_6,
    #   max_tokens: 1024,
    #   server_tools: [Anthropic::WebSearchTool.new],
    #   messages: [{role: "user", content: "Search for..."}]
    # ) do |event|
    #   # handle events
    # end
    # ```
    def stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
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
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
      &
    )
      open_stream(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        betas: betas,
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
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_schema: output_schema,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        user_profile_id: user_profile_id,
        extra_headers: extra_headers,
        diagnostics: diagnostics
      ) do |stream|
        stream.each { |event| yield event }
      end
    end

    # Open a beta streaming response and yield a richer stream helper object.
    def open_stream(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
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
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
      &
    )
      typed_messages = normalize_messages(messages)
      tool_definitions = build_tool_definitions(tools, server_tools)
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }
      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaMessageCreateParams.new(
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
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(
        betas,
        server_tools,
        output_format,
        resolved_output_config,
        cache_control,
        diagnostics: diagnostics,
        include_user_profiles_beta: !user_profile_id.nil?,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token
      )

      merged = merge_user_profile_header(beta_headers, user_profile_id)
      merged = merge_extra_headers(merged, extra_headers)

      @client.post_stream("/v1/messages", params, merged) do |response|
        yield MessageStream.new(response)
      end
    end

    # Count tokens for a beta message request without sending it
    def count_tokens(
      model : String,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      betas : Array(String) = [] of String,
      system : String | Array(TextContent)? = nil,
      tools : Array(Tool)? = nil,
      server_tools : Array(ServerTool)? = nil,
      tool_choice : ToolChoice? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      output_schema : BaseOutputSchema? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      speed : String? = nil,
      user_profile_id : String? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : TokenCountResponse
      typed_messages = normalize_messages(messages)
      tool_definitions = build_tool_definitions(tools, server_tools)
      output_format = output_schema.try { |schema| OutputFormat.from_output_schema(schema) }
      resolved_output_config = merge_output_config(output_config, effort, output_format)

      params = BetaTokenCountParams.new(
        model: model,
        messages: typed_messages,
        system: system,
        tools: tool_definitions,
        tool_choice: tool_choice,
        thinking: thinking,
        cache_control: cache_control,
        output_format: resolved_output_config ? nil : output_format,
        output_config: resolved_output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        speed: speed,
        diagnostics: diagnostics
      )

      beta_headers = build_beta_headers(
        betas,
        server_tools,
        output_format,
        resolved_output_config,
        cache_control,
        diagnostics: diagnostics,
        include_token_counting_beta: true,
        include_user_profiles_beta: !user_profile_id.nil?
      )

      response = @client.post("/v1/messages/count_tokens?beta=true", params, merge_user_profile_header(beta_headers, user_profile_id))
      TokenCountResponse.from_json(response.body)
    end

    def parse(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : TypedOutputSchema(T),
      betas : Array(String) = [] of String,
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
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : ParsedMessage(T) forall T
      message = create(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        output_schema: output_schema,
        betas: betas,
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
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        user_profile_id: user_profile_id,
        extra_headers: extra_headers,
        diagnostics: diagnostics
      )

      ParsedMessage(T).new(message, message.parsed_output_as!(T))
    end

    def parse(
      model : String,
      max_tokens : Int32,
      messages : Array(MessageParam) | Array(NamedTuple(role: String, content: String)),
      output_schema : OutputSchema,
      betas : Array(String) = [] of String,
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
      speed : String? = nil,
      thinking : ThinkingConfig? = nil,
      cache_control : CacheControl? = nil,
      effort : String? = nil,
      output_config : OutputConfig? = nil,
      inference_geo : String? = nil,
      context_management : ContextManagementConfig? = nil,
      container : String | ContainerConfig? = nil,
      mcp_servers : Array(MCPServerDefinition)? = nil,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
      user_profile_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      diagnostics : DiagnosticsParam? = nil,
    ) : ParsedMessage(JSON::Any)
      message = create(
        model: model,
        max_tokens: max_tokens,
        messages: messages,
        output_schema: output_schema,
        betas: betas,
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
        speed: speed,
        thinking: thinking,
        cache_control: cache_control,
        effort: effort,
        output_config: output_config,
        inference_geo: inference_geo,
        context_management: context_management,
        container: container,
        mcp_servers: mcp_servers,
        fallbacks: fallbacks,
        fallback_credit_token: fallback_credit_token,
        user_profile_id: user_profile_id,
        extra_headers: extra_headers,
        diagnostics: diagnostics
      )

      ParsedMessage(JSON::Any).new(message, message.parsed_output_as!(JSON::Any))
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

    private def merge_output_config(
      output_config : OutputConfig?,
      effort : String?,
      output_format : OutputFormat?,
    ) : OutputConfig?
      return output_config unless effort || output_format

      OutputConfig.new(
        effort: output_config.try(&.effort) || effort,
        format: output_config.try(&.format) || output_format,
        task_budget: output_config.try(&.task_budget)
      )
    end

    private def build_beta_headers(
      betas : Array(String),
      server_tools : Array(ServerTool)?,
      output_format : OutputFormat?,
      output_config : OutputConfig?,
      cache_control : CacheControl?,
      diagnostics : DiagnosticsParam? = nil,
      include_token_counting_beta : Bool = false,
      include_user_profiles_beta : Bool = false,
      fallbacks : Array(FallbackParam)? = nil,
      fallback_credit_token : String? = nil,
    ) : Hash(String, String)?
      # Both a fallback chain and a bare credit-token retry require the
      # server-side fallback beta.
      merged_betas = betas.dup
      if (fallbacks && !fallbacks.empty?) || fallback_credit_token
        merged_betas << SERVER_SIDE_FALLBACK_BETA unless merged_betas.includes?(SERVER_SIDE_FALLBACK_BETA)
      end

      Anthropic.resolve_beta_headers(
        betas: merged_betas,
        server_tools: server_tools,
        cache_control: cache_control,
        diagnostics: diagnostics,
        output_format: output_format,
        output_config: output_config,
        include_token_counting: include_token_counting_beta,
        include_user_profiles: include_user_profiles_beta
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
