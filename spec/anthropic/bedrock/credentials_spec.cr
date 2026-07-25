require "../../spec_helper"
require "file_utils"
require "digest/sha1"
require "digest/sha256"

# Helpers for Bedrock credential resolution specs. Isolate from the machine's
# real AWS files / env; never print secret values.

private def with_clean_aws_env(&)
  keys = %w[
    AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE
    AWS_SHARED_CREDENTIALS_FILE AWS_CONFIG_FILE AWS_LOGIN_CACHE_DIRECTORY
    AWS_SSO_CACHE_DIRECTORY
    AWS_EC2_METADATA_DISABLED AWS_EC2_METADATA_SERVICE_ENDPOINT
  ]
  saved = {} of String => String?
  keys.each do |k|
    saved[k] = ENV[k]?
    ENV.delete(k)
  end
  # Disable IMDS by default so local specs do not probe the link-local hop.
  ENV["AWS_EC2_METADATA_DISABLED"] = "true"
  begin
    yield
  ensure
    keys.each do |k|
      if v = saved[k]
        ENV[k] = v
      else
        ENV.delete(k)
      end
    end
  end
end

private def with_temp_aws_home(&)
  root = File.join(Dir.tempdir, "anthropic-cr-aws-#{Random::Secure.hex(8)}")
  FileUtils.mkdir_p(File.join(root, ".aws", "login", "cache"))
  FileUtils.mkdir_p(File.join(root, ".aws", "sso", "cache"))
  begin
    yield Path.new(root)
  ensure
    FileUtils.rm_rf(root)
  end
end

private def write_aws_file(path : Path | String, content : String)
  FileUtils.mkdir_p(File.dirname(path.to_s))
  File.write(path.to_s, content)
end

describe Anthropic::Bedrock::CredentialsResolver do
  describe "explicit constructor args" do
    it "uses explicit keys and region" do
      with_clean_aws_env do
        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          aws_access_key: "AKIAEXPLICIT",
          aws_secret_key: "secret-explicit",
          aws_session_token: "token-explicit",
          aws_region: "eu-west-1",
          enable_imds: false,
          home: "/nonexistent-home-#{Random::Secure.hex(4)}",
        )
        creds.access_key_id.should eq("AKIAEXPLICIT")
        creds.secret_access_key.should eq("secret-explicit")
        creds.session_token.should eq("token-explicit")
        creds.region.should eq("eu-west-1")
      end
    end
  end

  describe "environment variables" do
    it "resolves from AWS_* env vars" do
      with_clean_aws_env do
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "secret-from-env"
        ENV["AWS_SESSION_TOKEN"] = "session-from-env"
        ENV["AWS_REGION"] = "ap-southeast-2"

        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          enable_imds: false,
          home: "/nonexistent-home-#{Random::Secure.hex(4)}",
        )
        creds.access_key_id.should eq("AKIAFROMENV")
        creds.secret_access_key.should eq("secret-from-env")
        creds.session_token.should eq("session-from-env")
        creds.region.should eq("ap-southeast-2")
      end
    end

    it "prefers AWS_REGION over AWS_DEFAULT_REGION" do
      with_clean_aws_env do
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "secret-from-env"
        ENV["AWS_REGION"] = "us-west-2"
        ENV["AWS_DEFAULT_REGION"] = "us-east-1"

        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          enable_imds: false,
          home: "/nonexistent-home-#{Random::Secure.hex(4)}",
        )
        creds.region.should eq("us-west-2")
      end
    end

    it "falls back to AWS_DEFAULT_REGION" do
      with_clean_aws_env do
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "secret-from-env"
        ENV["AWS_DEFAULT_REGION"] = "ca-central-1"

        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          enable_imds: false,
          home: "/nonexistent-home-#{Random::Secure.hex(4)}",
        )
        creds.region.should eq("ca-central-1")
      end
    end

    it "prefers explicit args over environment" do
      with_clean_aws_env do
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "secret-from-env"
        ENV["AWS_REGION"] = "us-west-2"

        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          aws_access_key: "AKIAEXPLICIT",
          aws_secret_key: "secret-explicit",
          aws_region: "eu-central-1",
          enable_imds: false,
          home: "/nonexistent-home-#{Random::Secure.hex(4)}",
        )
        creds.access_key_id.should eq("AKIAEXPLICIT")
        creds.region.should eq("eu-central-1")
      end
    end
  end

  describe "shared credentials + config files" do
    it "loads keys from credentials file and region from config" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          write_aws_file(home / ".aws" / "credentials", <<-INI)
            [default]
            aws_access_key_id = AKIADEFAULT
            aws_secret_access_key = secret-default
            aws_session_token = session-default

            [myprofile]
            aws_access_key_id = AKIAPROFILE
            aws_secret_access_key = secret-profile
          INI
          write_aws_file(home / ".aws" / "config", <<-INI)
            [default]
            region = us-east-1

            [profile myprofile]
            region = eu-west-1
          INI

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "myprofile",
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("AKIAPROFILE")
          creds.secret_access_key.should eq("secret-profile")
          creds.session_token.should be_nil
          creds.region.should eq("eu-west-1")
        end
      end
    end

    it "uses AWS_PROFILE when aws_profile is omitted" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          write_aws_file(home / ".aws" / "credentials", <<-INI)
            [envprofile]
            aws_access_key_id = AKIAENVPROF
            aws_secret_access_key = secret-envprof
          INI
          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile envprofile]
            region = sa-east-1
          INI
          ENV["AWS_PROFILE"] = "envprofile"

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("AKIAENVPROF")
          creds.region.should eq("sa-east-1")
        end
      end
    end

    it "accepts explicit credentials_path and config_path" do
      with_clean_aws_env do
        dir = File.join(Dir.tempdir, "anthropic-cr-paths-#{Random::Secure.hex(6)}")
        FileUtils.mkdir_p(dir)
        creds_path = File.join(dir, "my-creds")
        config_path = File.join(dir, "my-config")
        begin
          write_aws_file(creds_path, <<-INI)
            [custom]
            aws_access_key_id = AKIACUSTOM
            aws_secret_access_key = secret-custom
            aws_session_token = tok-custom
          INI
          write_aws_file(config_path, <<-INI)
            [profile custom]
            region = af-south-1
          INI

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "custom",
            credentials_path: creds_path,
            config_path: config_path,
            enable_imds: false,
            home: "/nonexistent-home-#{Random::Secure.hex(4)}",
          )
          creds.access_key_id.should eq("AKIACUSTOM")
          creds.session_token.should eq("tok-custom")
          creds.region.should eq("af-south-1")
        ensure
          FileUtils.rm_rf(dir)
        end
      end
    end

    it "defaults region to us-east-1 when unset" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          write_aws_file(home / ".aws" / "credentials", <<-INI)
            [default]
            aws_access_key_id = AKIADEFAULT
            aws_secret_access_key = secret-default
          INI

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            enable_imds: false,
            home: home,
          )
          creds.region.should eq("us-east-1")
        end
      end
    end
  end

  describe "aws login cache" do
    it "loads temporary credentials from login cache via login_session" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          login_session = "arn:aws:iam::123456789012:user/dev"
          digest = Digest::SHA256.hexdigest(login_session)
          expires = (Time.utc + 1.hour).to_rfc3339

          write_aws_file(home / ".aws" / "config", <<-INI)
            [default]
            login_session = #{login_session}
            region = us-west-1
          INI
          write_aws_file(home / ".aws" / "login" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": {
                "accessKeyId": "ASIALOGIN",
                "secretAccessKey": "secret-login",
                "sessionToken": "session-login-token",
                "accountId": "123456789012",
                "expiresAt": "#{expires}"
              },
              "tokenType": "urn:aws:params:oauth:token-type:access_token",
              "clientId": "arn:aws:signin:::devtools/same-device"
            }
          JSON

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("ASIALOGIN")
          creds.secret_access_key.should eq("secret-login")
          creds.session_token.should eq("session-login-token")
          creds.region.should eq("us-west-1")
        end
      end
    end

    it "skips expired login cache entries" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          login_session = "arn:aws:iam::123456789012:user/dev"
          digest = Digest::SHA256.hexdigest(login_session)
          expires = (Time.utc - 1.hour).to_rfc3339

          write_aws_file(home / ".aws" / "config", <<-INI)
            [default]
            login_session = #{login_session}
            region = us-west-1
          INI
          write_aws_file(home / ".aws" / "login" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": {
                "accessKeyId": "ASIALOGIN",
                "secretAccessKey": "secret-login",
                "sessionToken": "session-login-token",
                "expiresAt": "#{expires}"
              }
            }
          JSON

          expect_raises(ArgumentError, /Could not resolve AWS credentials/) do
            Anthropic::Bedrock::CredentialsResolver.resolve(
              enable_imds: false,
              home: home,
            )
          end
        end
      end
    end

    it "prefers shared credentials over login cache for the same profile" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          login_session = "arn:aws:iam::123456789012:user/dev"
          digest = Digest::SHA256.hexdigest(login_session)
          expires = (Time.utc + 1.hour).to_rfc3339

          write_aws_file(home / ".aws" / "credentials", <<-INI)
            [default]
            aws_access_key_id = AKIASTATIC
            aws_secret_access_key = secret-static
          INI
          write_aws_file(home / ".aws" / "config", <<-INI)
            [default]
            login_session = #{login_session}
            region = us-east-2
          INI
          write_aws_file(home / ".aws" / "login" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": {
                "accessKeyId": "ASIALOGIN",
                "secretAccessKey": "secret-login",
                "sessionToken": "session-login-token",
                "expiresAt": "#{expires}"
              }
            }
          JSON

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("AKIASTATIC")
          creds.session_token.should be_nil
        end
      end
    end

    it "uses login_cache_dir override" do
      with_clean_aws_env do
        home = File.join(Dir.tempdir, "anthropic-cr-login-#{Random::Secure.hex(6)}")
        cache = File.join(Dir.tempdir, "custom-login-cache-#{Random::Secure.hex(6)}")
        FileUtils.mkdir_p(File.join(home, ".aws"))
        FileUtils.mkdir_p(cache)
        begin
          login_session = "arn:aws:iam::999999999999:root"
          digest = Digest::SHA256.hexdigest(login_session)
          expires = (Time.utc + 2.hours).to_rfc3339

          write_aws_file(File.join(home, ".aws", "config"), <<-INI)
            [profile loginprof]
            login_session = #{login_session}
            region = me-south-1
          INI
          write_aws_file(File.join(cache, "#{digest}.json"), <<-JSON)
            {
              "accessToken": {
                "accessKeyId": "ASIACUSTOM",
                "secretAccessKey": "secret-custom-login",
                "sessionToken": "tok",
                "expiresAt": "#{expires}"
              }
            }
          JSON

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "loginprof",
            login_cache_dir: cache,
            home: home,
            enable_imds: false,
          )
          creds.access_key_id.should eq("ASIACUSTOM")
          creds.region.should eq("me-south-1")
        ensure
          FileUtils.rm_rf(home)
          FileUtils.rm_rf(cache)
        end
      end
    end
  end

  describe "IAM Identity Center SSO" do
    it "resolves via legacy SSO profile + GetRoleCredentials" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          start_url = "https://example.awsapps.com/start"
          digest = Digest::SHA1.hexdigest(start_url)
          expires = (Time.utc + 2.hours).to_rfc3339
          role_exp_ms = (Time.utc + 1.hour).to_unix_ms

          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-legacy]
            sso_start_url = #{start_url}
            sso_region = us-east-1
            sso_account_id = 123456789012
            sso_role_name = AdministratorAccess
            region = eu-west-1
          INI
          write_aws_file(home / ".aws" / "sso" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": "sso-access-token-legacy",
              "expiresAt": "#{expires}",
              "region": "us-east-1",
              "startUrl": "#{start_url}"
            }
          JSON

          WebMock.stub(:get, /portal\.sso\.us-east-1\.amazonaws\.com\/federation\/credentials/).to_return do |request|
            request.headers["x-amz-sso_bearer_token"]?.should eq("sso-access-token-legacy")
            request.query_params["account_id"]?.should eq("123456789012")
            request.query_params["role_name"]?.should eq("AdministratorAccess")
            HTTP::Client::Response.new(200, <<-JSON)
              {
                "roleCredentials": {
                  "accessKeyId": "ASIASSOLEGACY",
                  "secretAccessKey": "secret-sso-legacy",
                  "sessionToken": "session-sso-legacy",
                  "expiration": #{role_exp_ms}
                }
              }
            JSON
          end

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "sso-legacy",
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("ASIASSOLEGACY")
          creds.secret_access_key.should eq("secret-sso-legacy")
          creds.session_token.should eq("session-sso-legacy")
          creds.region.should eq("eu-west-1")
        end
      end
    end

    it "resolves via modern sso_session section" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          start_url = "https://myorg.awsapps.com/start/#"
          digest = Digest::SHA1.hexdigest(start_url)
          expires = (Time.utc + 3.hours).to_rfc3339
          role_exp_ms = (Time.utc + 1.hour).to_unix_ms

          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-modern]
            sso_session = my-sso
            sso_account_id = 999888777666
            sso_role_name = ReadOnlyAccess
            region = us-west-2

            [sso-session my-sso]
            sso_start_url = #{start_url}
            sso_region = us-west-2
            sso_registration_scopes = sso:account:access
          INI
          write_aws_file(home / ".aws" / "sso" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": "sso-access-token-modern",
              "expiresAt": "#{expires}",
              "startUrl": "#{start_url}"
            }
          JSON

          WebMock.stub(:get, /portal\.sso\.us-west-2\.amazonaws\.com\/federation\/credentials/).to_return do |request|
            request.headers["x-amz-sso_bearer_token"]?.should eq("sso-access-token-modern")
            request.query_params["account_id"]?.should eq("999888777666")
            request.query_params["role_name"]?.should eq("ReadOnlyAccess")
            HTTP::Client::Response.new(200, <<-JSON)
              {
                "roleCredentials": {
                  "accessKeyId": "ASIASSOMODERN",
                  "secretAccessKey": "secret-sso-modern",
                  "sessionToken": "session-sso-modern",
                  "expiration": #{role_exp_ms}
                }
              }
            JSON
          end

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "sso-modern",
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("ASIASSOMODERN")
          creds.session_token.should eq("session-sso-modern")
          creds.region.should eq("us-west-2")
        end
      end
    end

    it "raises when SSO is configured but the access token cache is missing" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-nologin]
            sso_start_url = https://example.awsapps.com/start
            sso_region = us-east-1
            sso_account_id = 123456789012
            sso_role_name = Admin
            region = us-east-1
          INI

          expect_raises(ArgumentError, /aws sso login --profile sso-nologin/) do
            Anthropic::Bedrock::CredentialsResolver.resolve(
              aws_profile: "sso-nologin",
              enable_imds: false,
              home: home,
            )
          end
        end
      end
    end

    it "raises when GetRoleCredentials fails" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          start_url = "https://fail.awsapps.com/start"
          digest = Digest::SHA1.hexdigest(start_url)
          expires = (Time.utc + 1.hour).to_rfc3339

          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-fail]
            sso_start_url = #{start_url}
            sso_region = us-east-1
            sso_account_id = 111122223333
            sso_role_name = MissingRole
            region = us-east-1
          INI
          write_aws_file(home / ".aws" / "sso" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": "token",
              "expiresAt": "#{expires}"
            }
          JSON

          WebMock.stub(:get, /portal\.sso\.us-east-1\.amazonaws\.com\/federation\/credentials/).to_return(
            status: 401,
            body: %({"message":"Unauthorized"})
          )

          expect_raises(ArgumentError, /GetRoleCredentials failed/) do
            Anthropic::Bedrock::CredentialsResolver.resolve(
              aws_profile: "sso-fail",
              enable_imds: false,
              home: home,
            )
          end
        end
      end
    end

    it "skips expired SSO access tokens" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          start_url = "https://expired.awsapps.com/start"
          digest = Digest::SHA1.hexdigest(start_url)
          expires = (Time.utc - 1.hour).to_rfc3339

          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-expired]
            sso_start_url = #{start_url}
            sso_region = us-east-1
            sso_account_id = 123456789012
            sso_role_name = Admin
            region = us-east-1
          INI
          write_aws_file(home / ".aws" / "sso" / "cache" / "#{digest}.json", <<-JSON)
            {
              "accessToken": "stale-token",
              "expiresAt": "#{expires}"
            }
          JSON

          expect_raises(ArgumentError, /no valid cached access token/) do
            Anthropic::Bedrock::CredentialsResolver.resolve(
              aws_profile: "sso-expired",
              enable_imds: false,
              home: home,
            )
          end
        end
      end
    end

    it "prefers shared credentials over SSO for the same profile" do
      with_clean_aws_env do
        with_temp_aws_home do |home|
          write_aws_file(home / ".aws" / "credentials", <<-INI)
            [sso-and-static]
            aws_access_key_id = AKIASTATICFIRST
            aws_secret_access_key = secret-static-first
          INI
          write_aws_file(home / ".aws" / "config", <<-INI)
            [profile sso-and-static]
            sso_start_url = https://example.awsapps.com/start
            sso_region = us-east-1
            sso_account_id = 123456789012
            sso_role_name = Admin
            region = us-east-1
          INI

          creds = Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "sso-and-static",
            enable_imds: false,
            home: home,
          )
          creds.access_key_id.should eq("AKIASTATICFIRST")
          creds.session_token.should be_nil
        end
      end
    end
  end

  describe "errors" do
    it "raises a clear ArgumentError when nothing resolves" do
      with_clean_aws_env do
        expect_raises(ArgumentError, /Could not resolve AWS credentials for Bedrock/) do
          Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "missing-profile",
            enable_imds: false,
            home: "/nonexistent-home-#{Random::Secure.hex(4)}",
          )
        end
      end
    end

    it "mentions profile and sources in the error message" do
      with_clean_aws_env do
        begin
          Anthropic::Bedrock::CredentialsResolver.resolve(
            aws_profile: "ghost",
            enable_imds: false,
            home: "/nonexistent-home-#{Random::Secure.hex(4)}",
          )
          fail "expected ArgumentError"
        rescue e : ArgumentError
          e.message.not_nil!.should contain("ghost")
          e.message.not_nil!.should match(/shared credentials|login cache|aws login|Identity Center|SSO/i)
        end
      end
    end
  end

  describe "IMDS guard" do
    it "does not hang when IMDS is disabled" do
      with_clean_aws_env do
        ENV["AWS_EC2_METADATA_DISABLED"] = "true"
        expect_raises(ArgumentError, /Could not resolve/) do
          Anthropic::Bedrock::CredentialsResolver.resolve(
            home: "/nonexistent-home-#{Random::Secure.hex(4)}",
          )
        end
      end
    end
  end

  # Live resolution against the developer's machine (gracefully skips if
  # unavailable). Never asserts or prints secret material.
  describe "live AWS profile resolution" do
    it "resolves AWS_PROFILE=anthropic-cr-bedrock when configured" do
      profile = "anthropic-cr-bedrock"
      creds_path = Path.home / ".aws" / "credentials"
      unless File.exists?(creds_path) && File.read(creds_path).includes?("[#{profile}]")
        puts "  [skip] shared credentials profile #{profile.inspect} not present"
        next
      end

      saved = {} of String => String?
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE].each do |k|
        saved[k] = ENV[k]?
        ENV.delete(k)
      end
      begin
        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          aws_profile: profile,
          enable_imds: false,
        )
        creds.access_key_id.should_not be_empty
        creds.secret_access_key.should_not be_empty
        creds.region.should_not be_empty
        # access key id shape only (AKIA… / ASIA…) — no secret dump
        creds.access_key_id.should match(/^[A-Z0-9]{16,}$/)
      ensure
        saved.each do |k, v|
          if v
            ENV[k] = v
          else
            ENV.delete(k)
          end
        end
      end
    end

    it "resolves default profile from aws login cache when unexpired" do
      config_path = Path.home / ".aws" / "config"
      unless File.exists?(config_path)
        puts "  [skip] ~/.aws/config not present"
        next
      end
      config_body = File.read(config_path)
      unless config_body.includes?("login_session")
        puts "  [skip] no login_session in ~/.aws/config"
        next
      end

      saved = {} of String => String?
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE].each do |k|
        saved[k] = ENV[k]?
        ENV.delete(k)
      end
      begin
        creds = Anthropic::Bedrock::CredentialsResolver.resolve(
          aws_profile: "default",
          enable_imds: false,
        )
        creds.access_key_id.should_not be_empty
        creds.secret_access_key.should_not be_empty
        creds.session_token.should_not be_nil
      rescue ArgumentError
        puts "  [skip] default profile login cache missing or expired (run `aws login`)"
      ensure
        saved.each do |k, v|
          if v
            ENV[k] = v
          else
            ENV.delete(k)
          end
        end
      end
    end
  end
end
