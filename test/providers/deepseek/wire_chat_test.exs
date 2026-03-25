defmodule ReqLlmNext.Wire.DeepSeekChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.DeepSeekChat

  test "encodes thinking mode into chat request bodies" do
    body =
      DeepSeekChat.encode_body(
        TestModels.deepseek_reasoning(),
        "Explain the result",
        thinking: %{type: "enabled"}
      )

    assert body.model == "deepseek-reasoner"
    assert body.thinking == %{type: "enabled"}
    assert body.stream == true
  end

  test "falls back to enabled thinking when reasoning effort is requested" do
    body =
      DeepSeekChat.encode_body(
        TestModels.deepseek_reasoning(),
        "Explain the result",
        reasoning_effort: :high
      )

    assert body.thinking == %{type: "enabled"}
  end

  test "decodes SSE events with reasoning deltas through the DeepSeek semantic protocol" do
    [thinking, answer] =
      DeepSeekChat.decode_sse_event(
        %{
          data:
            Jason.encode!(%{
              "choices" => [
                %{"delta" => %{"reasoning_content" => "Think", "content" => "Answer"}}
              ]
            })
        },
        TestModels.deepseek_reasoning()
      )

    assert thinking == {:thinking, "Think"}
    assert answer == "Answer"
  end
end
