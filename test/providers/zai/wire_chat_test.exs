defmodule ReqLlmNext.Wire.ZAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.ZAIChat

  test "encodes Z.AI thinking controls on the request body" do
    body =
      ZAIChat.encode_body(
        TestModels.zai(%{id: "glm-4.6"}),
        "Explain the result",
        thinking: %{type: "disabled"}
      )

    assert body.model == "glm-4.6"
    assert body.thinking == %{type: "disabled"}
  end

  test "decodes reasoning content through the provider-local semantic protocol" do
    chunks =
      ZAIChat.decode_sse_event(
        %{
          data:
            Jason.encode!(%{
              "choices" => [
                %{
                  "delta" => %{
                    "reasoning_content" => "Thinking",
                    "content" => "Answer"
                  }
                }
              ]
            })
        },
        TestModels.zai()
      )

    assert {:thinking, "Thinking"} in chunks
    assert "Answer" in chunks
  end
end
