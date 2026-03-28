defmodule ReqLlmNext.Wire.StreamingOptionalCallbacksTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.Streaming

  setup do
    on_exit(fn ->
      Code.ensure_loaded?(ReqLlmNext.Wire.Anthropic)
      Code.ensure_loaded?(ReqLlmNext.Wire.GoogleGenerateContent)
    end)

    :ok
  end

  test "loads Anthropic wire headers before building the request" do
    unload(ReqLlmNext.Wire.Anthropic)

    {:ok, request} =
      Streaming.build_request(
        ReqLlmNext.Providers.Anthropic,
        ReqLlmNext.Wire.Anthropic,
        TestModels.anthropic(),
        "Hello!",
        api_key: "sk-ant-test"
      )

    headers = normalized_headers(request.headers)

    assert headers["x-api-key"] == "sk-ant-test"
    assert headers["anthropic-version"] == "2023-06-01"
  end

  test "loads Google custom build_request before constructing the request" do
    unload(ReqLlmNext.Wire.GoogleGenerateContent)

    {:ok, request} =
      Streaming.build_request(
        ReqLlmNext.Providers.Google,
        ReqLlmNext.Wire.GoogleGenerateContent,
        TestModels.google(%{id: "gemini-2.5-flash"}),
        "Hello!",
        api_key: "test-key",
        provider_options: [google_api_version: "v1"]
      )

    assert request.host == "generativelanguage.googleapis.com"
    assert request.path == "/v1/models/gemini-2.5-flash:streamGenerateContent"
    assert request.query == "alt=sse"
  end

  defp unload(module) do
    :code.purge(module)
    :code.delete(module)
    assert :code.is_loaded(module) == false
  end

  defp normalized_headers(headers) do
    Map.new(headers, fn {name, value} -> {String.downcase(name), value} end)
  end
end
