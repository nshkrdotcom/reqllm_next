defmodule ReqLlmNext.OpenAI.RealtimeTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Realtime
  alias ReqLlmNext.OpenAI.Realtime.SemanticProtocol
  alias ReqLlmNext.OpenAI.Realtime.Wire
  alias ReqLlmNext.TestModels

  test "builds websocket URLs for realtime models" do
    url = Wire.websocket_url("https://api.openai.com", TestModels.openai())
    assert url == "wss://api.openai.com/v1/realtime?model=test-model"
  end

  test "builds common realtime client events" do
    assert Realtime.session_update(instructions: "Be concise").type == "session.update"

    assert Realtime.conversation_item_create(%{type: "message"}).type ==
             "conversation.item.create"

    assert Realtime.input_audio_buffer_append("pcm").type == "input_audio_buffer.append"
    assert Realtime.input_audio_buffer_commit().type == "input_audio_buffer.commit"
    assert Realtime.response_create(instructions: "Answer").type == "response.create"
    assert Realtime.response_cancel().type == "response.cancel"
  end

  test "normalizes realtime server events" do
    assert SemanticProtocol.decode_event(
             %{"type" => "response.text.delta", "delta" => "Hello"},
             nil
           ) ==
             ["Hello"]

    assert SemanticProtocol.decode_event(
             %{"type" => "response.audio.delta", "delta" => "YmFzZTY0"},
             nil
           ) ==
             [{:audio, "YmFzZTY0"}]

    assert SemanticProtocol.decode_event(
             %{"type" => "response.done", "response" => %{"id" => "resp_123"}},
             nil
           ) ==
             [{:meta, %{terminal?: true, finish_reason: :stop, response_id: "resp_123"}}]
  end
end
