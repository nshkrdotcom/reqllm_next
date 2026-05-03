defmodule ReqLlmNext.Providers.OpenAI.Realtime.Adapter do
  @moduledoc false

  @behaviour ReqLlmNext.Realtime.Adapter

  alias ReqLlmNext.OpenAI.Realtime.Transport
  alias ReqLlmNext.OpenAI.Realtime.Wire
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers.OpenAI
  alias ReqLlmNext.Providers.OpenAI.Realtime.SemanticProtocolEvents
  alias ReqLlmNext.Realtime.Command

  @impl ReqLlmNext.Realtime.Adapter
  @spec encode_command(LLMDB.Model.t(), Command.t(), keyword()) :: map()
  def encode_command(_model, %Command{type: :session_update, data: data}, _opts)
      when is_map(data) do
    %{type: "session.update", session: data}
  end

  def encode_command(
        _model,
        %Command{type: :conversation_item_create, data: item},
        _opts
      )
      when is_map(item) do
    %{type: "conversation.item.create", item: item}
  end

  def encode_command(_model, %Command{type: :input_audio_append, data: audio}, _opts)
      when is_binary(audio) do
    %{type: "input_audio_buffer.append", audio: Base.encode64(audio)}
  end

  def encode_command(_model, %Command{type: :input_audio_commit}, _opts) do
    %{type: "input_audio_buffer.commit"}
  end

  def encode_command(_model, %Command{type: :response_create, data: data}, _opts)
      when is_map(data) do
    %{type: "response.create", response: data}
  end

  def encode_command(_model, %Command{type: :response_cancel}, _opts) do
    %{type: "response.cancel"}
  end

  @impl ReqLlmNext.Realtime.Adapter
  @spec decode_event(map() | binary(), LLMDB.Model.t(), keyword()) :: [
          ReqLlmNext.Realtime.Event.t()
        ]
  def decode_event(event, model, _opts) do
    event
    |> Wire.decode_wire_event()
    |> Enum.flat_map(&SemanticProtocolEvents.decode_event(&1, model))
  end

  @impl ReqLlmNext.Realtime.Adapter
  @spec websocket_url(LLMDB.Model.t(), keyword()) :: String.t()
  def websocket_url(model, opts \\ []) do
    case Provider.base_url(OpenAI, opts) do
      {:ok, base_url} -> Wire.websocket_url(base_url, model, opts)
      {:error, reason} -> raise reason
    end
  end

  @impl ReqLlmNext.Realtime.Adapter
  @spec stream_commands(LLMDB.Model.t(), [Command.t()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_commands(model, commands, opts \\ []) do
    encoded = Enum.map(commands, &encode_command(model, &1, opts))
    Transport.stream(OpenAI, SemanticProtocolEvents, Wire, model, encoded, opts)
  end
end
