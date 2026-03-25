defmodule ReqLlmNext.RealtimeAdapterContractTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Providers.OpenAI.Realtime.Adapter, as: OpenAIAdapter
  alias ReqLlmNext.Realtime.{Command, Event, Session}
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.TestSupport.FakeRealtimeAdapter

  test "adapter modules implement the shared realtime behaviour" do
    for adapter <- [OpenAIAdapter, FakeRealtimeAdapter] do
      behaviours = adapter.module_info(:attributes)[:behaviour] || []
      assert ReqLlmNext.Realtime.Adapter in behaviours
    end
  end

  test "different adapters encode the same canonical command into provider-specific events" do
    command = Command.session_update(instructions: "Be concise")

    assert OpenAIAdapter.encode_command(TestModels.openai(), command, %{}) == %{
             type: "session.update",
             session: %{instructions: "Be concise"}
           }

    assert FakeRealtimeAdapter.encode_command(
             TestModels.minimal(%{provider: :fake, id: "fake-realtime"}),
             command,
             []
           ) == %{
             event: "session.configure",
             payload: %{instructions: "Be concise"}
           }
  end

  test "different adapters decode into the same canonical session model" do
    fake_model = TestModels.minimal(%{provider: :fake, id: "fake-realtime"})

    events =
      OpenAIAdapter.decode_event(%{"type" => "response.text.delta", "delta" => "Hello"}, TestModels.openai(), []) ++
        FakeRealtimeAdapter.decode_event(%{"kind" => "reasoning", "text" => "Think"}, fake_model, []) ++
        FakeRealtimeAdapter.decode_event(%{"kind" => "media.audio", "chunk" => "YmFzZTY0"}, fake_model, []) ++
        FakeRealtimeAdapter.decode_event(%{"kind" => "tool", "index" => 0, "name" => "lookup"}, fake_model, []) ++
        FakeRealtimeAdapter.decode_event(%{"kind" => "tool.delta", "index" => 0, "arguments" => "{\"city\":\"Austin\"}"}, fake_model, []) ++
        FakeRealtimeAdapter.decode_event(%{"kind" => "done", "id" => "resp_fake"}, fake_model, [])

    assert Enum.all?(events, &match?(%Event{}, &1))

    reduced =
      Session.new!(%{model: fake_model})
      |> Session.apply_events(events)

    assert Session.text(reduced) == "Hello"
    assert Session.thinking(reduced) == "Think"
    assert Session.audio_chunks(reduced) == ["YmFzZTY0"]
    assert Enum.map(Session.channel_items(reduced, :tools), & &1.type) == [:tool_call]
    assert reduced.response_id == "resp_fake"
  end

  test "non-openai adapter websocket urls stay provider-owned" do
    model = TestModels.minimal(%{provider: :fake, id: "fake-realtime"})
    assert FakeRealtimeAdapter.websocket_url(model, []) == "realtime://fake.example/sessions/fake-realtime"
  end
end
