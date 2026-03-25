defmodule ReqLlmNext.SemanticProtocols.DeepSeekChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.DeepSeekChat
  alias ReqLlmNext.TestModels

  test "decodes thinking deltas and usage from streaming events" do
    events =
      DeepSeekChat.decode_event(
        %{
          "choices" => [
            %{
              "delta" => %{"reasoning_content" => "Think", "content" => "Answer"},
              "finish_reason" => nil
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 5,
            "prompt_cache_hit_tokens" => 6
          }
        },
        TestModels.deepseek_reasoning()
      )

    assert {:thinking, "Think"} in events
    assert "Answer" in events

    assert {:usage,
            %{
              input_tokens: 10,
              output_tokens: 5,
              total_tokens: 15,
              cache_read_tokens: 6
            }} in events
  end

  test "decodes non-stream response messages with reasoning content" do
    events =
      DeepSeekChat.decode_event(
        %{
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "reasoning_content" => "Thought",
                "content" => "Final answer"
              }
            }
          ]
        },
        TestModels.deepseek_reasoning()
      )

    assert {:thinking, "Thought"} in events
    assert "Final answer" in events
    assert {:meta, %{finish_reason: :stop, terminal?: true}} in events
  end
end
