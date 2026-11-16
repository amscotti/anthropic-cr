require "../spec_helper"

private def save_env(*names : String, &)
  saved = {} of String => String?
  names.each { |name| saved[name] = ENV[name]? }
  begin
    yield
  ensure
    saved.each do |name, value|
      if value
        ENV[name] = value
      else
        ENV.delete(name)
      end
    end
  end
end

describe "v0.12.0 core foundation (2026-10-21)" do
  describe "API version and authentication semantics" do
    it "bumps API_VERSION to 2026-10-21 and sends Bearer auth instead of x-api-key" do
      Anthropic::Client::API_VERSION.should eq("2026-10-21")

      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)
      client = Anthropic::Client.new(api_key: "sk-ant-bearer-test")
      client.models.list

      headers = capture.headers.not_nil!
      headers["anthropic-version"].should eq("2026-10-21")
      headers["authorization"].should eq("Bearer sk-ant-bearer-test")
      headers.has_key?("x-api-key").should be_false
    end

    it "skips authorization header when api_key or auth_token is empty string" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "")
      client.models.list
      capture.headers.not_nil!.has_key?("authorization").should be_false

      token_client = Anthropic::Client.new(auth_token: "")
      token_client.models.list
      capture.headers.not_nil!.has_key?("authorization").should be_false
    end

    it "raises ArgumentError when both api_key and auth_token are explicitly passed" do
      expect_raises(ArgumentError) do
        Anthropic::Client.new(api_key: "sk-1", auth_token: "tok-1")
      end

      client = Anthropic::Client.new(api_key: "sk-1")
      expect_raises(ArgumentError) do
        client.with_options(api_key: "sk-2", auth_token: "tok-2")
      end
    end

    it "emits a one-shot warning and prefers ANTHROPIC_API_KEY when both env vars are set" do
      save_env("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN") do
        ENV["ANTHROPIC_API_KEY"] = "sk-dual-key"
        ENV["ANTHROPIC_AUTH_TOKEN"] = "tok-dual"
        Anthropic::Client.reset_dual_credentials_warning!
        io = IO::Memory.new
        Anthropic::Client.warning_io = io
        begin
          capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

          c1 = Anthropic::Client.new
          c1.models.list
          capture.headers.not_nil!["authorization"].should eq("Bearer sk-dual-key")

          c2 = Anthropic::Client.new
          c2.api_key.should eq("sk-dual-key")
          c2.auth_token.should be_nil

          warning_text = io.to_s
          warning_text.should contain("Anthropic: ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are both set. Using ANTHROPIC_API_KEY.")
          warning_text.scan("ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN").size.should eq(1)
        ensure
          Anthropic::Client.warning_io = nil
        end
      end
    end

    it "supports with_options credential clearing and switching without falling back to ENV" do
      save_env("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN") do
        ENV["ANTHROPIC_API_KEY"] = "sk-env-fallback"
        ENV["ANTHROPIC_AUTH_TOKEN"] = "tok-env-fallback"

        base = Anthropic::Client.new(api_key: "sk-initial")

        # Switching api_key -> auth_token clears api_key
        as_token = base.with_options(auth_token: "tok-switched")
        as_token.auth_token.should eq("tok-switched")
        as_token.api_key.should be_nil

        # Switching auth_token -> api_key clears auth_token
        back_to_key = as_token.with_options(api_key: "sk-switched")
        back_to_key.api_key.should eq("sk-switched")
        back_to_key.auth_token.should be_nil

        # Explicitly clearing credentials does NOT fall back to env and omits Authorization header
        cleared = base.with_options(api_key: nil)
        cleared.api_key.should be_nil
        cleared.auth_token.should be_nil

        capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)
        cleared.models.list
        capture.headers.not_nil!.has_key?("authorization").should be_false
      end
    end
  end

  describe "timeout tracking, x-stainless-timeout, client headers, and redirects" do
    it "tracks timeout_overridden? and sends x-stainless-timeout when active" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20", Fixtures::Responses::MODEL_LIST)

      default_client = Anthropic::Client.new(api_key: "sk-test")
      default_client.timeout.should eq(600.seconds)
      default_client.timeout_overridden?.should be_false
      default_client.models.list
      capture.headers.not_nil!["x-stainless-timeout"].should eq("600")

      custom_client = Anthropic::Client.new(api_key: "sk-test", timeout: 45.seconds)
      custom_client.timeout.should eq(45.seconds)
      custom_client.timeout_overridden?.should be_true
      custom_client.models.list
      capture.headers.not_nil!["x-stainless-timeout"].should eq("45")

      # Explicit timeout: nil disables default 600s and omits x-stainless-timeout unless overridden per-request
      nil_timeout_client = Anthropic::Client.new(api_key: "sk-test", timeout: nil)
      nil_timeout_client.timeout.should be_nil
      nil_timeout_client.timeout_overridden?.should be_true
      nil_timeout_client.models.list
      nil_timeout_client.supports_message_threads?.should be_true
      capture.headers.not_nil!.has_key?("x-stainless-timeout").should be_false

      nil_timeout_client.get("/v1/models", {"limit" => "20"}, timeout: 12.seconds)
      capture.headers.not_nil!["x-stainless-timeout"].should eq("12")
    end

    it "preserves client-level anthropic-workspace-id and anthropic-user-profile-id when per-request params are nil" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)

      client = Anthropic::Client.new(
        api_key: "sk-test",
        workspace_id: "ws_client",
        user_profile_id: "uprof_client",
      )

      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 32,
        messages: [{role: "user", content: "hi"}],
        workspace_id: nil,
        user_profile_id: nil,
      )
      headers = capture.headers.not_nil!
      headers["anthropic-workspace-id"].should eq("ws_client")
      headers["anthropic-user-profile-id"].should eq("uprof_client")

      client.messages.create(
        model: "claude-sonnet-4-6",
        max_tokens: 32,
        messages: [{role: "user", content: "hi"}],
        workspace_id: "ws_req",
        user_profile_id: "uprof_req",
      )
      override_headers = capture.headers.not_nil!
      override_headers["anthropic-workspace-id"].should eq("ws_req")
      override_headers["anthropic-user-profile-id"].should eq("uprof_req")
    end

    it "strips sensitive headers on cross-origin redirects while preserving them same-origin" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/redirect-cross")
        .to_return(status: 302, headers: {"Location" => "https://cdn.other.example.com/target"})

      cross_headers : HTTP::Headers? = nil
      WebMock.stub(:get, "https://cdn.other.example.com/target")
        .to_return do |request|
          cross_headers = request.headers.dup
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MODEL_LIST, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      client = Anthropic::Client.new(
        api_key: "sk-secret",
        default_headers: {
          "cookie"              => "session=secret",
          "proxy-authorization" => "Basic secret",
          "x-api-key"           => "legacy-secret",
          "x-trace"             => "keep-me",
        },
      )

      client.get("/v1/redirect-cross")
      hdrs = cross_headers.not_nil!
      hdrs["authorization"]?.should be_nil
      hdrs["x-api-key"]?.should be_nil
      hdrs["cookie"]?.should be_nil
      hdrs["proxy-authorization"]?.should be_nil
      hdrs["x-trace"].should eq("keep-me")

      WebMock.stub(:get, "https://api.anthropic.com/v1/redirect-same")
        .to_return(status: 307, headers: {"Location" => "/v1/same-target"})

      same_headers : HTTP::Headers? = nil
      WebMock.stub(:get, "https://api.anthropic.com/v1/same-target")
        .to_return do |request|
          same_headers = request.headers.dup
          HTTP::Client::Response.new(200, body: Fixtures::Responses::MODEL_LIST, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      client.get("/v1/redirect-same")
      same = same_headers.not_nil!
      same["authorization"].should eq("Bearer sk-secret")
      same["cookie"].should eq("session=secret")
    end

    it "propagates beta? to APIRequest so BetaRefusalFallbackMiddleware only targets beta message calls" do
      middleware = Anthropic::BetaRefusalFallbackMiddleware.new(
        [Anthropic::FallbackParam.new(model: Anthropic::Model::CLAUDE_OPUS_4_8)]
      )
      client = Anthropic::Client.new(api_key: "sk-test", middleware: [middleware])

      # GA call: beta? is false -> refusal fallback middleware does NOT activate
      ga_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client.messages.create(model: "claude-sonnet-4-6", max_tokens: 16, messages: [{role: "user", content: "hi"}])
      ga_headers = ga_capture.headers.not_nil!
      ga_headers["x-stainless-helper"]?.should be_nil

      # Beta call: beta? is true -> refusal fallback middleware activates without ?beta=true
      WebMock.reset
      beta_capture = stub_and_capture(:post, "https://api.anthropic.com/v1/messages", Fixtures::Responses::MESSAGE_BASIC)
      client.beta.messages.create(model: "claude-sonnet-4-6", max_tokens: 16, messages: [{role: "user", content: "hi"}])
      beta_capture.path.should eq("/v1/messages")
      beta_headers = beta_capture.headers.not_nil!
      beta_headers["x-stainless-helper"].should contain(Anthropic::StainlessHelper::FALLBACK_REFUSAL_MIDDLEWARE)
    end
  end

  describe "path segment validation, query encoding, pagination, uploads, helpers, schema" do
    it "validates and encodes path segments against dot-segments and matrix params" do
      ["", ".", "..", "%2e", "%2E", "%2e%2e", ".%2e", ";matrix", ".;a=1", "..;b=2", "%2e;x=1", "%2e%3bx=1"].each do |bad|
        expect_raises(ArgumentError) do
          Anthropic.validate_path_segment!(bad)
        end
        expect_raises(ArgumentError) do
          Anthropic.encode_path_segment(bad)
        end
      end

      Anthropic.encode_path_segment("model/v1").should eq("model%2Fv1")
      Anthropic.encode_path_segment("id;v=1").should eq("id%3Bv%3D1")

      client = Anthropic::Client.new(api_key: "sk-test")
      expect_raises(ArgumentError) { client.models.retrieve("..") }
      expect_raises(ArgumentError) { client.files.retrieve("%2e%2e") }
      expect_raises(ArgumentError) { client.beta.sessions.retrieve(".;x") }
    end

    it "encodes bracketed arrays, nested hashes, keeps empty strings, and skips nil query params" do
      capture = stub_and_capture(:get, "https://api.anthropic.com/v1/test?empty=&arr[]=a&arr[]=b", "{}")
      client = Anthropic::Client.new(api_key: "sk-test")

      params = {
        "empty" => "",
        "nil_k" => nil,
        "arr"   => ["a", "b"],
      } of String => Anthropic::Client::QueryParamValue

      client.get("/v1/test", params)
      path = capture.path.not_nil!
      path.should contain("empty=")
      path.should contain("arr%5B%5D=a&arr%5B%5D=b")
      path.should_not contain("nil_k")
    end

    it "handles empty-data cursor continuation and ReportPageCursor semantics" do
      empty_with_cursor = Anthropic::PageCursor(Anthropic::ModelInfo).from_json(%({"data":[],"next_page":"page_2"}))
      empty_with_cursor.has_next_page?.should be_true

      empty_string_cursor = Anthropic::PageCursor(Anthropic::ModelInfo).from_json(%({"data":[],"next_page":""}))
      empty_string_cursor.has_next_page?.should be_false

      # auto_paging_all continues across an empty data page with non-empty next_page and stops on ""
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=20&page=cur_empty")
        .to_return(body: %({"data":[],"next_page":"cur_last"}))
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=20&page=cur_last")
        .to_return(body: %({"data":[{"id":"file_99","type":"file","filename":"f.txt","mime_type":"text/plain","size_bytes":10,"created_at":"2026-01-01T00:00:00Z","downloadable":false}],"next_page":""}))

      client = Anthropic::Client.new(api_key: "sk-test")
      first = Anthropic::FileListResponse.from_json(%({"data":[],"next_page":"cur_empty"}))
      all = first.auto_paging_all(client, beta: false)
      all.map(&.id).should eq(["file_99"])

      report_more = Anthropic::ReportPageCursor(JSON::Any).from_json(
        %({"data":[{"id":"r1"}],"has_more":true,"next_page":"p2","data_refreshed_at":"2026-10-21T00:00:00Z"})
      )
      report_more.has_more?.should be_true
      report_more.has_next_page?.should be_true
      report_more.data_refreshed_at.should eq("2026-10-21T00:00:00Z")

      report_done = Anthropic::ReportPageCursor(JSON::Any).from_json(
        %({"data":[{"id":"r1"}],"has_more":false,"next_page":"ignored_cursor"})
      )
      report_done.has_more?.should be_false
      report_done.has_next_page?.should be_false
    end

    it "sends empty filename for unnamed IO/Bytes uploads and preserves explicit filenames" do
      capture = stub_and_capture(:post, "https://api.anthropic.com/v1/files", Fixtures::Responses::FILE_METADATA)
      client = Anthropic::Client.new(api_key: "sk-test")

      client.files.upload(IO::Memory.new("hello"))
      body_unnamed = capture.body.not_nil!
      body_unnamed.should contain(%(filename=""))
      body_unnamed.should_not contain(%(filename="file"))
      body_unnamed.should_not contain(%(filename="upload"))

      client.files.upload("bytes-data".to_slice)
      body_bytes = capture.body.not_nil!
      body_bytes.should contain(%(filename=""))
      body_bytes.should_not contain(%(filename="file"))

      client.beta.files.upload(IO::Memory.new("explicit"), filename: "custom.csv")
      capture.body.not_nil!.should contain(%(filename="custom.csv"))

      upload = Anthropic::FileUpload.from_bytes("hi".to_slice)
      upload.filename.should be_nil
    end

    it "exposes new StainlessHelper constants and x-stainless-helper-method helpers" do
      Anthropic::StainlessHelper::METHOD_HEADER.should eq("x-stainless-helper-method")
      Anthropic::StainlessHelper::BROWSER_TOOLSET.should eq("browser-toolset")
      Anthropic::StainlessHelper::COMPUTER_TOOLSET.should eq("computer-toolset")
      Anthropic::StainlessHelper::MESSAGE_THREAD.should eq("message-thread")

      hdr = Anthropic::StainlessHelper.method_header("messages.parse")
      hdr.should eq({"x-stainless-helper-method" => "messages.parse"})

      merged = Anthropic::StainlessHelper.merge_method_header({"X-Stainless-Helper-Method" => "old"}, "new")
      merged["x-stainless-helper-method"].should eq("new")
      merged.has_key?("X-Stainless-Helper-Method").should be_false
    end

    it "keeps Schema const and enum properties without requiring type" do
      const_prop = Anthropic::Schema.const("fixed")
      JSON.parse(const_prop.to_json).as_h.should eq({"const" => JSON::Any.new("fixed")})

      parsed_const = Anthropic::Schema::Property.from_json(%({"const":42}))
      parsed_const.type.should be_nil
      parsed_const.const.not_nil!.as_i.should eq(42)

      untyped_enum = Anthropic::Schema.enum("a", "b", type: nil)
      parsed_json = JSON.parse(untyped_enum.to_json).as_h
      parsed_json.has_key?("type").should be_false
      parsed_json["enum"].as_a.map(&.as_s).should eq(["a", "b"])

      schema = Anthropic::Schema.object({
        "mode" => untyped_enum,
        "kind" => const_prop,
      }, required: ["mode", "kind"])
      transformed = Anthropic::SchemaTransform.add_additional_properties_false(JSON.parse(schema.to_json))
      transformed["additionalProperties"].as_bool.should be_false
      transformed["properties"]["mode"].as_h.has_key?("type").should be_false
      transformed["properties"]["kind"]["const"].as_s.should eq("fixed")
    end
  end

  describe "errors and (status, error_code) exception hierarchy" do
    it "defines new HTTP status subclasses, reparents 504/529, and does not shadow ::NotImplementedError" do
      cfg = Anthropic::ConfigurationError.new("bad config")
      cfg.is_a?(Exception).should be_true

      Anthropic::HTTPNotImplementedError.new("x").is_a?(Anthropic::InternalServerError).should be_true
      Anthropic::ServiceUnavailableError.new("x").is_a?(Anthropic::InternalServerError).should be_true
      Anthropic::GatewayTimeoutError.new("x").is_a?(Anthropic::InternalServerError).should be_true
      Anthropic::OverloadedError.new("x").is_a?(Anthropic::InternalServerError).should be_true
      Anthropic::ContentTooLargeError.should eq(Anthropic::PayloadTooLargeError)

      # Verify stdlib ::NotImplementedError is unaffected inside module Anthropic
      Anthropic::HTTPNotImplementedError.new("x").is_a?(::NotImplementedError).should be_false

      Anthropic::ErrorType::MEMORY_PRECONDITION_FAILED_ERROR.should eq("memory_precondition_failed_error")
      Anthropic::ErrorType::MEMORY_PATH_CONFLICT_ERROR.should eq("memory_path_conflict_error")
      Anthropic::ErrorType::CONFLICT_ERROR.should eq("conflict_error")
    end

    it "dispatches all status defaults and (status, error_code) subclasses with typed details" do
      Anthropic::ERROR_CLASSES.size.should eq(98)

      status_cases = {
        408 => Anthropic::RequestTimeoutError,
        412 => Anthropic::PreconditionFailedError,
        413 => Anthropic::ContentTooLargeError,
        431 => Anthropic::RequestHeaderFieldsTooLargeError,
        499 => Anthropic::ClientClosedRequestError,
        501 => Anthropic::HTTPNotImplementedError,
        503 => Anthropic::ServiceUnavailableError,
        504 => Anthropic::GatewayTimeoutError,
        529 => Anthropic::OverloadedError,
      }
      status_cases.each do |code, klass|
        err = Anthropic.build_api_error(code, %({"error":{"type":"api_error","message":"boom"}}))
        err.class.should eq(klass)
        err.api_message.should eq("boom")
      end

      # Parameterized details: BetaHeartbeatPreconditionFailedError (412)
      hb_body = %({"error":{"type":"invalid_request_error","message":"lease mismatch","details":{"error_code":"heartbeat_precondition_failed","current_state":{"last_heartbeat":"2026-10-21T00:00:00Z","lease_extended":false,"state":"active","ttl_seconds":30}}}})
      hb_err = Anthropic.build_api_error(412, hb_body)
      hb_err.should be_a(Anthropic::BetaHeartbeatPreconditionFailedError)
      hb_err.error_code.should eq("heartbeat_precondition_failed")
      hb_det = hb_err.as(Anthropic::BetaHeartbeatPreconditionFailedError).typed_details.not_nil!
      hb_det.current_state.state.should eq("active")
      hb_det.current_state.lease_extended?.should be_false
      hb_det.current_state.ttl_seconds.should eq(30_i64)

      # Parameterized details: OrganizationOnHoldError (400) & ThreadUnsupportedRequestError (400)
      hold_body = %({"error":{"type":"invalid_request_error","message":"on hold","details":{"error_code":"organization_on_hold","appeal_url":"https://support.anthropic.com/appeal"}}})
      hold_err = Anthropic.build_api_error(400, hold_body)
      hold_err.should be_a(Anthropic::OrganizationOnHoldError)
      hold_err.as(Anthropic::OrganizationOnHoldError).typed_details.not_nil!.appeal_url.should eq("https://support.anthropic.com/appeal")

      thread_body = %({"error":{"type":"invalid_request_error","message":"unsupported","details":{"error_code":"thread_unsupported_request","unsupported":["cache_control","thinking"]}}})
      thread_err = Anthropic.build_api_error(400, thread_body)
      thread_err.should be_a(Anthropic::ThreadUnsupportedRequestError)
      thread_err.as(Anthropic::ThreadUnsupportedRequestError).typed_details.not_nil!.unsupported.should eq(["cache_control", "thinking"])

      # 429 rate-limit error code subclass
      rl_body = %({"error":{"type":"rate_limit_error","message":"spend limit","details":{"error_code":"enforced_spend_limit_reached"}}})
      rl_err = Anthropic.build_api_error(429, rl_body, HTTP::Headers{"retry-after" => "15"})
      rl_err.should be_a(Anthropic::EnforcedSpendLimitReachedError)
      rl_err.as(Anthropic::RateLimitError).retry_after.should eq(15)

      # 529 overloaded error code subclass & SSE streaming error dispatch
      sse_body = "event: error\ndata: {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"compaction busy\",\"details\":{\"error_code\":\"compaction_unavailable\"}}}\n\n"
      sse_resp = HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "text/event-stream"}, body_io: IO::Memory.new(sse_body))
      stream_err = expect_raises(Anthropic::CompactionUnavailableError) do
        Anthropic::MessageStream.new(sse_resp).each { |_ev| }
      end
      stream_err.status.should be_nil
      stream_err.error_code.should eq("compaction_unavailable")
    end

    it "guards non-object body['error'] payloads safely without raising TypeCastError" do
      ["oops", %({"error":"string"}), %({"error":[1,2]}), %({"error":null})].each do |raw|
        err = Anthropic.build_api_error(400, raw)
        err.class.should eq(Anthropic::BadRequestError)
        err.api_message.should be_nil
        err.error_code.should be_nil
        err.details.should be_nil
      end
    end
  end

  describe "models, beta headers, ?beta=true removal, and completions removal" do
    it "exposes 2026-10-21 model constants, shorthands, capabilities, and ModelInfo lifecycle fields" do
      Anthropic::Model::CLAUDE_SONNET_5_5.should eq("claude-sonnet-5-5")
      Anthropic::Model::CLAUDE_HAIKU_5_5.should eq("claude-haiku-5-5")
      Anthropic::Model::CLAUDE_FABLE_5_2.should eq("claude-fable-5-2")
      Anthropic::Model::CLAUDE_MYTHOS_5_2.should eq("claude-mythos-5-2")

      Anthropic.model_name(:sonnet_5_5).should eq("claude-sonnet-5-5")
      Anthropic.model_name(:haiku_5_5).should eq("claude-haiku-5-5")
      Anthropic.model_name(:fable_5_2).should eq("claude-fable-5-2")
      Anthropic.model_name(:mythos_5_2).should eq("claude-mythos-5-2")

      info = Anthropic::ModelInfo.from_json(
        %({"type":"model","id":"claude-sonnet-5-5","display_name":"Claude Sonnet 5.5","created_at":"2026-10-21T00:00:00Z","deprecated_at":null,"lifecycle":"active","line":"sonnet","retires_at":null,"capabilities":{"batch":{"supported":true},"citations":{"supported":true},"code_execution":{"supported":true},"context_management":{"supported":true},"effort":{"supported":true,"low":{"supported":true},"medium":{"supported":true},"high":{"supported":true},"max":{"supported":true}},"image_input":{"supported":true},"pdf_input":{"supported":true},"server_tools":{"supported":true,"code_execution":{"supported":true},"web_search":{"supported":true}},"structured_outputs":{"supported":true},"thinking":{"supported":true,"types":{"adaptive":{"supported":true},"between_tools":{"supported":true},"disabled":{"supported":true},"enabled":{"supported":true}}}}})
      )
      info.lifecycle.should eq("active")
      info.line.should eq("sonnet")
      info.deprecated_at.should be_nil
      info.retires_at.should be_nil
      caps = info.capabilities.not_nil!
      caps.server_tools.not_nil!.supported?.should be_true
      caps.server_tools.not_nil!.web_search.supported?.should be_true
      caps.thinking.types.between_tools.not_nil!.supported?.should be_true
      caps.thinking.types.disabled.not_nil!.supported?.should be_true
    end

    it "passes lifecycle filter on Models#list and BetaModels#list" do
      ga_cap = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=20&lifecycle[]=active&lifecycle[]=deprecated", Fixtures::Responses::MODEL_LIST)
      beta_cap = stub_and_capture(:get, "https://api.anthropic.com/v1/models?limit=10&lifecycle[]=retired", Fixtures::Responses::MODEL_LIST)

      client = Anthropic::Client.new(api_key: "sk-test")
      client.models.list(lifecycle: ["active", "deprecated"])
      ga_cap.path.not_nil!.should contain("lifecycle%5B%5D=active&lifecycle%5B%5D=deprecated")

      client.beta.models.list(limit: 10, lifecycle: ["retired"])
      beta_cap.path.not_nil!.should_not contain("beta=true")
      beta_cap.path.not_nil!.should contain("lifecycle%5B%5D=retired")
    end

    it "exposes all 8 new beta header constants and updated USER_PROFILES_BETA" do
      Anthropic::CE_PLUGINS_BETA.should eq("ce-plugins-2026-09-01")
      Anthropic::SPEND_LIMIT_READS_BETA.should eq("spend-limit-reads-2026-09-26")
      Anthropic::TELEMETRY_DESTINATIONS_BETA.should eq("telemetry-destinations-2026-08-11")
      Anthropic::WEBHOOKS_BETA.should eq("webhooks-2026-10-07")
      Anthropic::ADMIN_USER_SIGN_OUT_BETA.should eq("admin-user-sign-out-2026-10-08")
      Anthropic::MESSAGE_THREADS_BETA.should eq("message-threads-2026-08-12")
      Anthropic::ANALYTICS_USAGE_COST_BETA.should eq("analytics-usage-cost-2026-08-24")
      Anthropic::EXPERIMENTAL_CLAUDE_TAG_BETA.should eq("experimental-claude-tag-2026-10-21")
      Anthropic::USER_PROFILES_BETA.should eq("user-profiles-2026-08-18")
      Anthropic::USER_PROFILES_2026_03_24_BETA.should eq("user-profiles-2026-03-24")
      Anthropic::USER_PROFILES_2026_09_04_BETA.should eq("user-profiles-2026-09-04")
    end

    it "removes client.completions" do
      ({{ Anthropic::Client.methods.any? { |method| method.name == "completions" } }}).should be_false
      ({{ Anthropic::Client.methods.any? { |method| method.name == "supports_message_threads?" } }}).should be_true
    end
  end
end
