defmodule ReqLlmNext.Wire.ZenmuxResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.ZenmuxResponses

  test "encodes Zenmux Responses request fields" do
    body =
      ZenmuxResponses.build_request_body(
        TestModels.zenmux(),
        "Explain the result",
        provider_options: [
          provider: %{routing: %{type: "priority"}},
          model_routing_config: %{preference: "quality"},
          reasoning: %{depth: "full"},
          verbosity: "high"
        ],
        reasoning_effort: :medium,
        max_completion_tokens: 1024
      )

    assert body.model == "openai/gpt-5.2"
    assert body.max_output_tokens == 1024
    assert body.provider == %{routing: %{type: "priority"}}
    assert body.model_routing_config == %{preference: "quality"}
    assert body.reasoning == %{effort: "medium", depth: "full"}
    assert body.verbosity == "high"
  end

  test "decodes Responses SSE events through the shared semantic protocol" do
    chunks =
      ZenmuxResponses.decode_sse_event(
        %{data: Jason.encode!(%{"type" => "response.output_text.delta", "delta" => "Answer"})},
        TestModels.zenmux()
      )

    assert chunks == ["Answer"]
  end
end
