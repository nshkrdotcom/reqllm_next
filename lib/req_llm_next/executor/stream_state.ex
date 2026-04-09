defmodule ReqLlmNext.Executor.StreamState do
  @moduledoc false

  alias ExecutionPlane.SSE
  alias ReqLlmNext.Fixtures

  @schema Zoi.struct(
            __MODULE__,
            %{
              buffer: Zoi.string() |> Zoi.default(""),
              model: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              protocol_mod: Zoi.atom(),
              recorder: Zoi.map() |> Zoi.nullish() |> Zoi.default(nil),
              wire_mod: Zoi.atom(),
              error: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil)
            },
            coerce: true
          )

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
          | {:sse, binary(), [map()]}
          | {:frame, binary()}
          | {:transport_error, term()}
          | {:close, non_neg_integer() | nil, binary() | nil}
          | :transport_timeout
          | :done

  @type result ::
          {:cont, [term()], t()}
          | {:halt, t()}

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, state} -> state
      {:error, reason} -> raise ArgumentError, "Invalid stream state: #{inspect(reason)}"
    end
  end

  @spec new(map() | nil, LLMDB.Model.t() | nil, module(), module()) :: t()
  def new(recorder, model, wire_mod, protocol_mod) do
    new!(%{
      buffer: "",
      model: model,
      protocol_mod: protocol_mod,
      recorder: recorder,
      wire_mod: wire_mod,
      error: nil
    })
  end

  @spec handle_message(msg(), t()) :: result()
  def handle_message({:status, status}, %__MODULE__{} = state) when status not in [101, 200] do
    new_recorder = Fixtures.record_status(state.recorder, status)
    Fixtures.save_fixture(new_recorder)

    error_chunk =
      {:error, %{message: "HTTP request failed with status #{status}", type: "http_error"}}

    {:cont, [error_chunk], %{state | recorder: new_recorder, error: {:http_error, status}}}
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
    {events, remaining} = SSE.parse(new_buffer)
    chunks = decode_events(events, state)

    new_state = %{state | buffer: remaining, recorder: new_recorder}

    {:cont, chunks, new_state}
  end

  def handle_message({:sse, data, events}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_chunk(state.recorder, data)
    chunks = decode_events(events, state)

    {:cont, chunks, %{state | recorder: new_recorder}}
  end

  def handle_message({:frame, data}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_chunk(state.recorder, data)
    chunks = decode_events([%{data: data}], state)

    {:cont, chunks, %{state | recorder: new_recorder}}
  end

  def handle_message({:transport_error, reason}, %__MODULE__{} = state) do
    error_chunk =
      {:error, %{message: "Transport failed: #{inspect(reason)}", type: "transport_error"}}

    {:cont, [error_chunk], %{state | error: {:transport_error, reason}}}
  end

  def handle_message({:close, _code, _reason}, %__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    {:halt, state}
  end

  def handle_message(:transport_timeout, %__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    {:halt, %{state | error: :timeout}}
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
