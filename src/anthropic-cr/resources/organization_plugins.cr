module Anthropic
  class Client
    # POST multipart form data with a single explicitly named file field
    # (for endpoints such as marketplace archive validation using `"archive"`).
    def post_multipart_field(
      path : String,
      field_name : String,
      file : FileUpload,
      form_fields : Hash(String, String)? = nil,
      extra_headers : Hash(String, String)? = nil,
      beta : Bool = false,
    ) : HTTP::Client::Response
      with_request_context(nil, beta) do
        ctx_timeout, _ = current_request_context
        uri = URI.parse(@base_url)
        full_path = apply_default_query(path)

        with_http_client(uri, timeout: ctx_timeout) do |client|
          body_io = IO::Memory.new
          builder = HTTP::FormData::Builder.new(body_io)

          form_fields.try &.each do |name, value|
            builder.field(name, value)
          end

          metadata = HTTP::FormData::FileMetadata.new(filename: file.filename || "archive.zip")
          file_headers = HTTP::Headers{"Content-Type" => file.content_type}
          builder.file(field_name, file.io, metadata, headers: file_headers)
          builder.finish

          hdrs = headers(extra_headers, content_type: builder.content_type, method: "POST")
          body_io.rewind
          response = client.post(full_path, headers: hdrs, body: body_io)
          handle_error(response) unless response.success?
          return response
        end
      end

      raise APIError.new("Request failed")
    rescue ex : IO::TimeoutError
      raise APITimeoutError.new("Request timed out", cause: ex)
    rescue ex : IO::Error | Socket::Error | OpenSSL::Error
      raise APIConnectionError.new("Connection failed: #{ex.message}", cause: ex)
    end
  end

  # Organization CE Plugins API (beta).
  #
  # All requests automatically include `anthropic-beta: ce-plugins-2026-09-01`.
  class BetaOrganizationPlugins
    def initialize(@client : Client)
    end

    def versions : BetaOrganizationPluginVersions
      BetaOrganizationPluginVersions.new(@client)
    end

    def installation_settings : BetaOrganizationPluginInstallationSettings
      BetaOrganizationPluginInstallationSettings.new(@client)
    end

    def shares : BetaOrganizationPluginShares
      BetaOrganizationPluginShares.new(@client)
    end

    # Upload and create a plugin (`POST /v1/organizations/plugins`).
    def create(
      files : Array(FileUpload),
      marketplace_id : String? = nil,
      release_notes : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPlugin
      form_fields = {} of String => String
      form_fields["marketplace_id"] = marketplace_id if marketplace_id
      form_fields["release_notes"] = release_notes if release_notes

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post_multipart_files(
        "/v1/organizations/plugins",
        files,
        form_fields: form_fields.empty? ? nil : form_fields,
        extra_headers: headers
      )
      BetaPlugin.from_json(response.body)
    end

    # Retrieve a plugin by ID (`GET /v1/organizations/plugins/{plugin_id}`).
    def retrieve(
      plugin_id : String,
      organization_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPlugin
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "organization_id", organization_id)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}",
        query,
        extra_headers: headers,
        beta: true
      )
      BetaPlugin.from_json(response.body)
    end

    # Update a plugin's served version (`POST /v1/organizations/plugins/{plugin_id}`).
    def update(
      plugin_id : String,
      served_version_id : String,
      betas : Array(String) = [] of String,
    ) : BetaPlugin
      body = {"served_version_id" => JSON::Any.new(served_version_id)}
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}",
        body,
        extra_headers: headers,
        beta: true
      )
      BetaPlugin.from_json(response.body)
    end

    # List plugins with optional timestamp and ownership filters.
    def list(
      created_at_gt : String? = nil,
      created_at_gte : String? = nil,
      created_at_lt : String? = nil,
      created_at_lte : String? = nil,
      limit : Int32? = nil,
      marketplace_id : String? = nil,
      organization_id : String? = nil,
      owner_type : String? = nil,
      owner_user_id : String? = nil,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaPlugin)
      query = {} of String => (String | Array(String))
      add_created_at_filters(query, created_at_gt, created_at_gte, created_at_lt, created_at_lte)
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "marketplace_id", marketplace_id)
      OrganizationHelpers.set_query(query, "organization_id", organization_id)
      OrganizationHelpers.set_query(query, "owner_type", owner_type)
      OrganizationHelpers.set_query(query, "owner_user_id", owner_user_id)
      OrganizationHelpers.set_query(query, "page", page)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get("/v1/organizations/plugins", query, extra_headers: headers, beta: true)
      PageCursor(BetaPlugin).from_json(response.body)
    end

    # Delete a plugin (`DELETE /v1/organizations/plugins/{plugin_id}`).
    def delete(
      plugin_id : String,
      betas : Array(String) = [] of String,
    ) : BetaDeletedPlugin
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.delete(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}",
        extra_headers: headers,
        beta: true
      )
      BetaDeletedPlugin.from_json(response.body)
    end

    private def add_created_at_filters(
      query : OrganizationHelpers::QueryHash,
      gt : String?,
      gte : String?,
      lt : String?,
      lte : String?,
    ) : Nil
      OrganizationHelpers.set_query(query, "created_at[gt]", gt)
      OrganizationHelpers.set_query(query, "created_at[gte]", gte)
      OrganizationHelpers.set_query(query, "created_at[lt]", lt)
      OrganizationHelpers.set_query(query, "created_at[lte]", lte)
    end
  end

  # Plugin versions (beta).
  class BetaOrganizationPluginVersions
    def initialize(@client : Client)
    end

    # Upload a new version of a plugin (`POST /v1/organizations/plugins/{plugin_id}/versions`).
    def create(
      plugin_id : String,
      files : Array(FileUpload),
      release_notes : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPluginVersion
      form_fields = {} of String => String
      form_fields["release_notes"] = release_notes if release_notes

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post_multipart_files(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/versions",
        files,
        form_fields: form_fields.empty? ? nil : form_fields,
        extra_headers: headers
      )
      BetaPluginVersion.from_json(response.body)
    end

    # Retrieve a plugin version (`GET /v1/organizations/plugins/{plugin_id}/versions/{version}`).
    def retrieve(
      plugin_id : String,
      version : String,
      organization_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPluginVersion
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "organization_id", organization_id)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/versions/#{Anthropic.encode_path_segment(version)}",
        query,
        extra_headers: headers,
        beta: true
      )
      BetaPluginVersion.from_json(response.body)
    end

    # List versions of a plugin (`GET /v1/organizations/plugins/{plugin_id}/versions`).
    def list(
      plugin_id : String,
      limit : Int32? = nil,
      organization_id : String? = nil,
      page : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaPluginVersion)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "organization_id", organization_id)
      OrganizationHelpers.set_query(query, "page", page)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/versions",
        query,
        extra_headers: headers,
        beta: true
      )
      PageCursor(BetaPluginVersion).from_json(response.body)
    end

    # Download binary archive content of a plugin version.
    def download(
      plugin_id : String,
      version : String,
      organization_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : IO::Memory
      path = "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/versions/#{Anthropic.encode_path_segment(version)}/content"
      if org_id = organization_id
        params = URI::Params.new
        params["organization_id"] = org_id
        path = "#{path}?#{params}"
      end

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas) || {} of String => String
      headers["accept"] = "application/binary"
      @client.get_raw(path, extra_headers: headers)
    end
  end

  # Plugin installation settings (beta).
  class BetaOrganizationPluginInstallationSettings
    def initialize(@client : Client)
    end

    # List installation settings for a plugin.
    def list(
      plugin_id : String,
      limit : Int32? = nil,
      organization_id : String? = nil,
      page : String? = nil,
      target_type : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaPluginInstallationSetting)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "organization_id", organization_id)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "target_type", target_type)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/installation_settings",
        query,
        extra_headers: headers,
        beta: true
      )
      PageCursor(BetaPluginInstallationSetting).from_json(response.body)
    end

    # Set an organization-wide or RBAC-group installation preference for a plugin.
    def set(
      plugin_id : String,
      target : String,
      installation_preference : String,
      betas : Array(String) = [] of String,
    ) : BetaPluginInstallationSetting
      body = {"installation_preference" => JSON::Any.new(installation_preference)}
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/installation_settings/#{Anthropic.encode_path_segment(target)}",
        body,
        extra_headers: headers,
        beta: true
      )
      BetaPluginInstallationSetting.from_json(response.body)
    end

    # Remove a target's installation setting override for a plugin.
    def remove(
      plugin_id : String,
      target : String,
      betas : Array(String) = [] of String,
    ) : BetaDeletedPluginInstallationSetting
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.delete(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/installation_settings/#{Anthropic.encode_path_segment(target)}",
        extra_headers: headers,
        beta: true
      )
      BetaDeletedPluginInstallationSetting.from_json(response.body)
    end
  end

  # Plugin shares (beta).
  class BetaOrganizationPluginShares
    def initialize(@client : Client)
    end

    # List shares granted for a plugin.
    def list(
      plugin_id : String,
      limit : Int32? = nil,
      organization_id : String? = nil,
      page : String? = nil,
      target_type : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaPluginShare)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "organization_id", organization_id)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "target_type", target_type)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugins/#{Anthropic.encode_path_segment(plugin_id)}/shares",
        query,
        extra_headers: headers,
        beta: true
      )
      PageCursor(BetaPluginShare).from_json(response.body)
    end
  end

  # Organization plugin marketplaces API (beta).
  #
  # All requests automatically include `anthropic-beta: ce-plugins-2026-09-01`.
  class BetaOrganizationPluginMarketplaces
    def initialize(@client : Client)
    end

    # Retrieve a plugin marketplace by ID.
    def retrieve(
      marketplace_id : String,
      organization_id : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPluginMarketplace
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "organization_id", organization_id)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get(
        "/v1/organizations/plugin_marketplaces/#{Anthropic.encode_path_segment(marketplace_id)}",
        query,
        extra_headers: headers,
        beta: true
      )
      BetaPluginMarketplace.from_json(response.body)
    end

    # Update a plugin marketplace's default installation preference.
    def update(
      marketplace_id : String,
      default_installation_preference : String,
      betas : Array(String) = [] of String,
    ) : BetaPluginMarketplace
      body = {"default_installation_preference" => JSON::Any.new(default_installation_preference)}
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post(
        "/v1/organizations/plugin_marketplaces/#{Anthropic.encode_path_segment(marketplace_id)}",
        body,
        extra_headers: headers,
        beta: true
      )
      BetaPluginMarketplace.from_json(response.body)
    end

    # List plugin marketplaces.
    def list(
      limit : Int32? = nil,
      organization_id : String? = nil,
      owner_type : String? = nil,
      page : String? = nil,
      source : String? = nil,
      betas : Array(String) = [] of String,
    ) : PageCursor(BetaPluginMarketplace)
      query = {} of String => (String | Array(String))
      OrganizationHelpers.set_query(query, "limit", limit)
      OrganizationHelpers.set_query(query, "organization_id", organization_id)
      OrganizationHelpers.set_query(query, "owner_type", owner_type)
      OrganizationHelpers.set_query(query, "page", page)
      OrganizationHelpers.set_query(query, "source", source)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.get("/v1/organizations/plugin_marketplaces", query, extra_headers: headers, beta: true)
      PageCursor(BetaPluginMarketplace).from_json(response.body)
    end

    # Validate a marketplace archive uploaded as multipart `"archive"` (`POST .../validate_archive`).
    def validate_archive(
      archive : FileUpload | Path | String | IO,
      betas : Array(String) = [] of String,
    ) : BetaPluginMarketplaceValidationReport
      upload = normalize_archive_upload(archive)
      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post_multipart_field(
        "/v1/organizations/plugin_marketplaces/validate_archive",
        "archive",
        upload,
        extra_headers: headers,
        beta: true
      )
      BetaPluginMarketplaceValidationReport.from_json(response.body)
    end

    # Validate a Git repository as a plugin marketplace (`POST .../validate_repository`).
    def validate_repository(
      repository_url : String,
      ref : String? = nil,
      betas : Array(String) = [] of String,
    ) : BetaPluginMarketplaceValidationReport
      body = {"repository_url" => JSON::Any.new(repository_url)} of String => JSON::Any
      OrganizationHelpers.set_json_opt(body, "ref", ref)

      headers = OrganizationHelpers.beta_headers([CE_PLUGINS_BETA], betas)
      response = @client.post(
        "/v1/organizations/plugin_marketplaces/validate_repository",
        body,
        extra_headers: headers,
        beta: true
      )
      BetaPluginMarketplaceValidationReport.from_json(response.body)
    end

    private def normalize_archive_upload(archive : FileUpload | Path | String | IO) : FileUpload
      case archive
      when FileUpload
        archive.filename ? archive : FileUpload.new(archive.io, filename: "archive.zip", content_type: archive.content_type)
      when Path
        FileUpload.from_path(archive.to_s)
      when String
        FileUpload.from_path(archive)
      when IO
        FileUpload.new(archive, filename: "archive.zip")
      else
        raise ArgumentError.new("Unsupported archive input")
      end
    end
  end
end
