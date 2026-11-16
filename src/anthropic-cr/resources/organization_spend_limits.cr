module Anthropic
  # Organization spend limits (GA surface).
  #
  # Exposes `effective` spend summaries and `increase_requests`. For
  # managing spend-limit configurations (`list`, `retrieve`, `set`,
  # `delete`), use `client.beta.organization.spend_limits`.
  class OrganizationSpendLimits
    def initialize(@client : Client, @beta : Bool = false)
    end

    def effective : OrganizationSpendLimitsEffective
      OrganizationSpendLimitsEffective.new(@client, beta: @beta)
    end

    def increase_requests : OrganizationSpendLimitsIncreaseRequests
      OrganizationSpendLimitsIncreaseRequests.new(@client, beta: @beta)
    end
  end

  # Organization spend limits (beta surface).
  #
  # Inherits `effective` and `increase_requests` and adds beta spend-limit
  # CRUD (`list`, `retrieve`, `set`, `delete`).
  class BetaOrganizationSpendLimits < OrganizationSpendLimits
    def initialize(client : Client)
      super(client, beta: true)
    end

    # Retrieve a spend limit by ID.
    def retrieve(spend_limit_id : String, betas : Array(String) = [] of String) : SpendLimit
      headers = OrganizationHelpers.beta_headers(extra_betas: betas)
      response = @client.get(
        "/v1/organizations/spend_limits/#{Anthropic.encode_path_segment(spend_limit_id)}",
        extra_headers: headers,
        beta: true
      )
      SpendLimit.from_json(response.body)
    end

    # List configured spend limits in the organization.
    #
    # Sends `anthropic-beta: spend-limit-reads-2026-09-26`.
    def list(
      limit : Int32? = nil,
      page : String? = nil,
      scope_type : String | Array(String) | Nil = nil,
      workspace_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : SpendLimitListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "workspace_id", workspace_id)
      case scope_type
      when String        then query["scope_type"] = [scope_type]
      when Array(String) then query["scope_type"] = scope_type
      end

      headers = OrganizationHelpers.beta_headers([SPEND_LIMIT_READS_BETA], betas)
      response = @client.get("/v1/organizations/spend_limits", query, extra_headers: headers, beta: true)
      SpendLimitListResponse.from_json(response.body)
    end

    # Create or update a spend limit for a `(scope, period)` pair.
    #
    # Pass `amount: nil` to set an unlimited override.
    def set(
      amount : String?,
      scope : SpendLimitSetScope | JSON::Any | Hash(String, JSON::Any),
      period : String? = nil,
      betas : Array(String) = [] of String,
    ) : SpendLimit
      body = {
        "amount" => amount.nil? ? JSON::Any.new(nil) : JSON::Any.new(amount),
        "scope"  => JSON.parse(scope.to_json),
      } of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "period", period)

      headers = OrganizationHelpers.beta_headers(extra_betas: betas)
      response = @client.post("/v1/organizations/spend_limits", body, extra_headers: headers, beta: true)
      SpendLimit.from_json(response.body)
    end

    # Delete a spend limit by ID.
    def delete(spend_limit_id : String, betas : Array(String) = [] of String) : SpendLimitDeleteResponse
      headers = OrganizationHelpers.beta_headers(extra_betas: betas)
      response = @client.delete(
        "/v1/organizations/spend_limits/#{Anthropic.encode_path_segment(spend_limit_id)}",
        extra_headers: headers,
        beta: true
      )
      SpendLimitDeleteResponse.from_json(response.body)
    end
  end

  # Effective spend limit summaries for organization members (GA and beta).
  class OrganizationSpendLimitsEffective
    def initialize(@client : Client, @beta : Bool = false)
    end

    # List effective spend limits and current period-to-date spend.
    def list(
      limit : Int32? = nil,
      page : String? = nil,
      period : String | Array(String) | Nil = nil,
      user_ids : Array(String)? = nil,
    ) : SpendSummaryListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      case period
      when String        then query["period"] = [period]
      when Array(String) then query["period"] = period
      end
      OrganizationHelpers.set_query(query, "user_ids", user_ids)

      response = @client.get("/v1/organizations/spend_limits/effective", query, beta: @beta)
      SpendSummaryListResponse.from_json(response.body)
    end
  end

  class BetaOrganizationSpendLimitsEffective < OrganizationSpendLimitsEffective
    def initialize(client : Client)
      super(client, beta: true)
    end
  end

  # Spend limit increase requests (GA and beta).
  class OrganizationSpendLimitsIncreaseRequests
    def initialize(@client : Client, @beta : Bool = false)
    end

    # Retrieve a spend limit increase request by ID.
    def retrieve(spend_limit_increase_request_id : String) : SpendLimitIncreaseRequest
      response = @client.get(
        "/v1/organizations/spend_limit_increase_requests/#{Anthropic.encode_path_segment(spend_limit_increase_request_id)}",
        beta: @beta
      )
      SpendLimitIncreaseRequest.from_json(response.body)
    end

    # List spend limit increase requests.
    def list(
      actor_ids : Array(String)? = nil,
      limit : Int32? = nil,
      page : String? = nil,
      status : Array(String)? = nil,
    ) : SpendLimitIncreaseRequestListResponse
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "actor_ids", actor_ids)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "status", status)

      response = @client.get("/v1/organizations/spend_limit_increase_requests", query, beta: @beta)
      SpendLimitIncreaseRequestListResponse.from_json(response.body)
    end

    # Approve a spend limit increase request.
    def approve(
      spend_limit_increase_request_id : String,
      amount : String,
      period : String? = nil,
      suppress_notification : Bool? = nil,
    ) : SpendLimitIncreaseRequestApproveResponse
      body = {"amount" => JSON::Any.new(amount)} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "period", period)
      OrganizationHelpers.set_json_opt(body, "suppress_notification", suppress_notification)

      response = @client.post(
        "/v1/organizations/spend_limit_increase_requests/#{Anthropic.encode_path_segment(spend_limit_increase_request_id)}/approve",
        body,
        beta: @beta
      )
      SpendLimitIncreaseRequestApproveResponse.from_json(response.body)
    end

    # Deny a spend limit increase request.
    def deny(
      spend_limit_increase_request_id : String,
      suppress_notification : Bool? = nil,
    ) : SpendLimitIncreaseRequest
      body = {} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "suppress_notification", suppress_notification)

      response = @client.post(
        "/v1/organizations/spend_limit_increase_requests/#{Anthropic.encode_path_segment(spend_limit_increase_request_id)}/deny",
        body,
        beta: @beta
      )
      SpendLimitIncreaseRequest.from_json(response.body)
    end
  end

  class BetaOrganizationSpendLimitsIncreaseRequests < OrganizationSpendLimitsIncreaseRequests
    def initialize(client : Client)
      super(client, beta: true)
    end
  end
end
