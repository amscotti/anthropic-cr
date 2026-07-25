require "digest/sha1"
require "digest/sha256"
require "http/client"
require "json"
require "uri"

module Anthropic
  module Bedrock
    # AWS credentials used for SigV4 signing of Bedrock Runtime requests.
    struct Credentials
      getter access_key_id : String
      getter secret_access_key : String
      getter session_token : String?
      getter region : String

      def initialize(
        @access_key_id : String,
        @secret_access_key : String,
        @region : String,
        @session_token : String? = nil,
      )
      end
    end

    # Internal key material before region is finalized.
    private struct ResolvedKeys
      getter access_key_id : String
      getter secret_access_key : String
      getter session_token : String?
      getter region : String?

      def initialize(
        @access_key_id : String,
        @secret_access_key : String,
        @session_token : String? = nil,
        @region : String? = nil,
      )
      end
    end

    # Mutable partial result while walking the provider chain.
    private class ResolutionState
      property access : String?
      property secret : String?
      property session : String?
      property region : String?
      getter sources_tried = [] of String

      def initialize(
        @access : String? = nil,
        @secret : String? = nil,
        @session : String? = nil,
        @region : String? = nil,
      )
      end

      def complete? : Bool
        !(access.nil? || secret.nil?)
      end

      def note(source : String) : Nil
        sources_tried << source
      end

      # Merge keys only for missing fields (shared-credentials style fill-in).
      def fill_missing(keys : ResolvedKeys, source : String) : Nil
        @access ||= keys.access_key_id
        @secret ||= keys.secret_access_key
        @session ||= keys.session_token
        @region ||= keys.region
        note(source)
      end

      # Replace keys entirely (login cache / SSO / IMDS become the sole source).
      def replace_with(keys : ResolvedKeys, source : String) : Nil
        @access = keys.access_key_id
        @secret = keys.secret_access_key
        @session = keys.session_token
        @region ||= keys.region
        note(source)
      end
    end

    # IAM Identity Center (SSO) profile settings from `~/.aws/config`.
    private struct SsoProfileConfig
      getter start_url : String
      getter sso_region : String
      getter account_id : String
      getter role_name : String

      def initialize(
        @start_url : String,
        @sso_region : String,
        @account_id : String,
        @role_name : String,
      )
      end
    end

    # Resolve AWS credentials for Bedrock.
    #
    # Resolution order (simplified AWS default chain, pure Crystal):
    # 1. Explicit constructor args (`aws_access_key`, `aws_secret_key`, …)
    # 2. Environment: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
    #    `AWS_SESSION_TOKEN`, `AWS_REGION` / `AWS_DEFAULT_REGION`, `AWS_PROFILE`
    # 3. Shared credentials file (`~/.aws/credentials`, or
    #    `AWS_SHARED_CREDENTIALS_FILE`) for the selected profile
    # 4. AWS CLI `aws login` cache (`~/.aws/login/cache/{sha256(login_session)}.json`)
    #    when the profile sets `login_session` in `~/.aws/config`
    # 5. IAM Identity Center (SSO): read cached access token from
    #    `~/.aws/sso/cache/{sha1(start_url)}.json`, then call
    #    `GetRoleCredentials` on `portal.sso.{region}.amazonaws.com`
    #    (legacy profile keys or modern `[sso-session …]` form)
    # 6. EC2 Instance Metadata Service (IMDS), unless
    #    `AWS_EC2_METADATA_DISABLED` is true — short timeouts so local
    #    development does not hang
    #
    # Region is resolved from explicit arg → `AWS_REGION` →
    # `AWS_DEFAULT_REGION` → profile `region` in config → IMDS → `us-east-1`.
    #
    # Optional path kwargs (`credentials_path`, `config_path`,
    # `login_cache_dir`, `sso_cache_dir`, `home`) are for tests; production
    # callers omit them.
    module CredentialsResolver
      extend self

      DEFAULT_REGION         = "us-east-1"
      IMDS_CONNECT_TIMEOUT   = 1.seconds
      IMDS_READ_TIMEOUT      = 1.seconds
      IMDS_DEFAULT_ENDPOINT  = "http://169.254.169.254"
      IMDS_TOKEN_TTL_SECONDS = "21600"
      SSO_CONNECT_TIMEOUT    = 5.seconds
      SSO_READ_TIMEOUT       = 10.seconds

      def resolve(
        aws_access_key : String? = nil,
        aws_secret_key : String? = nil,
        aws_session_token : String? = nil,
        aws_region : String? = nil,
        aws_profile : String? = nil,
        *,
        credentials_path : Path | String | Nil = nil,
        config_path : Path | String | Nil = nil,
        login_cache_dir : Path | String | Nil = nil,
        sso_cache_dir : Path | String | Nil = nil,
        home : Path | String | Nil = nil,
        enable_imds : Bool? = nil,
      ) : Credentials
        paths = resolve_paths(home, credentials_path, config_path, login_cache_dir, sso_cache_dir)
        profile = present(aws_profile) || present(ENV["AWS_PROFILE"]?) || "default"

        state = ResolutionState.new(
          access: present(aws_access_key) || present(ENV["AWS_ACCESS_KEY_ID"]?),
          secret: present(aws_secret_key) || present(ENV["AWS_SECRET_ACCESS_KEY"]?),
          session: present(aws_session_token) || present(ENV["AWS_SESSION_TOKEN"]?),
          region: present(aws_region) || present(ENV["AWS_REGION"]?) || present(ENV["AWS_DEFAULT_REGION"]?),
        )
        state.note("explicit/env") if state.access || state.secret

        credentials_ini = load_ini_file(paths[:credentials])
        config_ini = load_ini_file(paths[:config])

        apply_shared_credentials(state, credentials_ini, profile, paths[:credentials])
        apply_login_cache(state, config_ini, profile, paths[:login_cache])
        apply_sso(state, config_ini, profile, paths[:sso_cache])
        state.region ||= region_from_config(config_ini, profile)
        apply_imds(state, enable_imds)

        region = state.region || DEFAULT_REGION
        access = state.access
        secret = state.secret
        if access.nil? || secret.nil?
          raise ArgumentError.new(resolution_error(profile, state.sources_tried))
        end

        Credentials.new(access, secret, region, state.session)
      end

      # --- Provider chain steps ----------------------------------------------

      private def resolve_paths(
        home : Path | String | Nil,
        credentials_path : Path | String | Nil,
        config_path : Path | String | Nil,
        login_cache_dir : Path | String | Nil,
        sso_cache_dir : Path | String | Nil,
      ) : NamedTuple(credentials: Path, config: Path, login_cache: Path, sso_cache: Path)
        home_path = resolve_home(home)
        {
          credentials: path_or(
            credentials_path,
            ENV["AWS_SHARED_CREDENTIALS_FILE"]?,
            home_path / ".aws" / "credentials"
          ),
          config: path_or(
            config_path,
            ENV["AWS_CONFIG_FILE"]?,
            home_path / ".aws" / "config"
          ),
          login_cache: path_or(
            login_cache_dir,
            ENV["AWS_LOGIN_CACHE_DIRECTORY"]?,
            home_path / ".aws" / "login" / "cache"
          ),
          sso_cache: path_or(
            sso_cache_dir,
            ENV["AWS_SSO_CACHE_DIRECTORY"]?,
            home_path / ".aws" / "sso" / "cache"
          ),
        }
      end

      private def apply_shared_credentials(
        state : ResolutionState,
        credentials_ini : Hash(String, Hash(String, String)),
        profile : String,
        creds_file : Path,
      ) : Nil
        return if state.complete?

        if keys = from_shared_credentials(credentials_ini, profile)
          state.fill_missing(keys, "shared credentials (#{creds_file})")
        else
          state.note("shared credentials (miss)")
        end
      end

      private def apply_login_cache(
        state : ResolutionState,
        config_ini : Hash(String, Hash(String, String)),
        profile : String,
        login_dir : Path,
      ) : Nil
        return if state.complete?

        if keys = from_login_cache(config_ini, profile, login_dir)
          state.replace_with(keys, "aws login cache")
        else
          state.note("aws login cache (miss/expired)")
        end
      end

      private def apply_sso(
        state : ResolutionState,
        config_ini : Hash(String, Hash(String, String)),
        profile : String,
        sso_dir : Path,
      ) : Nil
        return if state.complete?

        sso = sso_profile_config(config_ini, profile)
        unless sso
          state.note("IAM Identity Center SSO (not configured)")
          return
        end

        access_token = read_sso_access_token(sso.start_url, sso_dir)
        unless access_token
          raise ArgumentError.new(
            "IAM Identity Center SSO profile #{profile.inspect} is configured " \
            "but no valid cached access token was found under #{sso_dir}. " \
            "Run `aws sso login --profile #{profile}` and retry."
          )
        end

        keys = fetch_sso_role_credentials(sso, access_token)
        unless keys
          raise ArgumentError.new(
            "IAM Identity Center SSO GetRoleCredentials failed for profile " \
            "#{profile.inspect} (account=#{sso.account_id}, role=#{sso.role_name}, " \
            "sso_region=#{sso.sso_region}). Re-run `aws sso login --profile #{profile}` " \
            "or check the role assignment."
          )
        end

        state.replace_with(keys, "IAM Identity Center SSO")
      end

      private def apply_imds(state : ResolutionState, enable_imds : Bool?) : Nil
        return if state.complete?
        return unless imds_enabled?(enable_imds)

        if keys = from_imds
          state.replace_with(keys, "IMDS")
        else
          state.note("IMDS (unavailable)")
        end
      end

      # --- Shared credentials file -------------------------------------------

      private def from_shared_credentials(
        ini : Hash(String, Hash(String, String)),
        profile : String,
      ) : ResolvedKeys?
        section = ini[profile]?
        return nil unless section

        access = present(section["aws_access_key_id"]?)
        secret = present(section["aws_secret_access_key"]?)
        return nil if access.nil? || secret.nil?

        ResolvedKeys.new(
          access,
          secret,
          present(section["aws_session_token"]?),
        )
      end

      # --- AWS CLI `aws login` cache -----------------------------------------
      #
      # Config profile sets `login_session = arn:aws:iam::ACCOUNT:…`.
      # Cache file: `~/.aws/login/cache/{sha256(login_session)}.json`
      # Shape (stable enough for CLI v2 `aws login`):
      #   { "accessToken": {
      #       "accessKeyId", "secretAccessKey", "sessionToken", "expiresAt"
      #     }, … }

      private def from_login_cache(
        config_ini : Hash(String, Hash(String, String)),
        profile : String,
        login_dir : Path,
      ) : ResolvedKeys?
        section = config_section(config_ini, profile)
        return nil unless section

        login_session = present(section["login_session"]?)
        return nil unless login_session

        digest = Digest::SHA256.hexdigest(login_session)
        path = login_dir / "#{digest}.json"
        return nil unless File.exists?(path)

        read_login_cache_file(path)
      end

      private def read_login_cache_file(path : Path) : ResolvedKeys?
        root = JSON.parse(File.read(path))
        token = root["accessToken"]?
        return nil unless token

        access = present(token["accessKeyId"]?.try(&.as_s?))
        secret = present(token["secretAccessKey"]?.try(&.as_s?))
        session = present(token["sessionToken"]?.try(&.as_s?))
        expires_at = token["expiresAt"]?.try(&.as_s?)
        return nil if access.nil? || secret.nil?

        if expires_at
          exp = Time.parse_rfc3339(expires_at)
          return nil if Time.utc >= exp
        end

        ResolvedKeys.new(access, secret, session)
      rescue JSON::ParseException | Time::Format::Error | KeyError | TypeCastError
        nil
      end

      # --- IAM Identity Center (SSO) ----------------------------------------
      #
      # Profile forms supported:
      #   Legacy (keys on the profile):
      #     sso_start_url, sso_region, sso_account_id, sso_role_name
      #   Modern (shared session):
      #     sso_session = NAME
      #     sso_account_id, sso_role_name
      #     [sso-session NAME] sso_start_url, sso_region
      #
      # Token cache (after `aws sso login`):
      #   ~/.aws/sso/cache/{sha1(start_url)}.json
      #   { "accessToken": "...", "expiresAt": "RFC3339", ... }
      #
      # Role credentials:
      #   GET https://portal.sso.{sso_region}.amazonaws.com/federation/credentials
      #       ?role_name=…&account_id=…
      #   Header: x-amz-sso_bearer_token: {accessToken}

      private def sso_profile_config(
        config_ini : Hash(String, Hash(String, String)),
        profile : String,
      ) : SsoProfileConfig?
        section = config_section(config_ini, profile)
        return nil unless section

        account_id = present(section["sso_account_id"]?)
        role_name = present(section["sso_role_name"]?)
        return nil if account_id.nil? || role_name.nil?

        start_url : String? = nil
        sso_region : String? = nil

        if session_name = present(section["sso_session"]?)
          session = config_ini["sso-session #{session_name}"]?
          return nil unless session

          start_url = present(session["sso_start_url"]?)
          sso_region = present(session["sso_region"]?)
        else
          start_url = present(section["sso_start_url"]?)
          sso_region = present(section["sso_region"]?)
        end

        return nil if start_url.nil? || sso_region.nil?

        SsoProfileConfig.new(start_url, sso_region, account_id, role_name)
      end

      private def read_sso_access_token(start_url : String, sso_dir : Path) : String?
        digest = Digest::SHA1.hexdigest(start_url)
        path = sso_dir / "#{digest}.json"
        return nil unless File.exists?(path)

        root = JSON.parse(File.read(path))
        # Client-registration cache files also live here; they have no accessToken.
        token = present(root["accessToken"]?.try(&.as_s?))
        return nil unless token

        if expires_at = root["expiresAt"]?.try(&.as_s?)
          exp = parse_sso_time(expires_at)
          return nil if exp && Time.utc >= exp
        end

        token
      rescue JSON::ParseException | KeyError | TypeCastError
        nil
      end

      # SSO cache timestamps are usually RFC3339 with Z; tolerate a few shapes.
      private def parse_sso_time(value : String) : Time?
        Time.parse_rfc3339(value)
      rescue Time::Format::Error
        begin
          Time.parse(value, "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
        rescue Time::Format::Error
          begin
            Time.parse(value, "%Y-%m-%dT%H:%M:%S%z", Time::Location::UTC)
          rescue Time::Format::Error
            nil
          end
        end
      end

      private def fetch_sso_role_credentials(
        sso : SsoProfileConfig,
        access_token : String,
      ) : ResolvedKeys?
        query = URI::Params.build do |form|
          form.add("role_name", sso.role_name)
          form.add("account_id", sso.account_id)
        end
        host = "portal.sso.#{sso.sso_region}.amazonaws.com"
        path = "/federation/credentials?#{query}"
        uri = URI.new(scheme: "https", host: host)

        HTTP::Client.new(uri) do |client|
          client.connect_timeout = SSO_CONNECT_TIMEOUT
          client.read_timeout = SSO_READ_TIMEOUT
          headers = HTTP::Headers{
            "x-amz-sso_bearer_token" => access_token,
            "Accept"                 => "application/json",
          }
          response = client.get(path, headers: headers)
          return nil unless response.success?

          parse_sso_role_credentials_body(response.body)
        end
      rescue IO::Error | Socket::Error | OpenSSL::Error | ArgumentError
        nil
      end

      private def parse_sso_role_credentials_body(body : String) : ResolvedKeys?
        data = JSON.parse(body)
        role = data["roleCredentials"]?
        return nil unless role

        access = present(role["accessKeyId"]?.try(&.as_s?))
        secret = present(role["secretAccessKey"]?.try(&.as_s?))
        session = present(role["sessionToken"]?.try(&.as_s?))
        return nil if access.nil? || secret.nil?

        # expiration is milliseconds since epoch when present
        if exp = role["expiration"]?
          ms = exp.as_i64? || exp.as_i?.try(&.to_i64)
          if ms && Time.utc.to_unix_ms >= ms
            return nil
          end
        end

        ResolvedKeys.new(access, secret, session)
      rescue JSON::ParseException | KeyError | TypeCastError
        nil
      end

      # --- IMDS (EC2 instance metadata) --------------------------------------

      private def imds_enabled?(override : Bool?) : Bool
        return override unless override.nil?

        disabled = ENV["AWS_EC2_METADATA_DISABLED"]?.try(&.downcase)
        !(disabled == "true" || disabled == "1")
      end

      private def from_imds : ResolvedKeys?
        endpoint = present(ENV["AWS_EC2_METADATA_SERVICE_ENDPOINT"]?) || IMDS_DEFAULT_ENDPOINT
        base = URI.parse(endpoint)

        HTTP::Client.new(base) do |client|
          client.connect_timeout = IMDS_CONNECT_TIMEOUT
          client.read_timeout = IMDS_READ_TIMEOUT
          fetch_imds_role_credentials(client)
        end
      rescue IO::Error | Socket::Error | OpenSSL::Error | JSON::ParseException | ArgumentError
        nil
      end

      private def fetch_imds_role_credentials(client : HTTP::Client) : ResolvedKeys?
        imds_token = fetch_imds_token(client)

        role_name = imds_get(client, "/latest/meta-data/iam/security-credentials/", imds_token)
        return nil if role_name.nil? || role_name.empty?

        role = role_name.lines.first?.try(&.strip)
        return nil if role.nil? || role.empty?

        body = imds_get(client, "/latest/meta-data/iam/security-credentials/#{role}", imds_token)
        return nil unless body

        data = JSON.parse(body)
        access = present(data["AccessKeyId"]?.try(&.as_s?))
        secret = present(data["SecretAccessKey"]?.try(&.as_s?))
        session = present(data["Token"]?.try(&.as_s?))
        return nil if access.nil? || secret.nil?

        region = present(imds_get(client, "/latest/meta-data/placement/region", imds_token))
        ResolvedKeys.new(access, secret, session, region)
      end

      private def fetch_imds_token(client : HTTP::Client) : String?
        headers = HTTP::Headers{
          "X-aws-ec2-metadata-token-ttl-seconds" => IMDS_TOKEN_TTL_SECONDS,
        }
        response = client.put("/latest/api/token", headers: headers)
        return nil unless response.success?

        present(response.body)
      rescue IO::Error | Socket::Error
        nil
      end

      private def imds_get(client : HTTP::Client, path : String, token : String?) : String?
        headers = HTTP::Headers.new
        headers["X-aws-ec2-metadata-token"] = token if token

        response = client.get(path, headers: headers)
        return nil unless response.success?

        present(response.body)
      rescue IO::Error | Socket::Error
        nil
      end

      # --- Config / region helpers -------------------------------------------

      private def region_from_config(
        ini : Hash(String, Hash(String, String)),
        profile : String,
      ) : String?
        section = config_section(ini, profile)
        return nil unless section

        present(section["region"]?)
      end

      private def config_section(
        ini : Hash(String, Hash(String, String)),
        profile : String,
      ) : Hash(String, String)?
        # credentials-style bare name first, then config-style "profile name"
        ini[profile]? || ini["profile #{profile}"]?
      end

      private def resolution_error(profile : String, sources_tried : Array(String)) : String
        String.build do |io|
          io << "Could not resolve AWS credentials for Bedrock (profile="
          io << profile.inspect
          io << "). Tried: "
          io << sources_tried.join(", ")
          io << ". Pass aws_access_key/aws_secret_key, set AWS_ACCESS_KEY_ID/"
          io << "AWS_SECRET_ACCESS_KEY, configure ~/.aws/credentials, run "
          io << "`aws login` (login_session cache), configure an IAM Identity "
          io << "Center SSO profile (`aws sso login --profile …`), or use an "
          io << "EC2 instance role."
        end
      end

      # --- Paths / INI -------------------------------------------------------

      private def resolve_home(home : Path | String | Nil) : Path
        case home
        when Path
          home
        when String
          Path.new(home)
        else
          Path.home
        end
      end

      private def path_or(
        explicit : Path | String | Nil,
        env_value : String?,
        default : Path,
      ) : Path
        if explicit.is_a?(Path)
          return explicit
        end
        if explicit.is_a?(String) && !explicit.empty?
          return Path.new(explicit)
        end
        if env_value && !env_value.empty?
          return Path.new(env_value)
        end
        default
      end

      private def present(value : String?) : String?
        return nil if value.nil?
        stripped = value.strip
        stripped.empty? ? nil : stripped
      end

      private def load_ini_file(path : Path) : Hash(String, Hash(String, String))
        return {} of String => Hash(String, String) unless File.exists?(path)

        parse_ini(File.read(path))
      end

      # Minimal INI parser (enough for ~/.aws/credentials and config).
      private def parse_ini(content : String) : Hash(String, Hash(String, String))
        result = {} of String => Hash(String, String)
        current : String? = nil

        content.each_line do |raw|
          line = raw.strip
          next if line.empty? || line.starts_with?('#') || line.starts_with?(';')

          if line.starts_with?('[') && line.ends_with?(']')
            current = line[1...-1].strip
            result[current] ||= {} of String => String
          elsif current
            if eq = line.index('=')
              key = line[0...eq].strip
              value = line[eq + 1..].strip
              result[current][key] = value
            end
          end
        end

        result
      end
    end
  end
end
