module Anthropic
  # Shared query builders for organization analytics resources.
  module OrganizationAnalyticsHelpers
    def self.activity_query(
      date : String? = nil,
      starting_date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
    ) : OrganizationHelpers::QueryHash
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "date", date)
      OrganizationHelpers.set_query(query, "starting_date", starting_date)
      OrganizationHelpers.set_query(query, "ending_date", ending_date)
      OrganizationHelpers.set_query(query, "filter", filter)
      OrganizationHelpers.set_query(query, "group_by", normalize_array(group_by))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "order", order)
      OrganizationHelpers.set_query(query, "order_by", order_by)
      OrganizationHelpers.set_query(query, "page", page)
      query
    end

    def self.add_report_filters(
      query : OrganizationHelpers::QueryHash,
      starting_at : String,
      ending_at : String? = nil,
      limit : Int32? = nil,
      page : String? = nil,
      group_by : Array(String) | String | Nil = nil,
      models : Array(String)? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      inference_geos : Array(String)? = nil,
      speeds : Array(String)? = nil,
      order : String? = nil,
      order_by : String? = nil,
      exclude_deleted_users : Bool? = nil,
    ) : OrganizationHelpers::QueryHash
      query["starting_at"] = starting_at
      OrganizationHelpers.set_query(query, "ending_at", ending_at)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "group_by", normalize_array(group_by))
      add_dimension_arrays(
        query,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
      )
      OrganizationHelpers.set_query(query, "order", order)
      OrganizationHelpers.set_query(query, "order_by", order_by)
      OrganizationHelpers.set_query(query, "exclude_deleted_users", exclude_deleted_users)
      query
    end

    def self.add_usage_cost_dimensions(
      query : OrganizationHelpers::QueryHash,
      actor_ids : Array(String)? = nil,
      actor_types : Array(String)? = nil,
      agent_ids : Array(String)? = nil,
      api_key_ids : Array(String)? = nil,
      deployment_ids : Array(String)? = nil,
      environment_ids : Array(String)? = nil,
      organization_ids : Array(String)? = nil,
      service_tiers : Array(String)? = nil,
      session_ids : Array(String)? = nil,
      user_profile_ids : Array(String)? = nil,
      workspace_ids : Array(String)? = nil,
      time_bucket_width : String? = nil,
    ) : OrganizationHelpers::QueryHash
      add_id_filters_part1(query, actor_ids, actor_types, agent_ids, api_key_ids, deployment_ids, environment_ids)
      add_id_filters_part2(query, organization_ids, service_tiers, session_ids, user_profile_ids, workspace_ids, time_bucket_width)
      query
    end

    private def self.add_dimension_arrays(
      query : OrganizationHelpers::QueryHash,
      models : Array(String)?,
      products : Array(String)?,
      rbac_group_ids : Array(String)?,
      slack_channel_ids : Array(String)?,
      claude_tag_categories : Array(String)?,
      claude_tag_user_ids : Array(String)?,
      context_windows : Array(String)?,
      inference_geos : Array(String)?,
      speeds : Array(String)?,
    ) : Nil
      OrganizationHelpers.set_query(query, "models", models)
      OrganizationHelpers.set_query(query, "products", products)
      OrganizationHelpers.set_query(query, "rbac_group_ids", rbac_group_ids)
      OrganizationHelpers.set_query(query, "slack_channel_ids", slack_channel_ids)
      OrganizationHelpers.set_query(query, "claude_tag_categories", claude_tag_categories)
      OrganizationHelpers.set_query(query, "claude_tag_user_ids", claude_tag_user_ids)
      OrganizationHelpers.set_query(query, "context_windows", context_windows)
      OrganizationHelpers.set_query(query, "inference_geos", inference_geos)
      OrganizationHelpers.set_query(query, "speeds", speeds)
    end

    private def self.add_id_filters_part1(
      query : OrganizationHelpers::QueryHash,
      actor_ids : Array(String)?,
      actor_types : Array(String)?,
      agent_ids : Array(String)?,
      api_key_ids : Array(String)?,
      deployment_ids : Array(String)?,
      environment_ids : Array(String)?,
    ) : Nil
      OrganizationHelpers.set_query(query, "actor_ids", actor_ids)
      OrganizationHelpers.set_query(query, "actor_types", actor_types)
      OrganizationHelpers.set_query(query, "agent_ids", agent_ids)
      OrganizationHelpers.set_query(query, "api_key_ids", api_key_ids)
      OrganizationHelpers.set_query(query, "deployment_ids", deployment_ids)
      OrganizationHelpers.set_query(query, "environment_ids", environment_ids)
    end

    private def self.add_id_filters_part2(
      query : OrganizationHelpers::QueryHash,
      organization_ids : Array(String)?,
      service_tiers : Array(String)?,
      session_ids : Array(String)?,
      user_profile_ids : Array(String)?,
      workspace_ids : Array(String)?,
      time_bucket_width : String?,
    ) : Nil
      OrganizationHelpers.set_query(query, "organization_ids", organization_ids)
      OrganizationHelpers.set_query(query, "service_tiers", service_tiers)
      OrganizationHelpers.set_query(query, "session_ids", session_ids)
      OrganizationHelpers.set_query(query, "user_profile_ids", user_profile_ids)
      OrganizationHelpers.set_query(query, "workspace_ids", workspace_ids)
      OrganizationHelpers.set_query(query, "time_bucket_width", time_bucket_width)
    end

    private def self.normalize_array(value : Array(String) | String | Nil) : Array(String)?
      case value
      when String        then [value]
      when Array(String) then value
      else                    nil
      end
    end
  end

  # Organization analytics (GA surface).
  #
  # Exposes enterprise usage activity endpoints (`summaries`, `users`,
  # `apps.chat.projects`, `connectors`, `plugins`, `skills`, `artifacts`).
  # For API token usage and cost reports (`usage`, `cost`, and legacy
  # `*_report` endpoints), use `client.beta.organization.analytics`.
  class OrganizationAnalytics
    def initialize(@client : Client, @beta : Bool = false)
    end

    def summaries : OrganizationAnalyticsSummaries
      OrganizationAnalyticsSummaries.new(@client, beta: @beta)
    end

    def users : OrganizationAnalyticsUsers
      OrganizationAnalyticsUsers.new(@client, beta: @beta)
    end

    def apps : OrganizationAnalyticsApps
      OrganizationAnalyticsApps.new(@client, beta: @beta)
    end

    def connectors : OrganizationAnalyticsConnectors
      OrganizationAnalyticsConnectors.new(@client, beta: @beta)
    end

    def plugins : OrganizationAnalyticsPlugins
      OrganizationAnalyticsPlugins.new(@client, beta: @beta)
    end

    def skills : OrganizationAnalyticsSkills
      OrganizationAnalyticsSkills.new(@client, beta: @beta)
    end

    def artifacts : OrganizationAnalyticsArtifacts
      OrganizationAnalyticsArtifacts.new(@client, beta: @beta)
    end
  end

  # Organization analytics (beta surface).
  #
  # Inherits all GA enterprise activity analytics and adds `usage`,
  # `cost`, `usage_report`, `cost_report`, `user_usage_report`, and
  # `user_cost_report`.
  class BetaOrganizationAnalytics < OrganizationAnalytics
    def initialize(client : Client)
      super(client, beta: true)
    end

    def usage : BetaOrganizationAnalyticsUsage
      BetaOrganizationAnalyticsUsage.new(@client)
    end

    def cost : BetaOrganizationAnalyticsCost
      BetaOrganizationAnalyticsCost.new(@client)
    end

    def usage_report : BetaOrganizationAnalyticsUsageReport
      BetaOrganizationAnalyticsUsageReport.new(@client)
    end

    def cost_report : BetaOrganizationAnalyticsCostReport
      BetaOrganizationAnalyticsCostReport.new(@client)
    end

    def user_usage_report : BetaOrganizationAnalyticsUserUsageReport
      BetaOrganizationAnalyticsUserUsageReport.new(@client)
    end

    def user_cost_report : BetaOrganizationAnalyticsUserCostReport
      BetaOrganizationAnalyticsUserCostReport.new(@client)
    end
  end

  class OrganizationAnalyticsApps
    def initialize(@client : Client, @beta : Bool = false)
    end

    def chat : OrganizationAnalyticsAppsChat
      OrganizationAnalyticsAppsChat.new(@client, beta: @beta)
    end
  end

  class OrganizationAnalyticsAppsChat
    def initialize(@client : Client, @beta : Bool = false)
    end

    def projects : OrganizationAnalyticsAppsChatProjects
      OrganizationAnalyticsAppsChatProjects.new(@client, beta: @beta)
    end
  end

  class OrganizationAnalyticsSummaries
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve single-day activity summaries (`GET /v1/organizations/analytics/summaries`).
    def list(
      starting_date : String,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      limit : Int32? = nil,
      page : String? = nil,
    ) : PageCursor(AnalyticsSingleDayActivitySummary)
      query = OrganizationAnalyticsHelpers.activity_query(
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        limit: limit,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/summaries", query, beta: @beta)
      PageCursor(AnalyticsSingleDayActivitySummary).from_json(response.body)
    end
  end

  class OrganizationAnalyticsUsers
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve per-user enterprise activity metrics (`GET /v1/organizations/analytics/users`).
    def list(
      date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      starting_date : String? = nil,
    ) : PageCursor(AnalyticsUserActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/users", query, beta: @beta)
      PageCursor(AnalyticsUserActivity).from_json(response.body)
    end
  end

  class OrganizationAnalyticsAppsChatProjects
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve chat project activity metrics (`GET /v1/organizations/analytics/apps/chat/projects`).
    def list(
      date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      starting_date : String? = nil,
    ) : PageCursor(AnalyticsProjectActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/apps/chat/projects", query, beta: @beta)
      PageCursor(AnalyticsProjectActivity).from_json(response.body)
    end
  end

  class OrganizationAnalyticsConnectors
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve connector activity metrics (`GET /v1/organizations/analytics/connectors`).
    def list(
      date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      starting_date : String? = nil,
    ) : PageCursor(AnalyticsConnectorActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/connectors", query, beta: @beta)
      PageCursor(AnalyticsConnectorActivity).from_json(response.body)
    end
  end

  class OrganizationAnalyticsPlugins
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve plugin activity metrics (`GET /v1/organizations/analytics/plugins`).
    def list(
      date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      starting_date : String? = nil,
    ) : PageCursor(AnalyticsPluginActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/plugins", query, beta: @beta)
      PageCursor(AnalyticsPluginActivity).from_json(response.body)
    end
  end

  class OrganizationAnalyticsSkills
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve skill activity metrics (`GET /v1/organizations/analytics/skills`).
    def list(
      date : String? = nil,
      ending_date : String? = nil,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      starting_date : String? = nil,
    ) : PageCursor(AnalyticsSkillActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        starting_date: starting_date,
        ending_date: ending_date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        order: order,
        order_by: order_by,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/skills", query, beta: @beta)
      PageCursor(AnalyticsSkillActivity).from_json(response.body)
    end
  end

  class OrganizationAnalyticsArtifacts
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve artifact activity metrics (`GET /v1/organizations/analytics/artifacts`).
    def list(
      date : String,
      filter : Array(String)? = nil,
      group_by : Array(String) | String | Nil = nil,
      limit : Int32? = nil,
      page : String? = nil,
    ) : PageCursor(AnalyticsArtifactActivity)
      query = OrganizationAnalyticsHelpers.activity_query(
        date: date,
        filter: filter,
        group_by: group_by,
        limit: limit,
        page: page,
      )
      response = @client.get("/v1/organizations/analytics/artifacts", query, beta: @beta)
      PageCursor(AnalyticsArtifactActivity).from_json(response.body)
    end
  end

  # Token usage analytics report (`GET /v1/organizations/analytics/usage`).
  #
  # Sends `anthropic-beta: analytics-usage-cost-2026-08-24`.
  class BetaOrganizationAnalyticsUsage
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      actor_ids : Array(String)? = nil,
      actor_types : Array(String)? = nil,
      agent_ids : Array(String)? = nil,
      api_key_ids : Array(String)? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      deployment_ids : Array(String)? = nil,
      ending_at : String? = nil,
      environment_ids : Array(String)? = nil,
      exclude_deleted_users : Bool? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      order : String? = nil,
      order_by : String? = nil,
      organization_ids : Array(String)? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      service_tiers : Array(String)? = nil,
      session_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      time_bucket_width : String? = nil,
      user_profile_ids : Array(String)? = nil,
      workspace_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : ReportPageCursor(BetaAnalyticsUsageItem)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
        order: order,
        order_by: order_by,
        exclude_deleted_users: exclude_deleted_users,
      )
      OrganizationAnalyticsHelpers.add_usage_cost_dimensions(
        query,
        actor_ids: actor_ids,
        actor_types: actor_types,
        agent_ids: agent_ids,
        api_key_ids: api_key_ids,
        deployment_ids: deployment_ids,
        environment_ids: environment_ids,
        organization_ids: organization_ids,
        service_tiers: service_tiers,
        session_ids: session_ids,
        user_profile_ids: user_profile_ids,
        workspace_ids: workspace_ids,
        time_bucket_width: time_bucket_width,
      )

      headers = OrganizationHelpers.beta_headers([ANALYTICS_USAGE_COST_BETA], betas)
      response = @client.get("/v1/organizations/analytics/usage", query, extra_headers: headers, beta: true)
      ReportPageCursor(BetaAnalyticsUsageItem).from_json(response.body)
    end
  end

  # Cost analytics report (`GET /v1/organizations/analytics/cost`).
  #
  # Sends `anthropic-beta: analytics-usage-cost-2026-08-24`.
  class BetaOrganizationAnalyticsCost
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      actor_ids : Array(String)? = nil,
      actor_types : Array(String)? = nil,
      agent_ids : Array(String)? = nil,
      api_key_ids : Array(String)? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      deployment_ids : Array(String)? = nil,
      ending_at : String? = nil,
      environment_ids : Array(String)? = nil,
      exclude_deleted_users : Bool? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      order : String? = nil,
      order_by : String? = nil,
      organization_ids : Array(String)? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      service_tiers : Array(String)? = nil,
      session_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      time_bucket_width : String? = nil,
      user_profile_ids : Array(String)? = nil,
      workspace_ids : Array(String)? = nil,
      betas : Array(String) = [] of String,
    ) : ReportPageCursor(BetaAnalyticsCostItem)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
        order: order,
        order_by: order_by,
        exclude_deleted_users: exclude_deleted_users,
      )
      OrganizationAnalyticsHelpers.add_usage_cost_dimensions(
        query,
        actor_ids: actor_ids,
        actor_types: actor_types,
        agent_ids: agent_ids,
        api_key_ids: api_key_ids,
        deployment_ids: deployment_ids,
        environment_ids: environment_ids,
        organization_ids: organization_ids,
        service_tiers: service_tiers,
        session_ids: session_ids,
        user_profile_ids: user_profile_ids,
        workspace_ids: workspace_ids,
        time_bucket_width: time_bucket_width,
      )

      headers = OrganizationHelpers.beta_headers([ANALYTICS_USAGE_COST_BETA], betas)
      response = @client.get("/v1/organizations/analytics/cost", query, extra_headers: headers, beta: true)
      ReportPageCursor(BetaAnalyticsCostItem).from_json(response.body)
    end
  end

  # Legacy usage time-bucket report (`GET /v1/organizations/analytics/usage_report`).
  class BetaOrganizationAnalyticsUsageReport
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      bucket_width : String? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      ending_at : String? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      user_ids : Array(String)? = nil,
    ) : ReportPageCursor(BetaAnalyticsUsageReportTimeBucket)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
      )
      OrganizationHelpers.set_query(query, "bucket_width", bucket_width)
      OrganizationHelpers.set_query(query, "user_ids", user_ids)

      response = @client.get("/v1/organizations/analytics/usage_report", query, beta: true)
      ReportPageCursor(BetaAnalyticsUsageReportTimeBucket).from_json(response.body)
    end
  end

  # Legacy cost time-bucket report (`GET /v1/organizations/analytics/cost_report`).
  class BetaOrganizationAnalyticsCostReport
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      bucket_width : String? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      ending_at : String? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      user_ids : Array(String)? = nil,
    ) : ReportPageCursor(BetaAnalyticsCostReportTimeBucket)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
      )
      OrganizationHelpers.set_query(query, "bucket_width", bucket_width)
      OrganizationHelpers.set_query(query, "user_ids", user_ids)

      response = @client.get("/v1/organizations/analytics/cost_report", query, beta: true)
      ReportPageCursor(BetaAnalyticsCostReportTimeBucket).from_json(response.body)
    end
  end

  # Legacy per-user usage report (`GET /v1/organizations/analytics/user_usage_report`).
  class BetaOrganizationAnalyticsUserUsageReport
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      bucket_width : String? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      ending_at : String? = nil,
      exclude_deleted_users : Bool? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      user_ids : Array(String)? = nil,
    ) : ReportPageCursor(BetaAnalyticsUsageUsersItem)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
        order: order,
        order_by: order_by,
        exclude_deleted_users: exclude_deleted_users,
      )
      OrganizationHelpers.set_query(query, "bucket_width", bucket_width)
      OrganizationHelpers.set_query(query, "user_ids", user_ids)

      response = @client.get("/v1/organizations/analytics/user_usage_report", query, beta: true)
      ReportPageCursor(BetaAnalyticsUsageUsersItem).from_json(response.body)
    end
  end

  # Legacy per-user cost report (`GET /v1/organizations/analytics/user_cost_report`).
  class BetaOrganizationAnalyticsUserCostReport
    def initialize(@client : Client)
    end

    def list(
      starting_at : String,
      bucket_width : String? = nil,
      claude_tag_categories : Array(String)? = nil,
      claude_tag_user_ids : Array(String)? = nil,
      context_windows : Array(String)? = nil,
      ending_at : String? = nil,
      exclude_deleted_users : Bool? = nil,
      group_by : Array(String) | String | Nil = nil,
      inference_geos : Array(String)? = nil,
      limit : Int32? = nil,
      models : Array(String)? = nil,
      order : String? = nil,
      order_by : String? = nil,
      page : String? = nil,
      products : Array(String)? = nil,
      rbac_group_ids : Array(String)? = nil,
      slack_channel_ids : Array(String)? = nil,
      speeds : Array(String)? = nil,
      user_ids : Array(String)? = nil,
    ) : ReportPageCursor(BetaAnalyticsCostUsersItem)
      query = {} of String => (String | Array(String))
      OrganizationAnalyticsHelpers.add_report_filters(
        query,
        starting_at: starting_at,
        ending_at: ending_at,
        limit: limit,
        page: page,
        group_by: group_by,
        models: models,
        products: products,
        rbac_group_ids: rbac_group_ids,
        slack_channel_ids: slack_channel_ids,
        claude_tag_categories: claude_tag_categories,
        claude_tag_user_ids: claude_tag_user_ids,
        context_windows: context_windows,
        inference_geos: inference_geos,
        speeds: speeds,
        order: order,
        order_by: order_by,
        exclude_deleted_users: exclude_deleted_users,
      )
      OrganizationHelpers.set_query(query, "bucket_width", bucket_width)
      OrganizationHelpers.set_query(query, "user_ids", user_ids)

      response = @client.get("/v1/organizations/analytics/user_cost_report", query, beta: true)
      ReportPageCursor(BetaAnalyticsCostUsersItem).from_json(response.body)
    end
  end
end
