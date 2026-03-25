defmodule ReqLlmNext.Wire.AlibabaChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.AlibabaChat

  test "encodes provider-specific DashScope request fields" do
    body =
      AlibabaChat.encode_body(
        TestModels.alibaba(%{id: "qwen-plus"}),
        "Explain the result",
        provider_options: [
          enable_search: true,
          search_options: %{search_strategy: "agent", enable_source: true},
          enable_thinking: true,
          thinking_budget: 4096,
          top_k: 40,
          repetition_penalty: 1.1,
          enable_code_interpreter: true,
          incremental_output: true
        ]
      )

    assert body.model == "qwen-plus"
    assert body.enable_search == true
    assert body.search_options == %{search_strategy: "agent", enable_source: true}
    assert body.enable_thinking == true
    assert body.thinking_budget == 4096
    assert body.top_k == 40
    assert body.repetition_penalty == 1.1
    assert body.enable_code_interpreter == true
    assert body.incremental_output == true
  end

  test "merges raw dashscope_parameters with lifted DashScope options" do
    body =
      AlibabaChat.encode_body(
        TestModels.alibaba(),
        "Explain the result",
        provider_options: [
          dashscope_parameters: %{enable_search: false, top_k: 20},
          enable_search: true,
          repetition_penalty: 1.2
        ]
      )

    assert body.enable_search == true
    assert body.top_k == 20
    assert body.repetition_penalty == 1.2
  end

  test "decodes SSE events through the OpenAI-compatible semantic protocol" do
    ["Answer"] =
      AlibabaChat.decode_sse_event(
        %{data: Jason.encode!(%{"choices" => [%{"delta" => %{"content" => "Answer"}}]})},
        TestModels.alibaba()
      )
  end
end
