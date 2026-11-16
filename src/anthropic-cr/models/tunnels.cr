module Anthropic
  # Cloudflare connector transport for an MCP tunnel (`{"type": "cloudflare"}`).
  struct BetaCloudflareTunnelTransport
    include JSON::Serializable

    getter type : String = "cloudflare"

    def initialize(@type : String = "cloudflare")
    end
  end

  # Anthropic relay transport for an MCP tunnel (`{"type": "relay"}`).
  # `token` is populated only in the `tunnels.create` response and omitted on reads.
  struct BetaRelayTunnelTransport
    include JSON::Serializable

    getter type : String = "relay"

    @[JSON::Field(emit_null: false)]
    getter token : BetaTunnelToken? = nil

    def initialize(@token : BetaTunnelToken? = nil, @type : String = "relay")
    end
  end

  # Forward-compatible fallback for unrecognized MCP tunnel transport types.
  struct GenericBetaTunnelTransport
    getter type : String
    getter raw : JSON::Any

    def initialize(@type : String, @raw : JSON::Any)
    end

    def to_json(builder : JSON::Builder) : Nil
      raw.to_json(builder)
    end
  end

  alias GenericTunnelTransport = GenericBetaTunnelTransport

  # How traffic reaches an MCP tunnel, discriminated on `"type"`.
  alias BetaTunnelTransport = BetaCloudflareTunnelTransport | BetaRelayTunnelTransport | GenericBetaTunnelTransport

  # Discriminated-union converter for `BetaTunnel#transport`.
  module BetaTunnelTransportConverter
    def self.from_json(pull : JSON::PullParser) : BetaTunnelTransport?
      if pull.kind.null?
        pull.read_null
        return nil
      end

      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s?) || "unknown"
      raw = json.to_json

      case type
      when "cloudflare"
        BetaCloudflareTunnelTransport.from_json(raw)
      when "relay"
        BetaRelayTunnelTransport.from_json(raw)
      else
        GenericBetaTunnelTransport.new(type: type, raw: json)
      end
    end

    def self.to_json(value : BetaTunnelTransport?, builder : JSON::Builder) : Nil
      value.to_json(builder)
    end
  end

  # An MCP tunnel (research preview).
  #
  # Creation allocates a fresh hostname; the tunnel rejects MCP traffic until at
  # least one CA certificate is registered. Archival is irreversible.
  struct BetaTunnel
    include JSON::Serializable

    # Unique identifier, prefixed with `tnl_`.
    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    # Human-readable name (1-255 characters). Null if unset.
    @[JSON::Field(key: "display_name", emit_null: false)]
    getter display_name : String?

    # Anthropic-assigned hostname. Globally unique and never reused after archive.
    getter domain : String

    # How traffic reaches the tunnel (`cloudflare`, `relay`, or nil on legacy payloads).
    @[JSON::Field(converter: Anthropic::BetaTunnelTransportConverter, emit_null: false)]
    getter transport : BetaTunnelTransport? = nil

    getter type : String

    def archived? : Bool
      !archived_at.nil?
    end
  end

  # A tunnel's connector token.
  #
  # The value is fetched live; Anthropic does not store it. Treat as a credential.
  struct BetaTunnelToken
    include JSON::Serializable

    # Stable identifier for the current token value. Changes when rotated.
    getter id : String

    # Connector token used to run the tunnel.
    @[JSON::Field(key: "tunnel_token")]
    getter tunnel_token : String

    getter type : String
  end

  # A CA certificate attached to a tunnel.
  #
  # Anthropic verifies the gateway's server certificate against this CA when it
  # terminates the inner TLS session. A tunnel holds at most two non-archived
  # certificates.
  struct BetaTunnelCertificate
    include JSON::Serializable

    # Unique identifier, prefixed with `tcrt_`.
    getter id : String

    @[JSON::Field(key: "archived_at", emit_null: false)]
    getter archived_at : String?

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    @[JSON::Field(key: "expires_at", emit_null: false)]
    getter expires_at : String?

    # Lowercase hex SHA-256 fingerprint of the certificate's DER encoding.
    getter fingerprint : String

    # ID of the tunnel the certificate is registered against.
    @[JSON::Field(key: "tunnel_id")]
    getter tunnel_id : String

    getter type : String

    def archived? : Bool
      !archived_at.nil?
    end
  end

  # Page-cursor list response for tunnels (`data` + `next_page`).
  struct BetaTunnelListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaTunnel)

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?
  end

  # Page-cursor list response for tunnel certificates (`data` + `next_page`).
  struct BetaTunnelCertificateListResponse
    include JSON::Serializable
    include PageCursorMethods

    getter data : Array(BetaTunnelCertificate)

    @[JSON::Field(key: "next_page", emit_null: false)]
    getter next_page : String?
  end
end
