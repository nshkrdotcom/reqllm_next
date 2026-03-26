defmodule ReqLlmNext.SemanticProtocols.GoogleGenerateContentTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.GoogleGenerateContent
  alias ReqLlmNext.TestModels

  test "decodes thoughts tool calls usage and grounding metadata" do
    events =
      GoogleGenerateContent.decode_event(
        %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{"text" => "Thinking", "thought" => true},
                  %{
                    "functionCall" => %{
                      "name" => "lookup_weather",
                      "args" => %{"location" => "Austin"}
                    }
                  }
                ]
              },
              "finishReason" => "STOP",
              "groundingMetadata" => %{
                "groundingChunks" => [%{"web" => %{"uri" => "https://example.com"}}]
              }
            }
          ],
          "usageMetadata" => %{
            "promptTokenCount" => 10,
            "candidatesTokenCount" => 4,
            "totalTokenCount" => 14,
            "thoughtsTokenCount" => 2,
            "cachedContentTokenCount" => 3
          }
        },
        TestModels.google(%{id: "gemini-2.5-flash"})
      )

    assert {:thinking, "Thinking"} in events

    assert {:tool_call_start, %{name: "lookup_weather"}} =
             Enum.find(events, &match?({:tool_call_start, _}, &1))

    assert {:usage,
            %{
              input_tokens: 10,
              output_tokens: 4,
              total_tokens: 14,
              reasoning_tokens: 2,
              cache_read_tokens: 3
            }} in events

    assert {:provider_item, %{type: "grounding_metadata", metadata: _metadata}} =
             Enum.find(events, &match?({:provider_item, %{type: "grounding_metadata"}}, &1))

    assert {:meta, %{finish_reason: :tool_calls, terminal?: true}} in events
  end
end
