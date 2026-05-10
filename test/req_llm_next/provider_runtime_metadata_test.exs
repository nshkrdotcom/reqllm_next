defmodule ReqLlmNext.ProviderRuntimeMetadataTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers.Generic

  test "honors per-operation base_url overrides and provider_model_id templates" do
    model = model!(%{id: "base-model", provider: :runtime_test})

    runtime = %{
      base_url: "https://api.example.com/v1",
      auth: %{type: "bearer", env: ["RUNTIME_TEST_API_KEY"], headers: []},
      default_headers: %{},
      default_query: %{}
    }

    execution_entry = %{
      supported: true,
      base_url: "https://media.example.com/v2",
      path: "/responses/{provider_model_id}",
      provider_model_id: "override-model"
    }

    opts = runtime_opts(runtime, execution_entry)

    assert {:ok, url} = Provider.request_url(Generic, model, "/unused", opts)
    assert url == "https://media.example.com/v2/responses/override-model"
  end

  test "builds query auth into request URLs and merges default query parameters" do
    model = model!(%{id: "query-model", provider: :runtime_test})

    runtime = %{
      base_url: "https://query.example.com/v1",
      auth: %{type: "query", env: ["QUERY_RUNTIME_KEY"], query_name: "api_key", headers: []},
      default_headers: %{},
      default_query: %{version: "2026-03-26"}
    }

    execution_entry = %{supported: true, path: "/chat/completions"}

    ReqLlmNext.Env.put("QUERY_RUNTIME_KEY", "query-secret")

    on_exit(fn ->
      ReqLlmNext.Env.delete("QUERY_RUNTIME_KEY")
    end)

    opts = runtime_opts(runtime, execution_entry)

    assert {:ok, url} = Provider.request_url(Generic, model, "/unused", opts)
    assert URI.parse(url).path == "/v1/chat/completions"

    assert URI.parse(url).query |> URI.decode_query() == %{
             "api_key" => "query-secret",
             "version" => "2026-03-26"
           }
  end

  test "builds multi-header auth and default headers" do
    model = model!(%{id: "header-model", provider: :runtime_test})

    runtime = %{
      base_url: "https://headers.example.com/v1",
      auth: %{
        type: "multi_header",
        headers: [
          %{name: "x-api-key", env: "MULTI_RUNTIME_KEY"},
          %{name: "x-org-id"}
        ]
      },
      default_headers: %{accept: "application/json"},
      default_query: %{}
    }

    execution_entry = %{supported: true, path: "/chat/completions"}

    ReqLlmNext.Env.put("MULTI_RUNTIME_KEY", "multi-secret")

    on_exit(fn ->
      ReqLlmNext.Env.delete("MULTI_RUNTIME_KEY")
    end)

    opts =
      runtime_opts(runtime, execution_entry) ++
        [{"x-org-id", "org-123"}]

    assert {:ok, headers} =
             Provider.request_headers(Generic, model, opts, [{"Content-Type", "application/json"}])

    assert {"x-api-key", "multi-secret"} in headers
    assert {"x-org-id", "org-123"} in headers
    assert {"accept", "application/json"} in headers
    assert {"Content-Type", "application/json"} in headers
  end

  test "fails fast when runtime template config is missing" do
    model = model!(%{id: "templated-model", provider: :runtime_test})

    runtime = %{
      base_url: "https://api.example.com/accounts/{account_id}/ai/v1",
      auth: %{type: "bearer", env: ["RUNTIME_TEST_API_KEY"], headers: []},
      default_headers: %{},
      default_query: %{}
    }

    execution_entry = %{supported: true, path: "/chat/completions"}

    assert {:error, error} =
             Provider.request_url(
               Generic,
               model,
               "/unused",
               runtime_opts(runtime, execution_entry)
             )

    assert Exception.message(error) =~ "Missing provider runtime configuration for account_id"
  end

  defp runtime_opts(runtime, execution_entry) do
    [
      _use_runtime_metadata: true,
      _provider_runtime: runtime,
      _model_execution_entry: execution_entry
    ]
  end

  defp model!(attrs) do
    LLMDB.Model.new!(Map.merge(%{catalog_only: false}, attrs))
  end
end
