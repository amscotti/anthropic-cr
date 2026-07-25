require "../../spec_helper"

describe "MCP Tunnels" do
  tunnel_json = %({
    "id":"tnl_01abc",
    "archived_at":null,
    "created_at":"2026-06-22T12:00:00Z",
    "display_name":"prod-gateway",
    "domain":"tnl-01abc.tunnels.anthropic.com",
    "type":"tunnel"
  }).gsub(/\s+/, "")

  token_json = %({
    "id":"ttok_01",
    "tunnel_token":"tnl_tok_secret_value",
    "type":"tunnel_token"
  }).gsub(/\s+/, "")

  cert_json = %({
    "id":"tcrt_01xyz",
    "archived_at":null,
    "created_at":"2026-06-22T12:05:00Z",
    "expires_at":"2027-06-22T12:05:00Z",
    "fingerprint":"aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
    "tunnel_id":"tnl_01abc",
    "type":"tunnel_certificate"
  }).gsub(/\s+/, "")

  describe Anthropic::BetaTunnels do
    it "creates a tunnel with display_name and mcp-tunnels beta header" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/tunnels?beta=true", tunnel_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      tunnel = client.beta.tunnels.create(display_name: "prod-gateway")

      tunnel.id.should eq("tnl_01abc")
      tunnel.display_name.should eq("prod-gateway")
      tunnel.domain.should eq("tnl-01abc.tunnels.anthropic.com")
      tunnel.archived?.should be_false
      tunnel.type.should eq("tunnel")

      body = JSON.parse(capture.body.not_nil!)
      body["display_name"].as_s.should eq("prod-gateway")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
      capture.headers.not_nil!["anthropic-beta"].should contain("mcp-tunnels-2026-06-22")
    end

    it "creates a tunnel without body fields when display_name omitted" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/tunnels?beta=true", tunnel_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      client.beta.tunnels.create

      body = JSON.parse(capture.body.not_nil!)
      body.as_h.has_key?("display_name").should be_false
    end

    it "retrieves a tunnel by id" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/tunnels/tnl_01abc?beta=true")
        .to_return(body: tunnel_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      tunnel = client.beta.tunnels.retrieve("tnl_01abc")
      tunnel.id.should eq("tnl_01abc")
    end

    it "lists tunnels with pagination params" do
      list_json = %({"data":[#{tunnel_json}],"next_page":"cursor_2"})
      capture = RequestCapture.new
      WebMock.stub(:get, /https:\/\/api\.anthropic\.com\/v1\/tunnels\?beta=true/)
        .to_return do |request|
          capture.headers = request.headers
          capture.path = request.resource
          capture.method = request.method
          HTTP::Client::Response.new(200, body: list_json, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response = client.beta.tunnels.list(include_archived: true, limit: 5, page: "cursor_1")
      response.data.size.should eq(1)
      response.next_page.should eq("cursor_2")
      capture.path.not_nil!.should contain("limit=5")
      capture.path.not_nil!.should contain("include_archived=true")
      capture.path.not_nil!.should contain("page=cursor_1")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end

    it "archives a tunnel" do
      archived = tunnel_json.sub(%("archived_at":null), %("archived_at":"2026-06-23T00:00:00Z"))
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/tunnels/tnl_01abc/archive?beta=true", archived)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      tunnel = client.beta.tunnels.archive("tnl_01abc")
      tunnel.archived?.should be_true
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end

    it "reveals a tunnel token" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/tunnels/tnl_01abc/reveal_token?beta=true", token_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      token = client.beta.tunnels.reveal_token("tnl_01abc")
      token.id.should eq("ttok_01")
      token.tunnel_token.should eq("tnl_tok_secret_value")
      token.type.should eq("tunnel_token")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end

    it "rotates a tunnel token with optional reason" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/tunnels/tnl_01abc/rotate_token?beta=true", token_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      token = client.beta.tunnels.rotate_token("tnl_01abc", reason: "credential leak")
      token.tunnel_token.should eq("tnl_tok_secret_value")

      body = JSON.parse(capture.body.not_nil!)
      body["reason"].as_s.should eq("credential leak")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end
  end

  describe Anthropic::BetaTunnelCertificates do
    it "creates a certificate with ca_certificate_pem" do
      capture = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/tunnels/tnl_01abc/certificates?beta=true",
        cert_json
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n"

      cert = client.beta.tunnels.certificates.create("tnl_01abc", ca_certificate_pem: pem)

      cert.id.should eq("tcrt_01xyz")
      cert.tunnel_id.should eq("tnl_01abc")
      cert.fingerprint.should start_with("aabbcc")
      cert.type.should eq("tunnel_certificate")

      body = JSON.parse(capture.body.not_nil!)
      body["ca_certificate_pem"].as_s.should eq(pem)
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end

    it "retrieves a certificate" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/tunnels/tnl_01abc/certificates/tcrt_01xyz?beta=true")
        .to_return(body: cert_json)
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      cert = client.beta.tunnels.certificates.retrieve("tnl_01abc", "tcrt_01xyz")
      cert.id.should eq("tcrt_01xyz")
    end

    it "lists certificates for a tunnel" do
      list_json = %({"data":[#{cert_json}],"next_page":null})
      capture = RequestCapture.new
      WebMock.stub(:get, /https:\/\/api\.anthropic\.com\/v1\/tunnels\/tnl_01abc\/certificates\?beta=true/)
        .to_return do |request|
          capture.headers = request.headers
          capture.path = request.resource
          HTTP::Client::Response.new(200, body: list_json, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      response = client.beta.tunnels.certificates.list("tnl_01abc", limit: 20)
      response.data.size.should eq(1)
      response.data.first.id.should eq("tcrt_01xyz")
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end

    it "archives a certificate" do
      archived = cert_json.sub(%("archived_at":null), %("archived_at":"2026-06-24T00:00:00Z"))
      capture = stub_and_capture(
        :post,
        "https://api.anthropic.com/v1/tunnels/tnl_01abc/certificates/tcrt_01xyz/archive?beta=true",
        archived
      )
      client = Anthropic::Client.new(api_key: "sk-ant-test")

      cert = client.beta.tunnels.certificates.archive("tnl_01abc", "tcrt_01xyz")
      cert.archived?.should be_true
      capture.headers.not_nil!["anthropic-beta"].should contain(Anthropic::MCP_TUNNELS_BETA)
    end
  end
end
