defmodule ReqLlmNext.SemanticProtocols.OpenAIResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.OpenAIResponses
  alias ReqLlmNext.TestModels

  describe "text and reasoning deltas" do
    test "normalizes text deltas" do
      assert OpenAIResponses.decode_event(
               %{"type" => "response.output_text.delta", "delta" => "Hello"},
               nil
             ) ==
               ["Hello"]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.output_text.delta", "delta" => ""},
               nil
             ) == []

      assert OpenAIResponses.decode_event(%{"type" => "response.output_text.delta"}, nil) == []
    end

    test "normalizes reasoning deltas" do
      assert OpenAIResponses.decode_event(
               %{"type" => "response.reasoning.delta", "delta" => "Thinking..."},
               nil
             ) ==
               [{:thinking, "Thinking..."}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.reasoning.delta", "delta" => ""},
               nil
             ) == []

      assert OpenAIResponses.decode_event(%{"type" => "response.reasoning.delta"}, nil) == []
    end
  end

  describe "tool-call normalization" do
    test "normalizes function call starts from output_item.added" do
      event = %{
        "type" => "response.output_item.added",
        "output_index" => 0,
        "item" => %{
          "type" => "function_call",
          "call_id" => "call_123",
          "name" => "get_weather"
        }
      }

      assert OpenAIResponses.decode_event(event, nil) == [
               {:tool_call_start, %{index: 0, id: "call_123", name: "get_weather"}}
             ]
    end

    test "uses id field when call_id is missing" do
      event = %{
        "type" => "response.output_item.added",
        "output_index" => 0,
        "item" => %{
          "type" => "function_call",
          "id" => "call_456",
          "name" => "get_weather"
        }
      }

      assert OpenAIResponses.decode_event(event, nil) == [
               {:tool_call_start, %{index: 0, id: "call_456", name: "get_weather"}}
             ]
    end

    test "ignores malformed function call starts" do
      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.output_item.added",
                 "item" => %{"type" => "function_call", "call_id" => "call_123", "name" => ""}
               },
               nil
             ) == []

      assert OpenAIResponses.decode_event(
               %{"type" => "response.output_item.added", "item" => %{"type" => "text"}},
               nil
             ) == []
    end

    test "normalizes function call argument deltas" do
      event = %{
        "type" => "response.function_call_arguments.delta",
        "output_index" => 0,
        "delta" => ~s({"location":)
      }

      assert OpenAIResponses.decode_event(event, nil) == [
               {:tool_call_delta, %{index: 0, function: %{"arguments" => ~s({"location":)}}}
             ]

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.function_call_arguments.delta",
                 "index" => 1,
                 "delta" => ~s({"a":1})
               },
               nil
             ) == [
               {:tool_call_delta, %{index: 1, function: %{"arguments" => ~s({"a":1})}}}
             ]
    end

    test "ignores empty function call argument fragments" do
      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.function_call_arguments.delta",
                 "output_index" => 0,
                 "delta" => ""
               },
               nil
             ) == []
    end

    test "normalizes function_call.delta variants" do
      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.function_call.delta",
                 "output_index" => 0,
                 "call_id" => "call_789",
                 "delta" => %{"name" => "get_weather"}
               },
               nil
             ) == [
               {:tool_call_start, %{index: 0, id: "call_789", name: "get_weather"}}
             ]

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.function_call.delta",
                 "output_index" => 1,
                 "delta" => %{"arguments" => ~s({"city":"NYC"})}
               },
               nil
             ) == [
               {:tool_call_delta, %{index: 1, function: %{"arguments" => ~s({"city":"NYC"})}}}
             ]

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.function_call.delta",
                 "output_index" => 0,
                 "call_id" => "call_abc",
                 "delta" => %{"name" => "get_info", "arguments" => ~s({"id":1})}
               },
               nil
             ) == [
               {:tool_call_start, %{index: 0, id: "call_abc", name: "get_info"}},
               {:tool_call_delta, %{index: 0, function: %{"arguments" => ~s({"id":1})}}}
             ]
    end
  end

  describe "usage normalization" do
    test "normalizes usage events with reasoning and cached tokens" do
      model = TestModels.openai_reasoning()

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.usage",
                 "usage" => %{
                   "input_tokens" => 10,
                   "output_tokens" => 20,
                   "output_tokens_details" => %{"reasoning_tokens" => 5},
                   "input_tokens_details" => %{"cached_tokens" => 3}
                 }
               },
               model
             ) == [
               {:usage,
                %{
                  input_tokens: 10,
                  output_tokens: 20,
                  total_tokens: 30,
                  reasoning_tokens: 5,
                  cache_read_tokens: 3
                }}
             ]
    end

    test "normalizes usage events with top-level reasoning tokens" do
      model = TestModels.openai_reasoning()

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.usage",
                 "usage" => %{
                   "input_tokens" => 10,
                   "output_tokens" => 20,
                   "reasoning_tokens" => 8
                 }
               },
               model
             ) == [
               {:usage,
                %{
                  input_tokens: 10,
                  output_tokens: 20,
                  total_tokens: 30,
                  reasoning_tokens: 8
                }}
             ]
    end

    test "omits optional usage fields when absent" do
      model = TestModels.openai_reasoning()

      assert OpenAIResponses.decode_event(
               %{
                 "type" => "response.usage",
                 "usage" => %{"input_tokens" => 10, "output_tokens" => 20}
               },
               model
             ) == [
               {:usage, %{input_tokens: 10, output_tokens: 20, total_tokens: 30}}
             ]
    end
  end

  describe "terminal events" do
    test "normalizes completed events into terminal meta and usage" do
      event = %{
        "type" => "response.completed",
        "response" => %{
          "id" => "resp_123",
          "usage" => %{
            "input_tokens" => 5,
            "output_tokens" => 7,
            "output_tokens_details" => %{"reasoning_tokens" => 2}
          }
        }
      }

      assert [
               {:usage, usage},
               {:meta, %{terminal?: true, response_id: "resp_123", finish_reason: :stop}}
             ] = OpenAIResponses.decode_event(event, nil)

      assert usage.input_tokens == 5
      assert usage.output_tokens == 7
      assert usage.reasoning_tokens == 2
    end

    test "normalizes completed events without usage" do
      assert OpenAIResponses.decode_event(
               %{"type" => "response.completed", "response" => %{"id" => "resp_456"}},
               nil
             ) == [
               {:meta, %{terminal?: true, finish_reason: :stop, response_id: "resp_456"}}
             ]
    end

    test "normalizes incomplete finish reasons" do
      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "max_output_tokens"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :length}}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "max_tokens"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :length}}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "stop"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :stop}}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "tool_calls"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :tool_calls}}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "content_filter"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :content_filter}}]

      assert OpenAIResponses.decode_event(
               %{"type" => "response.incomplete", "reason" => "something_unknown"},
               nil
             ) ==
               [{:meta, %{terminal?: true, finish_reason: :error}}]
    end

    test "ignores non-semantic done events" do
      assert OpenAIResponses.decode_event(%{"type" => "response.output_text.done"}, nil) == []
      assert OpenAIResponses.decode_event(%{"type" => "response.output_item.done"}, nil) == []

      assert OpenAIResponses.decode_event(
               %{"type" => "response.function_call_arguments.done"},
               nil
             ) == []

      assert OpenAIResponses.decode_event(%{"type" => "response.unknown.type"}, nil) == []
    end
  end

  describe "error normalization" do
    test "normalizes explicit API errors" do
      assert OpenAIResponses.decode_event(
               %{
                 "error" => %{
                   "type" => "rate_limit_error",
                   "message" => "Too many requests",
                   "code" => "rate_limited"
                 }
               },
               nil
             ) == [
               {:error,
                %{type: "rate_limit_error", message: "Too many requests", code: "rate_limited"}}
             ]
    end

    test "fills missing error fields and handles decode errors" do
      assert OpenAIResponses.decode_event(%{"error" => %{}}, nil) == [
               {:error, %{message: "Unknown API error", type: "api_error", code: nil}}
             ]

      assert OpenAIResponses.decode_event(
               {:decode_error, %Jason.DecodeError{position: 1, token: nil, data: ""}},
               nil
             ) ==
               [
                 {:error,
                  %{
                    type: "decode_error",
                    message:
                      "Failed to decode SSE event: %Jason.DecodeError{position: 1, token: nil, data: \"\"}"
                  }}
               ]
    end

    test "treats done tokens and unknown payloads consistently" do
      assert OpenAIResponses.decode_event(:done, nil) == [nil]
      assert OpenAIResponses.decode_event(:something_else, nil) == []
    end
  end
end
