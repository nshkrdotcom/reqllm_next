defmodule ReqLlmNext.Executor.StreamStateTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Executor.StreamState

  defmodule FakeWire do
    def decode_wire_event(%{data: "[DONE]"}), do: [:done]
    def decode_wire_event(%{data: data}), do: [%{"text" => data}]
  end

  defmodule FakeProtocol do
    def decode_event(:done, _model), do: [nil]
    def decode_event(%{"text" => text}, _model), do: [text]
  end

  describe "struct definition (Zoi)" do
    test "schema/0 returns Zoi schema" do
      assert is_struct(StreamState.schema())
    end

    test "new!/1 provides default values" do
      state = StreamState.new!(%{protocol_mod: FakeProtocol, wire_mod: FakeWire})

      assert state.buffer == ""
      assert state.model == nil
      assert state.recorder == nil
      assert state.error == nil
    end

    test "new!/1 raises on missing required fields" do
      assert_raise ArgumentError, fn ->
        StreamState.new!(%{})
      end
    end
  end

  describe "new/4" do
    test "creates initial state with empty buffer" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      assert state.buffer == ""
      assert state.model == nil
      assert state.protocol_mod == FakeProtocol
      assert state.recorder == nil
      assert state.wire_mod == FakeWire
      assert state.error == nil
    end

    test "accepts recorder" do
      recorder = %{some: :data}
      state = StreamState.new(recorder, nil, FakeWire, FakeProtocol)

      assert state.recorder == recorder
    end
  end

  describe "handle_message/2 with :status" do
    test "status 200 continues with empty chunks" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, chunks, new_state} = StreamState.handle_message({:status, 200}, state)

      assert chunks == []
      assert new_state.error == nil
    end

    test "non-200 status yields an explicit error chunk" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, chunks, new_state} = StreamState.handle_message({:status, 500}, state)

      assert chunks == [
               {:error, %{message: "HTTP request failed with status 500", type: "http_error"}}
             ]

      assert new_state.error == {:http_error, 500}
    end

    test "404 status yields an explicit error chunk" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, chunks, new_state} = StreamState.handle_message({:status, 404}, state)

      assert chunks == [
               {:error, %{message: "HTTP request failed with status 404", type: "http_error"}}
             ]

      assert new_state.error == {:http_error, 404}
    end
  end

  describe "handle_message/2 with :headers" do
    test "headers continue with empty chunks" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)
      headers = [{"content-type", "text/event-stream"}]

      {:cont, chunks, new_state} = StreamState.handle_message({:headers, headers}, state)

      assert chunks == []
      assert new_state.error == nil
    end
  end

  describe "handle_message/2 with :data" do
    test "complete SSE event returns decoded chunks" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)
      data = "data: hello\n\n"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == ["hello"]
      assert new_state.buffer == ""
    end

    test "multiple events in one data message" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)
      data = "data: foo\n\ndata: bar\n\n"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == ["foo", "bar"]
      assert new_state.buffer == ""
    end

    test "partial SSE event is buffered" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)
      data = "data: incomplete"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == []
      assert new_state.buffer == "data: incomplete"
    end

    test "buffered data completes on next message" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, [], state} = StreamState.handle_message({:data, "data: hel"}, state)
      {:cont, chunks, state} = StreamState.handle_message({:data, "lo\n\n"}, state)

      assert chunks == ["hello"]
      assert state.buffer == ""
    end

    test "filters nil values from decoded events" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)
      data = "data: [DONE]\n\n"

      {:cont, chunks, _state} = StreamState.handle_message({:data, data}, state)

      assert chunks == []
    end
  end

  describe "handle_message/2 with :done" do
    test "done halts without error" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:halt, final_state} = StreamState.handle_message(:done, state)

      assert final_state.error == nil
    end
  end

  describe "handle_timeout/1" do
    test "sets timeout error" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      new_state = StreamState.handle_timeout(state)

      assert new_state.error == :timeout
    end
  end

  describe "full stream lifecycle" do
    test "status -> headers -> data -> done" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, [], state} = StreamState.handle_message({:status, 200}, state)
      {:cont, [], state} = StreamState.handle_message({:headers, []}, state)
      {:cont, ["Hi"], state} = StreamState.handle_message({:data, "data: Hi\n\n"}, state)
      {:halt, final_state} = StreamState.handle_message(:done, state)

      assert final_state.error == nil
      assert final_state.buffer == ""
    end

    test "error status produces an explicit error chunk" do
      state = StreamState.new(nil, nil, FakeWire, FakeProtocol)

      {:cont, chunks, final_state} = StreamState.handle_message({:status, 401}, state)

      assert chunks == [
               {:error, %{message: "HTTP request failed with status 401", type: "http_error"}}
             ]

      assert final_state.error == {:http_error, 401}
    end
  end
end
