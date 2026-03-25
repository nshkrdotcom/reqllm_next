defmodule ReqLlmNext.SemanticProtocols.AnthropicMessagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.SemanticProtocols.AnthropicMessages
  alias ReqLlmNext.TestModels

  describe "text, usage, and terminal events" do
    test "normalizes terminal and usage events" do
      model = TestModels.anthropic()

      assert AnthropicMessages.decode_event(:done, nil) == [nil]
      assert AnthropicMessages.decode_event(%{"type" => "message_stop"}, nil) == [nil]

      assert AnthropicMessages.decode_event(
               %{"type" => "message_delta", "usage" => %{"output_tokens" => 10}},
               model
             ) == [{:usage, %{input_tokens: 0, output_tokens: 10, total_tokens: 10}}]
    end

    test "normalizes text deltas and response metadata" do
      assert AnthropicMessages.decode_event(
               %{"type" => "content_block_delta", "delta" => %{"text" => "Hello"}},
               nil
             ) == ["Hello"]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_delta",
                 "delta" => %{"type" => "text_delta", "text" => "World"}
               },
               nil
             ) == ["World"]

      assert AnthropicMessages.decode_event(
               %{"type" => "message_start", "message" => %{"id" => "msg_123"}},
               nil
             ) == [{:meta, %{response_id: "msg_123"}}]

      assert AnthropicMessages.decode_event(
               %{"type" => "content_block_start", "content_block" => %{"type" => "text"}},
               nil
             ) == []

      assert AnthropicMessages.decode_event(%{"type" => "content_block_stop"}, nil) == []
      assert AnthropicMessages.decode_event(%{"type" => "ping"}, nil) == []
    end
  end

  describe "thinking and tool-use normalization" do
    test "normalizes thinking start and delta variants" do
      assert AnthropicMessages.decode_event(
               %{"type" => "content_block_start", "content_block" => %{"type" => "thinking"}},
               nil
             ) == [{:thinking_start, nil}]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_start",
                 "content_block" => %{"type" => "thinking", "thinking" => "Let me think..."}
               },
               nil
             ) == [{:thinking_start, nil}, {:thinking, "Let me think..."}]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_start",
                 "content_block" => %{"type" => "thinking", "text" => "Initial thought"}
               },
               nil
             ) == [{:thinking_start, nil}, {:thinking, "Initial thought"}]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_delta",
                 "delta" => %{"type" => "thinking_delta", "thinking" => "more thoughts"}
               },
               nil
             ) == [{:thinking, "more thoughts"}]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_delta",
                 "delta" => %{"type" => "thinking_delta", "text" => "alternative format"}
               },
               nil
             ) == [{:thinking, "alternative format"}]
    end

    test "normalizes tool use starts and partial json deltas" do
      event = %{
        "type" => "content_block_start",
        "index" => 1,
        "content_block" => %{
          "type" => "tool_use",
          "id" => "tool_123",
          "name" => "lookup_weather"
        }
      }

      assert AnthropicMessages.decode_event(event, nil) == [
               {:tool_call_start, %{index: 1, id: "tool_123", name: "lookup_weather"}}
             ]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_delta",
                 "index" => 0,
                 "delta" => %{"type" => "input_json_delta", "partial_json" => "{\"location\""}
               },
               nil
             ) == [{:tool_call_delta, %{index: 0, partial_json: "{\"location\""}}]
    end

    test "normalizes citation-bearing text blocks and stop reasons" do
      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_start",
                 "content_block" => %{
                   "type" => "text",
                   "text" => "Cited text",
                   "citations" => [%{"type" => "char_location", "cited_text" => "Cited text"}]
                 }
               },
               nil
             ) == [
               {:content_part,
                ReqLlmNext.Context.ContentPart.text("Cited text", %{
                  citations: [%{"type" => "char_location", "cited_text" => "Cited text"}]
                })}
             ]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "message_delta",
                 "delta" => %{"stop_reason" => "pause_turn"}
               },
               nil
             ) == [{:meta, %{finish_reason: :stop, anthropic_stop_reason: "pause_turn"}}]

      assert AnthropicMessages.decode_event(
               %{
                 "type" => "message_delta",
                 "delta" => %{"stop_reason" => "compaction"},
                 "context_management" => %{
                   "applied_edits" => [%{"type" => "compact_20260112"}]
                 }
               },
               nil
             ) == [
               {:meta, %{finish_reason: :stop, anthropic_stop_reason: "compaction"}},
               {:meta,
                %{
                  anthropic_context_management: %{
                    "applied_edits" => [%{"type" => "compact_20260112"}]
                  },
                  anthropic_applied_edits: [%{"type" => "compact_20260112"}]
                }}
             ]
    end

    test "preserves compaction blocks as provider items" do
      assert AnthropicMessages.decode_event(
               %{
                 "type" => "content_block_start",
                 "content_block" => %{
                   "type" => "compaction",
                   "summary" => "Conversation compacted"
                 }
               },
               nil
             ) == [
               {:provider_item, %{"anthropic_type" => "compaction", "summary" => "Conversation compacted", "type" => "compaction"}}
             ]
    end
  end

  describe "error normalization" do
    test "normalizes api and decode errors" do
      assert AnthropicMessages.decode_event(
               %{
                 "type" => "error",
                 "error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}
               },
               nil
             ) == [{:error, %{type: "rate_limit_error", message: "Too many requests"}}]

      assert AnthropicMessages.decode_event(
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
  end
end
