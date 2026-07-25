module Anthropic
  # MCP Tunnels API resource (beta / research preview).
  #
  # Requires the `mcp-tunnels-2026-06-22` beta header and may change without a
  # deprecation period. Supersedes Admin API endpoints at
  # `/v1/organizations/tunnels` during a migration window.
  #
  # **Auth:** tunnel *management* endpoints (create/list/archive/certificates/
  # reveal_token/rotate_token) require a bearer token with the
  # `workspace:manage_tunnels` scope from Workload Identity Federation.
  # Standard `ANTHROPIC_API_KEY` / admin API keys are **not** accepted and
  # return 401. Using a tunnel URL from Messages (`mcp_servers`) still uses a
  # normal workspace API key + the MCP client beta — that is separate.
  #
  # Creation allocates a fresh hostname; the tunnel rejects MCP traffic until at
  # least one CA certificate is added via `certificates`.
  #
  # ```
  # # Client must be configured with a WIF-exchanged bearer that has
  # # workspace:manage_tunnels (not a plain API key).
  # tunnel = client.beta.tunnels.create(display_name: "prod-gateway")
  # token = client.beta.tunnels.reveal_token(tunnel.id)
  # cert = client.beta.tunnels.certificates.create(
  #   tunnel.id,
  #   ca_certificate_pem: File.read("ca.pem"),
  # )
  # ```
  class BetaTunnels
    getter certificates : BetaTunnelCertificates

    def initialize(@client : Client)
      @certificates = BetaTunnelCertificates.new(@client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged = betas.dup
      merged << MCP_TUNNELS_BETA unless merged.includes?(MCP_TUNNELS_BETA)
      {"anthropic-beta" => merged.join(",")}
    end

    # Create a tunnel. Not idempotent; allocates a fresh hostname.
    def create(
      display_name : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTunnel
      params = {} of String => JSON::Any
      params["display_name"] = JSON::Any.new(display_name) if display_name

      response = @client.post("/v1/tunnels?beta=true", params, beta_headers(betas))
      BetaTunnel.from_json(response.body)
    end

    # Retrieve a tunnel by ID.
    def retrieve(
      tunnel_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnel
      response = @client.get("/v1/tunnels/#{tunnel_id}?beta=true", nil, beta_headers(betas))
      BetaTunnel.from_json(response.body)
    end

    # List tunnels (newest first). Archived tunnels excluded unless
    # `include_archived` is set.
    def list(
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTunnelListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get("/v1/tunnels?beta=true", query, beta_headers(betas))
      BetaTunnelListResponse.from_json(response.body)
    end

    # Archive a tunnel irreversibly (certificates archived, hostname retired,
    # token invalidated). Retrying an already-archived tunnel is a no-op.
    def archive(
      tunnel_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnel
      response = @client.post("/v1/tunnels/#{tunnel_id}/archive?beta=true", nil, beta_headers(betas))
      BetaTunnel.from_json(response.body)
    end

    # Reveal the tunnel's connector token (POST so it stays out of access logs).
    # Repeated calls return the same value until rotated.
    def reveal_token(
      tunnel_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnelToken
      response = @client.post("/v1/tunnels/#{tunnel_id}/reveal_token?beta=true", nil, beta_headers(betas))
      BetaTunnelToken.from_json(response.body)
    end

    # Rotate the connector token. Invalidates the current value for new
    # connections; established connections are not severed.
    def rotate_token(
      tunnel_id : String,
      reason : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTunnelToken
      params = {} of String => JSON::Any
      params["reason"] = JSON::Any.new(reason) if reason

      response = @client.post("/v1/tunnels/#{tunnel_id}/rotate_token?beta=true", params, beta_headers(betas))
      BetaTunnelToken.from_json(response.body)
    end
  end

  # Tunnel CA certificates sub-resource (beta / research preview).
  #
  # Registers PEM-encoded CA certificates used to verify the gateway's server
  # certificate when Anthropic terminates the inner TLS session.
  # Nested certificates resource under `client.beta.tunnels.certificates`.
  # Same auth rules as `BetaTunnels`: WIF bearer with `workspace:manage_tunnels`.
  class BetaTunnelCertificates
    def initialize(@client : Client)
    end

    private def beta_headers(betas : Array(String) = [] of String) : Hash(String, String)
      merged = betas.dup
      merged << MCP_TUNNELS_BETA unless merged.includes?(MCP_TUNNELS_BETA)
      {"anthropic-beta" => merged.join(",")}
    end

    # Register a public CA certificate on a tunnel.
    #
    # `ca_certificate_pem` must be PEM-encoded X.509 with exactly one certificate
    # and no private-key material (max 8KB). A tunnel holds at most two
    # non-archived certificates.
    def create(
      tunnel_id : String,
      ca_certificate_pem : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnelCertificate
      params = {"ca_certificate_pem" => ca_certificate_pem}

      response = @client.post(
        "/v1/tunnels/#{tunnel_id}/certificates?beta=true",
        params,
        beta_headers(betas)
      )
      BetaTunnelCertificate.from_json(response.body)
    end

    # Fetch a tunnel certificate by ID.
    def retrieve(
      tunnel_id : String,
      certificate_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnelCertificate
      response = @client.get(
        "/v1/tunnels/#{tunnel_id}/certificates/#{certificate_id}?beta=true",
        nil,
        beta_headers(betas)
      )
      BetaTunnelCertificate.from_json(response.body)
    end

    # List certificates registered on a tunnel.
    def list(
      tunnel_id : String,
      include_archived : Bool? = nil,
      limit : Int32 = 20,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaTunnelCertificateListResponse
      query = {"limit" => limit.to_s}
      query["include_archived"] = include_archived.to_s if include_archived != nil
      query["page"] = page if page

      response = @client.get(
        "/v1/tunnels/#{tunnel_id}/certificates?beta=true",
        query,
        beta_headers(betas)
      )
      BetaTunnelCertificateListResponse.from_json(response.body)
    end

    # Archive a tunnel certificate (removes it from the trusted set; record kept).
    def archive(
      tunnel_id : String,
      certificate_id : String,
      betas : Array(String) = [] of String,
    ) : BetaTunnelCertificate
      response = @client.post(
        "/v1/tunnels/#{tunnel_id}/certificates/#{certificate_id}/archive?beta=true",
        nil,
        beta_headers(betas)
      )
      BetaTunnelCertificate.from_json(response.body)
    end
  end
end
