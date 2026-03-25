defmodule ReqLlmNext.Wire.OpenRouterChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenRouterChat

  test "encodes provider-specific OpenRouter request fields" do
    body =
      OpenRouterChat.encode_body(
        TestModels.openrouter(%{id: "anthropic/claude-sonnet-4.5"}),
        "Explain the result",
        provider_options: [
          openrouter_models: ["anthropic/claude-sonnet-4.5", "openai/gpt-4o-mini"],
          openrouter_route: "fallback",
          openrouter_provider: %{require_parameters: true},
          openrouter_transforms: ["middle-out"],
          openrouter_top_k: 40,
          openrouter_repetition_penalty: 1.05,
          openrouter_min_p: 0.05,
          openrouter_top_a: 0.2,
          openrouter_top_logprobs: 3,
          openrouter_usage: %{include: true},
          openrouter_plugins: [%{id: "web"}]
        ]
      )

    assert body.model == "anthropic/claude-sonnet-4.5"
    assert body.models == ["anthropic/claude-sonnet-4.5", "openai/gpt-4o-mini"]
    assert body.route == "fallback"
    assert body.provider == %{require_parameters: true}
    assert body.transforms == ["middle-out"]
    assert body.top_k == 40
    assert body.repetition_penalty == 1.05
    assert body.min_p == 0.05
    assert body.top_a == 0.2
    assert body.top_logprobs == 3
    assert body.usage == %{include: true}
    assert body.plugins == [%{id: "web"}]
  end

  test "allows top-level OpenRouter provider keys to override provider_options" do
    body =
      OpenRouterChat.encode_body(
        TestModels.openrouter(),
        "Explain the result",
        provider_options: [openrouter_route: "fallback"],
        openrouter_route: "direct"
      )

    assert body.route == "direct"
  end

  test "adds OpenRouter attribution headers when configured" do
    headers =
      OpenRouterChat.headers(
        provider_options: [
          app_referer: "https://reqllm.dev",
          app_title: "ReqLlmNext"
        ]
      )

    assert {"Content-Type", "application/json"} in headers
    assert {"HTTP-Referer", "https://reqllm.dev"} in headers
    assert {"X-Title", "ReqLlmNext"} in headers
  end

  test "decodes SSE events through the OpenAI-compatible semantic protocol" do
    ["Answer"] =
      OpenRouterChat.decode_sse_event(
        %{data: Jason.encode!(%{"choices" => [%{"delta" => %{"content" => "Answer"}}]})},
        TestModels.openrouter()
      )
  end
end
