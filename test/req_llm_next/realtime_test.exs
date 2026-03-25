defmodule ReqLlmNext.RealtimeTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Realtime
  alias ReqLlmNext.Realtime.{Command, Event, Session}
  alias ReqLlmNext.TestModels

  test "encodes canonical commands for OpenAI realtime" do
    model = TestModels.openai()

    assert {:ok, encoded} =
             Realtime.encode_command(
               model,
               Command.session_update(instructions: "Be concise", tools: [%{name: "lookup"}])
             )

    assert encoded.type == "session.update"
    assert encoded.session.instructions == "Be concise"
    assert is_list(encoded.session.tools)
  end

  test "decodes OpenAI realtime wire events into canonical events" do
    model = TestModels.openai()

    assert {:ok, [event]} =
             Realtime.decode_event(
               model,
               Jason.encode!(%{"type" => "response.text.delta", "delta" => "Hello"})
             )

    assert %Event{type: :text_delta, data: "Hello"} = event
  end

  test "reduces canonical realtime events into session state" do
    session = Session.new!(%{model: TestModels.openai()})

    events = [
      Event.text_delta("Hello"),
      Event.audio_delta("YmFzZTY0"),
      Event.transcript_delta("spoken"),
      Event.tool_call_start(%{index: 0, id: "call_1", name: "get_weather"}),
      Event.tool_call_delta(%{index: 0, function: %{"arguments" => "{\"city\":\"Austin\"}"}}),
      Event.usage(%{input_tokens: 10, output_tokens: 4, total_tokens: 14}),
      Event.meta(%{finish_reason: :stop, response_id: "resp_123"})
    ]

    reduced = Realtime.apply_events(session, events)

    assert Session.text(reduced) == "Hello"
    assert Session.transcripts(reduced) == ["spoken"]
    assert Session.audio_chunks(reduced) == ["YmFzZTY0"]
    assert length(Session.tool_calls(reduced)) == 1
    assert reduced.usage == %{input_tokens: 10, output_tokens: 4, total_tokens: 14}
    assert reduced.finish_reason == :stop
    assert reduced.response_id == "resp_123"
  end

  test "builds websocket URLs for supported realtime models" do
    assert {:ok, url} = Realtime.websocket_url(TestModels.openai())
    assert url == "wss://api.openai.com/v1/realtime?model=test-model"
  end
end
