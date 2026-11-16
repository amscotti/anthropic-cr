module Anthropic
  # Organization telemetry destinations API (beta).
  #
  # All requests automatically include `anthropic-beta: telemetry-destinations-2026-08-11`.
  class BetaOrganizationTelemetryDestinations
    def initialize(@client : Client)
    end

    def workspaces : BetaOrganizationTelemetryDestinationWorkspaces
      BetaOrganizationTelemetryDestinationWorkspaces.new(@client)
    end

    # Create a telemetry destination (`POST /v1/organizations/telemetry_destinations`).
    def create(
      endpoint_url : String,
      workspaces : BetaTelemetryDestinationWorkspacesParam | JSON::Any | Hash(String, JSON::Any),
      display_name : String? = nil,
      headers : Hash(String, String)? = nil,
      traces : BetaTelemetryDestinationTracesParams | JSON::Any | Hash(String, JSON::Any)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTelemetryDestination
      body = {
        "endpoint_url" => JSON::Any.new(endpoint_url),
        "workspaces"   => JSON.parse(workspaces.to_json),
      } of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "display_name", display_name)
      OrganizationHelpers.set_json_any(body, "headers", headers)
      OrganizationHelpers.set_json_any(body, "traces", traces)

      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.post("/v1/organizations/telemetry_destinations", body, extra_headers: req_headers, beta: true)
      BetaTelemetryDestination.from_json(response.body)
    end

    # Retrieve a telemetry destination by ID.
    def retrieve(
      destination_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTelemetryDestination
      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.get(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaTelemetryDestination.from_json(response.body)
    end

    # Update a telemetry destination.
    #
    # Pass `display_name: nil` or `traces: nil` explicitly to clear them, or
    # pass a `nil` value inside `headers` to remove that header.
    def update(
      destination_id : String,
      display_name : String | OrganizationUnset | Nil = ORGANIZATION_UNSET,
      endpoint_url : String? = nil,
      headers : Hash(String, String?) | Hash(String, String) | Nil = nil,
      state : BetaTelemetryDestinationStateParam | JSON::Any | Hash(String, JSON::Any)? = nil,
      traces : BetaTelemetryDestinationTracesParams | OrganizationUnset | JSON::Any | Hash(String, JSON::Any) | Nil = ORGANIZATION_UNSET,
      workspaces : BetaTelemetryDestinationWorkspacesParam | JSON::Any | Hash(String, JSON::Any)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTelemetryDestination
      body = {} of String => JSON::Any
      apply_unset_display_name(body, display_name)
      OrganizationHelpers.set_json_opt(body, "endpoint_url", endpoint_url)
      apply_nullable_headers(body, headers)
      OrganizationHelpers.set_json_any(body, "state", state)
      apply_unset_traces(body, traces)
      OrganizationHelpers.set_json_any(body, "workspaces", workspaces)

      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.post(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}",
        body,
        extra_headers: req_headers,
        beta: true
      )
      BetaTelemetryDestination.from_json(response.body)
    end

    # List telemetry destinations.
    def list(
      limit : Int32? = nil,
      page : String? = nil,
      workspace_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaTelemetryDestination)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "workspace_ids", workspace_ids)

      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.get("/v1/organizations/telemetry_destinations", query, extra_headers: req_headers, beta: true)
      PageCursor(BetaTelemetryDestination).from_json(response.body)
    end

    # Delete a telemetry destination.
    def delete(
      destination_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDeletedTelemetryDestination
      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.delete(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaDeletedTelemetryDestination.from_json(response.body)
    end

    # Send a test delivery to a telemetry destination.
    def test(
      destination_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTelemetryDestinationTestResponse
      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.post(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}/test",
        nil,
        extra_headers: req_headers,
        beta: true
      )
      BetaTelemetryDestinationTestResponse.from_json(response.body)
    end

    private def apply_unset_display_name(
      body : Hash(String, JSON::Any),
      display_name : String | OrganizationUnset | Nil,
    ) : Nil
      return if display_name.is_a?(OrganizationUnset)
      body["display_name"] = display_name.nil? ? JSON::Any.new(nil) : JSON::Any.new(display_name)
    end

    private def apply_unset_traces(
      body : Hash(String, JSON::Any),
      traces : BetaTelemetryDestinationTracesParams | OrganizationUnset | JSON::Any | Hash(String, JSON::Any) | Nil,
    ) : Nil
      return if traces.is_a?(OrganizationUnset)
      body["traces"] = traces.nil? ? JSON::Any.new(nil) : JSON.parse(traces.to_json)
    end

    private def apply_nullable_headers(
      body : Hash(String, JSON::Any),
      headers : Hash(String, String?) | Hash(String, String) | Nil,
    ) : Nil
      return unless headers
      body["headers"] = JSON.parse(headers.to_json)
    end
  end

  # Workspaces configured for a telemetry destination (beta).
  class BetaOrganizationTelemetryDestinationWorkspaces
    def initialize(@client : Client)
    end

    # List workspaces attached to a telemetry destination's list.
    def list(
      destination_id : String,
      limit : Int32? = nil,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaTelemetryDestinationWorkspace)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.get(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}/workspaces",
        query,
        extra_headers: req_headers,
        beta: true
      )
      PageCursor(BetaTelemetryDestinationWorkspace).from_json(response.body)
    end

    # Add a workspace to a telemetry destination's list.
    def add(
      destination_id : String,
      workspace_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTelemetryDestinationWorkspace
      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.post(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}/workspaces/#{Anthropic.encode_path_segment(workspace_id)}",
        nil,
        extra_headers: req_headers,
        beta: true
      )
      BetaTelemetryDestinationWorkspace.from_json(response.body)
    end

    # Remove a workspace from a telemetry destination's list.
    def remove(
      destination_id : String,
      workspace_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDeletedTelemetryDestinationWorkspace
      req_headers = OrganizationHelpers.beta_headers([TELEMETRY_DESTINATIONS_BETA], betas)
      response = @client.delete(
        "/v1/organizations/telemetry_destinations/#{Anthropic.encode_path_segment(destination_id)}/workspaces/#{Anthropic.encode_path_segment(workspace_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaDeletedTelemetryDestinationWorkspace.from_json(response.body)
    end
  end

  # Organization webhook endpoints API (beta).
  #
  # All requests automatically include `anthropic-beta: webhooks-2026-10-07`.
  class BetaOrganizationWebhooks
    def initialize(@client : Client)
    end

    # Create a webhook endpoint (`POST /v1/organizations/webhooks`).
    def create(
      enabled_events : Array(String),
      url : String,
      description : String? = nil,
      name : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaNewOrganizationWebhookEndpoint
      body = {
        "enabled_events" => JSON.parse(enabled_events.to_json),
        "url"            => JSON::Any.new(url),
      } of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "description", description)
      OrganizationHelpers.set_json_opt(body, "name", name)

      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.post("/v1/organizations/webhooks", body, extra_headers: req_headers, beta: true)
      BetaNewOrganizationWebhookEndpoint.from_json(response.body)
    end

    # Retrieve a webhook endpoint by ID.
    def retrieve(
      webhook_endpoint_id : String,
      betas : Array(String) = [] of String,
    ) : BetaOrganizationWebhookEndpoint
      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.get(
        "/v1/organizations/webhooks/#{Anthropic.encode_path_segment(webhook_endpoint_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaOrganizationWebhookEndpoint.from_json(response.body)
    end

    # Update a webhook endpoint.
    def update(
      webhook_endpoint_id : String,
      description : String? = nil,
      enabled_events : Array(String)? = nil,
      name : String? = nil,
      state : String? = nil,
      url : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaOrganizationWebhookEndpoint
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "description", description)
      OrganizationHelpers.set_json_any(body, "enabled_events", enabled_events)
      OrganizationHelpers.set_json_opt(body, "name", name)
      OrganizationHelpers.set_json_opt(body, "state", state)
      OrganizationHelpers.set_json_opt(body, "url", url)

      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.post(
        "/v1/organizations/webhooks/#{Anthropic.encode_path_segment(webhook_endpoint_id)}",
        body,
        extra_headers: req_headers,
        beta: true
      )
      BetaOrganizationWebhookEndpoint.from_json(response.body)
    end

    # List webhook endpoints.
    def list(
      after_id : String? = nil,
      before_id : String? = nil,
      limit : Int32? = nil,
      order : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaOrganizationWebhookEndpointListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "after_id", after_id)
      OrganizationHelpers.set_query(query, "before_id", before_id)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "order", order)

      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.get("/v1/organizations/webhooks", query, extra_headers: req_headers, beta: true)
      BetaOrganizationWebhookEndpointListResponse.from_json(response.body)
    end

    # Delete a webhook endpoint.
    def delete(
      webhook_endpoint_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDeletedOrganizationWebhookEndpoint
      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.delete(
        "/v1/organizations/webhooks/#{Anthropic.encode_path_segment(webhook_endpoint_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaDeletedOrganizationWebhookEndpoint.from_json(response.body)
    end

    # Regenerate the signing secret of a webhook endpoint.
    def regenerate_signing_secret(
      webhook_endpoint_id : String,
      betas : Array(String) = [] of String,
    ) : BetaOrganizationWebhookEndpointSigningSecret
      req_headers = OrganizationHelpers.beta_headers([WEBHOOKS_BETA], betas)
      response = @client.post(
        "/v1/organizations/webhooks/#{Anthropic.encode_path_segment(webhook_endpoint_id)}/regenerate_signing_secret",
        nil,
        extra_headers: req_headers,
        beta: true
      )
      BetaOrganizationWebhookEndpointSigningSecret.from_json(response.body)
    end
  end

  # Claude Tag (Claude in Slack) admin API (beta).
  #
  # All requests automatically include `anthropic-beta: experimental-claude-tag-2026-10-21`.
  class BetaOrganizationClaudeTag
    def initialize(@client : Client)
    end

    def bundles : BetaOrganizationClaudeTagBundles
      BetaOrganizationClaudeTagBundles.new(@client)
    end

    def slack_channels : BetaOrganizationClaudeTagSlackChannels
      BetaOrganizationClaudeTagSlackChannels.new(@client)
    end

    def slack_workspaces : BetaOrganizationClaudeTagSlackWorkspaces
      BetaOrganizationClaudeTagSlackWorkspaces.new(@client)
    end
  end

  class BetaOrganizationClaudeTagBundles
    def initialize(@client : Client)
    end

    def targets : BetaOrganizationClaudeTagBundleTargets
      BetaOrganizationClaudeTagBundleTargets.new(@client)
    end

    # Retrieve a Claude Tag bundle by ID.
    def retrieve(
      bundle_id : String,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagBundle
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get(
        "/v1/organizations/claude_tag/bundles/#{Anthropic.encode_path_segment(bundle_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagBundle.from_json(response.body)
    end

    # List Claude Tag bundles.
    def list(
      limit : Int32? = nil,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaClaudeTagBundle)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get("/v1/organizations/claude_tag/bundles", query, extra_headers: req_headers, beta: true)
      PageCursor(BetaClaudeTagBundle).from_json(response.body)
    end
  end

  class BetaOrganizationClaudeTagBundleTargets
    def initialize(@client : Client)
    end

    # Add a Slack channel or workspace target to a Claude Tag bundle.
    #
    # Sends `target` directly as the JSON request body (not nested under a key).
    def create(
      bundle_id : String,
      target : BetaClaudeTagBundleTargetCreate | JSON::Any | Hash(String, JSON::Any),
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagBundleTarget
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.post(
        "/v1/organizations/claude_tag/bundles/#{Anthropic.encode_path_segment(bundle_id)}/targets",
        target,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagBundleTargetConverter.from_json(JSON::PullParser.new(response.body))
    end

    # Retrieve a target from a Claude Tag bundle.
    def retrieve(
      bundle_id : String,
      target_id : String,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagBundleTarget
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get(
        "/v1/organizations/claude_tag/bundles/#{Anthropic.encode_path_segment(bundle_id)}/targets/#{Anthropic.encode_path_segment(target_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagBundleTargetConverter.from_json(JSON::PullParser.new(response.body))
    end

    # List targets configured on a Claude Tag bundle.
    def list(
      bundle_id : String,
      limit : Int32? = nil,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagBundleTargetListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get(
        "/v1/organizations/claude_tag/bundles/#{Anthropic.encode_path_segment(bundle_id)}/targets",
        query,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagBundleTargetListResponse.from_json(response.body)
    end

    # Remove a target from a Claude Tag bundle.
    def delete(
      bundle_id : String,
      target_id : String,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagDeletedBundleTarget
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.delete(
        "/v1/organizations/claude_tag/bundles/#{Anthropic.encode_path_segment(bundle_id)}/targets/#{Anthropic.encode_path_segment(target_id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagDeletedBundleTarget.from_json(response.body)
    end
  end

  class BetaOrganizationClaudeTagSlackChannels
    def initialize(@client : Client)
    end

    # Create or configure a Claude Tag Slack channel entry.
    def create(
      slack : BetaClaudeTagSlackChannelIdentifiers | JSON::Any | Hash(String, JSON::Any),
      settings : BetaClaudeTagSettingsParam | JSON::Any | Hash(String, JSON::Any)? = nil,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagSlackChannel
      body = {"slack" => JSON.parse(slack.to_json)} of String => JSON::Any
      OrganizationHelpers.set_json_any(body, "settings", settings)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.post("/v1/organizations/claude_tag/slack_channels", body, extra_headers: req_headers, beta: true)
      BetaClaudeTagSlackChannel.from_json(response.body)
    end

    # Retrieve Claude Tag settings for a Slack channel.
    def retrieve(
      id : String,
      include_inherited : Bool? = nil,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagSlackChannel
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_inherited", include_inherited)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get(
        "/v1/organizations/claude_tag/slack_channels/#{Anthropic.encode_path_segment(id)}",
        query,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagSlackChannel.from_json(response.body)
    end

    # Update Claude Tag settings for a Slack channel.
    def update(
      id : String,
      settings : BetaClaudeTagSettingsParam | JSON::Any | Hash(String, JSON::Any),
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagSlackChannel
      body = {"settings" => JSON.parse(settings.to_json)}
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.post(
        "/v1/organizations/claude_tag/slack_channels/#{Anthropic.encode_path_segment(id)}",
        body,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagSlackChannel.from_json(response.body)
    end

    # List configured Claude Tag Slack channels within a Slack workspace.
    def list(
      slack_workspace_id : String,
      include_inherited : Bool? = nil,
      limit : Int32? = nil,
      page : String? = nil,
      slack_channel_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaClaudeTagSlackChannel)
      query = {"slack_workspace_id" => slack_workspace_id} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_inherited", include_inherited)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "slack_channel_id", slack_channel_id)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get("/v1/organizations/claude_tag/slack_channels", query, extra_headers: req_headers, beta: true)
      PageCursor(BetaClaudeTagSlackChannel).from_json(response.body)
    end

    # Delete stored Claude Tag overrides for a Slack channel.
    def delete(
      id : String,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagDeletedSlackChannel
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.delete(
        "/v1/organizations/claude_tag/slack_channels/#{Anthropic.encode_path_segment(id)}",
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagDeletedSlackChannel.from_json(response.body)
    end
  end

  class BetaOrganizationClaudeTagSlackWorkspaces
    def initialize(@client : Client)
    end

    # Retrieve Claude Tag settings for a Slack workspace.
    def retrieve(
      id : String,
      include_inherited : Bool? = nil,
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagSlackWorkspace
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_inherited", include_inherited)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get(
        "/v1/organizations/claude_tag/slack_workspaces/#{Anthropic.encode_path_segment(id)}",
        query,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagSlackWorkspace.from_json(response.body)
    end

    # Update Claude Tag settings for a Slack workspace.
    def update(
      id : String,
      settings : BetaClaudeTagSettingsParam | JSON::Any | Hash(String, JSON::Any),
      betas : Array(String) = [] of String,
    ) : BetaClaudeTagSlackWorkspace
      body = {"settings" => JSON.parse(settings.to_json)}
      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.post(
        "/v1/organizations/claude_tag/slack_workspaces/#{Anthropic.encode_path_segment(id)}",
        body,
        extra_headers: req_headers,
        beta: true
      )
      BetaClaudeTagSlackWorkspace.from_json(response.body)
    end

    # List configured Claude Tag Slack workspaces.
    def list(
      include_inherited : Bool? = nil,
      limit : Int32? = nil,
      page : String? = nil,
      slack_workspace_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaClaudeTagSlackWorkspace)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "include_inherited", include_inherited)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "slack_workspace_id", slack_workspace_id)

      req_headers = OrganizationHelpers.beta_headers([EXPERIMENTAL_CLAUDE_TAG_BETA], betas)
      response = @client.get("/v1/organizations/claude_tag/slack_workspaces", query, extra_headers: req_headers, beta: true)
      PageCursor(BetaClaudeTagSlackWorkspace).from_json(response.body)
    end
  end
end
