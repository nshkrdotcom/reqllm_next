defmodule ReqLlmNext.Executor.StreamState do
  @moduledoc false

  alias ReqLlmNext.Fixtures

  defstruct [:buffer, :model, :protocol_mod, :recorder, :wire_mod, :error]

  @type t :: %__MODULE__{
          buffer: binary(),
          model: LLMDB.Model.t() | nil,
          protocol_mod: module(),
          recorder: map() | nil,
          wire_mod: module(),
          error: term() | nil
        }

  @type msg ::
          {:status, non_neg_integer()}
          | {:headers, list()}
          | {:data, binary()}
          | {:frame, binary()}
          | :done

  @type result ::
          {:cont, [String.t()], t()}
          | {:halt, t()}

  @spec new(map() | nil, LLMDB.Model.t() | nil, module(), module()) :: t()
  def new(recorder, model, wire_mod, protocol_mod) do
    %__MODULE__{
      buffer: "",
      model: model,
      protocol_mod: protocol_mod,
      recorder: recorder,
      wire_mod: wire_mod,
      error: nil
    }
  end

  @spec handle_message(msg(), t()) :: result()
  def handle_message({:status, status}, %__MODULE__{} = state) when status not in [101, 200] do
    Fixtures.save_fixture(state.recorder)
    {:halt, %{state | error: {:http_error, status}}}
  end

  def handle_message({:status, status}, %__MODULE__{} = state) when status in [101, 200] do
    new_recorder = Fixtures.record_status(state.recorder, status)
    {:cont, [], %{state | recorder: new_recorder}}
  end

  def handle_message({:headers, headers}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_headers(state.recorder, headers)
    {:cont, [], %{state | recorder: new_recorder}}
  end

  def handle_message({:data, data}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_chunk(state.recorder, data)
    new_buffer = state.buffer <> data
    {events, remaining} = ServerSentEvents.parse(new_buffer)
    chunks = decode_events(events, state)

    new_state = %{state | buffer: remaining, recorder: new_recorder}

    {:cont, chunks, new_state}
  end

  def handle_message({:frame, data}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_chunk(state.recorder, data)
    chunks = decode_events([%{data: data}], state)

    {:cont, chunks, %{state | recorder: new_recorder}}
  end

  def handle_message(:done, %__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    {:halt, state}
  end

  @spec handle_timeout(t()) :: t()
  def handle_timeout(%__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    %{state | error: :timeout}
  end

  defp decode_events(events, state) do
    events
    |> Enum.flat_map(fn event -> state.wire_mod.decode_wire_event(event) end)
    |> Enum.flat_map(&state.protocol_mod.decode_event(&1, state.model))
    |> Enum.reject(&is_nil/1)
  end
end
