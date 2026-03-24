defmodule ReqLlmNext.SemanticProtocols.OpenAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.OpenAIChat
  alias ReqLlmNext.TestModels

  describe "content and tool-call deltas" do
    test "extracts content from first choice" do
      assert OpenAIChat.decode_event(
               %{
                 "choices" => [
                   %{"delta" => %{"content" => "Hello"}},
                   %{"delta" => %{"content" => "Second"}}
                 ]
               },
               nil
             ) == ["Hello"]
    end

    test "returns empty list for deltas without content or tool calls" do
      assert OpenAIChat.decode_event(
               %{"choices" => [%{"delta" => %{"role" => "assistant"}}]},
               nil
             ) == []

      assert OpenAIChat.decode_event(%{"choices" => []}, nil) == []

      assert OpenAIChat.decode_event(
               %{"id" => "chatcmpl-123", "object" => "chat.completion.chunk"},
               nil
             ) == []
    end

    test "normalizes tool-call deltas" do
      assert OpenAIChat.decode_event(
               %{
                 "choices" => [
                   %{
                     "delta" => %{
                       "tool_calls" => [
                         %{
                           "index" => 0,
                           "id" => "call_123",
                           "type" => "function",
                           "function" => %{"name" => "get_weather", "arguments" => ""}
                         }
                       ]
                     }
                   }
                 ]
               },
               nil
             ) == [
               {:tool_call_delta,
                %{
                  index: 0,
                  id: "call_123",
                  type: "function",
                  function: %{"name" => "get_weather", "arguments" => ""}
                }}
             ]

      assert OpenAIChat.decode_event(
               %{
                 "choices" => [
                   %{
                     "delta" => %{
                       "tool_calls" => [
                         %{"index" => 0, "function" => %{"arguments" => ~s({"loc)}}
                       ]
                     }
                   }
                 ]
               },
               nil
             ) == [
               {:tool_call_delta,
                %{index: 0, id: nil, type: nil, function: %{"arguments" => ~s({"loc)}}}
             ]
    end

    test "normalizes multiple tool calls in one delta" do
      assert OpenAIChat.decode_event(
               %{
                 "choices" => [
                   %{
                     "delta" => %{
                       "tool_calls" => [
                         %{
                           "index" => 0,
                           "id" => "call_1",
                           "type" => "function",
                           "function" => %{"name" => "tool1"}
                         },
                         %{
                           "index" => 1,
                           "id" => "call_2",
                           "type" => "function",
                           "function" => %{"name" => "tool2"}
                         }
                       ]
                     }
                   }
                 ]
               },
               nil
             ) == [
               {:tool_call_delta,
                %{index: 0, id: "call_1", type: "function", function: %{"name" => "tool1"}}},
               {:tool_call_delta,
                %{index: 1, id: "call_2", type: "function", function: %{"name" => "tool2"}}}
             ]
    end
  end

  describe "usage and errors" do
    test "normalizes usage-only and mixed content+usage payloads" do
      model = TestModels.openai()

      assert OpenAIChat.decode_event(
               %{"choices" => [], "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}},
               model
             ) == [{:usage, %{input_tokens: 10, output_tokens: 5, total_tokens: 15}}]

      assert OpenAIChat.decode_event(
               %{
                 "choices" => [%{"delta" => %{"content" => "Hi"}}],
                 "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
               },
               model
             ) == [
               "Hi",
               {:usage, %{input_tokens: 10, output_tokens: 5, total_tokens: 15}}
             ]

      assert OpenAIChat.decode_event(
               %{
                 "usage" => %{
                   "prompt_tokens" => 100,
                   "completion_tokens" => 50,
                   "total_tokens" => 150
                 }
               },
               model
             ) == [{:usage, %{input_tokens: 100, output_tokens: 50, total_tokens: 150}}]
    end

    test "normalizes api errors and decode errors" do
      assert OpenAIChat.decode_event(
               %{
                 "error" => %{
                   "message" => "Rate limit exceeded",
                   "type" => "rate_limit_error",
                   "code" => "rate_limit"
                 }
               },
               nil
             ) == [
               {:error,
                %{message: "Rate limit exceeded", type: "rate_limit_error", code: "rate_limit"}}
             ]

      assert OpenAIChat.decode_event(%{"error" => %{"message" => "Something went wrong"}}, nil) ==
               [{:error, %{message: "Something went wrong", type: "api_error", code: nil}}]

      assert OpenAIChat.decode_event(%{"error" => %{}}, nil) ==
               [{:error, %{message: "Unknown API error", type: "api_error", code: nil}}]

      assert OpenAIChat.decode_event(
               {:decode_error, %Jason.DecodeError{position: 1, token: nil, data: ""}},
               nil
             ) == [
               {:error,
                %{
                  type: "decode_error",
                  message:
                    "Failed to decode SSE event: %Jason.DecodeError{position: 1, token: nil, data: \"\"}"
                }}
             ]
    end

    test "treats done tokens consistently" do
      assert OpenAIChat.decode_event(:done, nil) == [nil]
    end
  end
end
