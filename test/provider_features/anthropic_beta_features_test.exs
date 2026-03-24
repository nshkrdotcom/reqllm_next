defmodule ReqLlmNext.ProviderFeatures.AnthropicBetaFeaturesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response

  test "supports the 1m context beta header on claude-sonnet-4-6" do
    {:ok, response} =
      ReqLlmNext.generate_text(
        "anthropic:claude-sonnet-4-6",
        "Say hello in one short sentence.",
        fixture: "basic_context_1m",
        anthropic_context_1m: true,
        max_tokens: 32
      )

    assert is_binary(Response.text(response))
    assert String.length(Response.text(response)) > 0

    fixture =
      "/Users/mhostetler/Source/ReqLLM/reqllm_next/test/fixtures/anthropic/claude_sonnet_4_6/basic_context_1m.json"
      |> File.read!()
      |> Jason.decode!()

    assert get_in(fixture, ["request", "headers", "anthropic-beta"]) =~ "context-1m-2025-08-07"
  end
end
