defmodule ReqLlmNext.GovernedAuthorityTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.GovernedAuthority
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers.Generic
  alias ReqLlmNext.Providers.Google
  alias ReqLlmNext.Providers.OpenAI
  alias ReqLlmNext.Providers.OpenAI.Realtime.Adapter, as: RealtimeAdapter
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.GoogleEmbeddings
  alias ReqLlmNext.Wire.GoogleImages

  setup do
    original_openai = System.get_env("OPENAI_API_KEY")
    original_runtime = System.get_env("RUNTIME_TEST_API_KEY")

    on_exit(fn ->
      restore_env("OPENAI_API_KEY", original_openai)
      restore_env("RUNTIME_TEST_API_KEY", original_runtime)
    end)

    :ok
  end

  test "governed provider URL and headers come from authority not env" do
    System.put_env("OPENAI_API_KEY", "env-openai-key")
    model = TestModels.openai()
    opts = [governed_authority: authority(base_url: "https://governed.example/v1")]

    assert {:ok, url} = Provider.request_url(OpenAI, model, "/chat/completions", opts)
    assert url == "https://governed.example/v1/chat/completions"

    assert {:ok, headers} =
             Provider.request_headers(OpenAI, model, opts, [{"content-type", "application/json"}])

    assert {"authorization", "governed-credential"} in headers
    assert {"content-type", "application/json"} in headers
    refute {"Authorization", "Bearer env-openai-key"} in headers
  end

  test "governed provider rejects unmanaged request authority inputs" do
    model = TestModels.openai()

    rejected_options = [
      api_key: "direct-key",
      base_url: "https://bypass.example/v1",
      url: "https://bypass.example/v1/chat",
      endpoint_url: "https://bypass.example/v1/chat",
      auth: {:bearer, "direct-key"},
      headers: [{"authorization", "direct-key"}],
      realtime_token: "direct-realtime-token",
      organization_id: "org-direct",
      project_id: "project-direct",
      account_id: "account-direct",
      model_account_id: "model-account-direct"
    ]

    Enum.each(rejected_options, fn {key, value} ->
      opts =
        [governed_authority: authority()]
        |> Keyword.put(key, value)

      assert {:error, error} = Provider.request_url(OpenAI, model, "/chat/completions", opts)
      assert Exception.message(error) =~ "governed ReqLlmNext"
      assert Exception.message(error) =~ Atom.to_string(key)
    end)
  end

  test "governed runtime metadata ignores env credentials and uses authority template values" do
    System.put_env("RUNTIME_TEST_API_KEY", "runtime-env-secret")
    model = runtime_model()

    runtime = %{
      base_url: "https://runtime.example/accounts/{account_id}/v1",
      auth: %{type: "bearer", env: ["RUNTIME_TEST_API_KEY"]},
      default_headers: %{accept: "application/json"},
      default_query: %{version: "2026-05-03"}
    }

    execution_entry = %{
      supported: true,
      path: "/responses/{provider_model_id}",
      provider_model_id: "runtime-model"
    }

    opts = [
      governed_authority:
        authority(
          base_url: "https://governed.example/accounts/{account_id}/v1",
          template_values: %{"account_id" => "governed-account"},
          query: %{"api_key" => "governed-query"}
        ),
      _use_runtime_metadata: true,
      _provider_runtime: runtime,
      _model_execution_entry: execution_entry
    ]

    assert {:ok, url} = Provider.request_url(Generic, model, "/unused", opts)
    uri = URI.parse(url)

    assert uri.scheme == "https"
    assert uri.host == "governed.example"
    assert uri.path == "/accounts/governed-account/v1/responses/runtime-model"
    refute String.contains?(url, "runtime-env-secret")

    assert URI.decode_query(uri.query) == %{
             "api_key" => "governed-query",
             "version" => "2026-05-03"
           }

    assert {:ok, headers} = Provider.request_headers(Generic, model, opts)
    assert {"authorization", "governed-credential"} in headers
    assert {"accept", "application/json"} in headers
    refute inspect(headers) =~ "runtime-env-secret"
  end

  test "governed realtime URL uses authority base URL" do
    url =
      RealtimeAdapter.websocket_url(
        TestModels.openai(),
        governed_authority: authority(base_url: "https://governed-realtime.example"),
        voice: "alloy"
      )

    assert url == "wss://governed-realtime.example/v1/realtime?model=test-model&voice=alloy"
  end

  test "governed authority requires provider key base url and cleanup refs" do
    for field <- [:provider_key_ref, :base_url_ref, :cleanup_policy_ref] do
      attrs =
        authority_attrs()
        |> Keyword.delete(field)

      assert_raise ArgumentError, fn ->
        GovernedAuthority.new!(attrs)
      end
    end
  end

  test "redacted authority projection carries refs and no materialized credentials" do
    projection =
      authority()
      |> GovernedAuthority.ref_projection()

    assert projection.credential_ref == "credential://reqllm/openai/default"
    assert projection.provider_key_ref == "provider-key://openai/default"
    assert projection.base_url_ref == "base-url://openai/default"
    assert projection.realtime_session_token_ref == "realtime-token://openai/default"
    assert projection.reconnect_token_ref == "reconnect-token://openai/default"
    assert projection.stream_ref == "stream://openai/default"
    refute inspect(projection) =~ "governed-credential"
    refute inspect(projection) =~ "https://governed.example"
  end

  test "governed realtime reconnect revalidates lease target and revocation state" do
    assert {:ok, _url} =
             ReqLlmNext.Realtime.websocket_url(
               TestModels.openai(),
               governed_authority: authority(),
               _realtime_reconnect?: true
             )

    rejected_statuses = [
      _credential_lease_status: :revoked,
      _target_grant_status: :denied,
      _revocation_status: :stale
    ]

    for {key, value} <- rejected_statuses do
      assert {:error, error} =
               ReqLlmNext.Realtime.websocket_url(
                 TestModels.openai(),
                 [{:governed_authority, authority()}, {:_realtime_reconnect?, true}, {key, value}]
               )

      assert Exception.message(error) =~ "governed ReqLlmNext realtime"
    end
  end

  test "realtime cleanup projection removes materialized session tokens" do
    projection =
      GovernedAuthority.cleanup_realtime_materialization(authority(), %{
        headers: [{"authorization", "governed-credential"}],
        realtime_session_token: "raw-realtime-session-token",
        reconnect_token: "raw-reconnect-token",
        stream_auth: "raw-stream-token"
      })

    assert projection.cleanup_status == :complete
    assert projection.realtime_session_token_ref == "realtime-token://openai/default"
    assert projection.reconnect_token_ref == "reconnect-token://openai/default"
    assert projection.stream_ref == "stream://openai/default"
    refute inspect(projection) =~ "raw-realtime-session-token"
    refute inspect(projection) =~ "raw-reconnect-token"
    refute inspect(projection) =~ "raw-stream-token"
    refute inspect(projection) =~ "governed-credential"
  end

  test "governed Google embedding and image wires use authority base URL" do
    google_authority = authority(base_url: "https://governed-google.example/custom/v1beta")

    assert {:ok, embedding_request} =
             GoogleEmbeddings.build_request(
               Google,
               TestModels.google(%{
                 id: "gemini-embedding-001",
                 capabilities: %{chat: false, embeddings: true},
                 modalities: %{input: [:text], output: [:embedding]}
               }),
               "hello",
               governed_authority: google_authority
             )

    assert embedding_request.host == "governed-google.example"
    assert embedding_request.path == "/custom/v1beta/models/gemini-embedding-001:embedContent"
    assert {"authorization", "governed-credential"} in embedding_request.headers

    assert {:ok, image_request} =
             GoogleImages.build_request(
               Google,
               TestModels.google(%{
                 id: "imagen-4.0-fast-generate-001",
                 capabilities: %{chat: false, embeddings: false},
                 modalities: %{input: [:text], output: [:image]}
               }),
               "Draw a paper lantern at dusk",
               governed_authority: google_authority
             )

    assert image_request.host == "governed-google.example"
    assert image_request.path == "/custom/v1beta/models/imagen-4.0-fast-generate-001:predict"
    assert {"authorization", "governed-credential"} in image_request.headers
  end

  test "fixture recorder redacts governed credential headers" do
    model = TestModels.openai()
    authority = authority()

    recorder =
      Fixtures.start_recorder(
        model,
        "governed",
        "Hello",
        %{
          "method" => "WEBSOCKET",
          "url" => "wss://governed.example/v1/realtime",
          "transport" => "websocket",
          "headers" => GovernedAuthority.headers(authority),
          "body" => %{type: "response.create", model: "test-model"}
        }
      )

    assert recorder.request["headers"]["authorization"] == "[REDACTED]"
    refute inspect(recorder) =~ "governed-credential"
  end

  defp authority(overrides \\ []) do
    authority_attrs(overrides)
    |> GovernedAuthority.new!()
  end

  defp authority_attrs(overrides \\ []) do
    defaults = [
      base_url: "https://governed.example",
      credential_ref: "credential://reqllm/openai/default",
      credential_lease_ref: "lease://reqllm/openai/default",
      provider_key_ref: "provider-key://openai/default",
      base_url_ref: "base-url://openai/default",
      target_ref: "target://reqllm/openai/default",
      operation_policy_ref: "operation-policy://reqllm/openai/read",
      cleanup_policy_ref: "cleanup-policy://reqllm/openai/default",
      redaction_ref: "redaction://reqllm/default",
      provider_ref: "provider://openai",
      provider_account_ref: "provider-account://openai/default",
      endpoint_account_ref: "endpoint-account://openai/default",
      model_account_ref: "model-account://openai/default",
      organization_ref: "organization://openai/default",
      project_ref: "project://openai/default",
      realtime_session_ref: "realtime-session://openai/default",
      realtime_session_token_ref: "realtime-token://openai/default",
      reconnect_token_ref: "reconnect-token://openai/default",
      stream_ref: "stream://openai/default",
      revocation_epoch: 7,
      headers: [{"authorization", "governed-credential"}],
      query: %{},
      template_values: %{}
    ]

    Keyword.merge(defaults, overrides)
  end

  defp runtime_model do
    LLMDB.Model.new!(%{
      id: "runtime-model",
      provider: :runtime_test,
      catalog_only: false
    })
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
