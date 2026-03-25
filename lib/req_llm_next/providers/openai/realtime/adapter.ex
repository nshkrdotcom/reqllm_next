defmodule ReqLlmNext.Providers.OpenAI.Realtime.Adapter do
  @moduledoc false

  alias ReqLlmNext.OpenAI.Realtime.Transport
  alias ReqLlmNext.OpenAI.Realtime.Wire
  alias ReqLlmNext.Providers.OpenAI
  alias ReqLlmNext.Providers.OpenAI.Realtime.SemanticProtocolEvents
  alias ReqLlmNext.Realtime.Command

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

  @spec decode_event(map() | binary(), LLMDB.Model.t(), keyword()) :: [
          ReqLlmNext.Realtime.Event.t()
        ]
  def decode_event(event, model, _opts) do
    event
    |> Wire.decode_wire_event()
    |> Enum.flat_map(&SemanticProtocolEvents.decode_event(&1, model))
  end

  @spec websocket_url(LLMDB.Model.t(), keyword()) :: String.t()
  def websocket_url(model, opts \\ []) do
    Wire.websocket_url(OpenAI.base_url(), model, opts)
  end

  @spec stream_commands(LLMDB.Model.t(), [Command.t()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_commands(model, commands, opts \\ []) do
    encoded = Enum.map(commands, &encode_command(model, &1, opts))
    Transport.stream(OpenAI, SemanticProtocolEvents, Wire, model, encoded, opts)
  end
end
