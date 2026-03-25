defmodule ReqLlmNext.Wire.GroqChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.GroqChat

  test "encodes provider-specific Groq request fields" do
    body =
      GroqChat.encode_body(
        TestModels.groq(),
        "Explain the result",
        provider_options: [
          service_tier: "flex",
          reasoning_effort: :high,
          reasoning_format: "parsed",
          search_settings: %{scope: "web"},
          compound_custom: %{mode: "compound"},
          logit_bias: %{"42" => 3}
        ]
      )

    assert body.model == "test-model"
    assert body.service_tier == "flex"
    assert body.reasoning_effort == "high"
    assert body.reasoning_format == "parsed"
    assert body.search_settings == %{scope: "web"}
    assert body.compound_custom == %{mode: "compound"}
    assert body.logit_bias == %{"42" => 3}
  end

  test "allows top-level Groq provider keys to override provider_options" do
    body =
      GroqChat.encode_body(
        TestModels.groq(),
        "Explain the result",
        provider_options: [service_tier: "flex"],
        service_tier: "performance"
      )

    assert body.service_tier == "performance"
  end

  test "decodes SSE events through the OpenAI-compatible semantic protocol" do
    ["Answer"] =
      GroqChat.decode_sse_event(
        %{data: Jason.encode!(%{"choices" => [%{"delta" => %{"content" => "Answer"}}]})},
        TestModels.groq()
      )
  end
end
