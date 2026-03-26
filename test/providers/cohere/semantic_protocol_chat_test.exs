defmodule ReqLlmNext.SemanticProtocols.CohereChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.CohereChat
  alias ReqLlmNext.TestModels

  test "decodes content deltas and message-end usage" do
    text_chunks =
      CohereChat.decode_event(
        %{
          "type" => "content-delta",
          "delta" => %{"message" => %{"content" => %{"text" => "Hello"}}}
        },
        TestModels.cohere()
      )

    final_chunks =
      CohereChat.decode_event(
        %{
          "type" => "message-end",
          "delta" => %{
            "finish_reason" => "COMPLETE",
            "usage" => %{"tokens" => %{"input_tokens" => 12, "output_tokens" => 4}}
          }
        },
        TestModels.cohere()
      )

    assert text_chunks == ["Hello"]

    assert {:usage, %{input_tokens: 12, output_tokens: 4, total_tokens: 16}} in final_chunks
    assert {:meta, %{finish_reason: :stop, terminal?: true}} in final_chunks
  end
end
