defmodule ReqLlmNext.OpenAI.Realtime do
  @moduledoc """
  OpenAI Realtime WebSocket helpers.
  """

  alias ReqLlmNext.Realtime, as: CoreRealtime
  alias ReqLlmNext.Realtime.Command
  alias ReqLlmNext.Realtime.Event
  alias ReqLlmNext.OpenAI.Realtime.{SemanticProtocol, Wire}

  @spec stream(ReqLlmNext.model_spec(), Enumerable.t() | [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(model_source, events, opts \\ []) do
    with {:ok, commands} <- normalize_commands(events),
         {:ok, stream} <- CoreRealtime.stream(model_source, commands, opts) do
      {:ok, Stream.flat_map(stream, &legacy_chunks/1)}
    end
  end

  @spec websocket_url(ReqLlmNext.model_spec(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def websocket_url(model_source, opts \\ []), do: CoreRealtime.websocket_url(model_source, opts)

  @spec decode_event(map() | binary()) :: [term()]
  def decode_event(event) do
    event
    |> Wire.decode_wire_event()
    |> Enum.flat_map(&SemanticProtocol.decode_event(&1, nil))
    |> Enum.reject(&is_nil/1)
  end

  @spec session_update(keyword()) :: map()
  def session_update(opts \\ []) do
    session =
      %{}
      |> maybe_put(:instructions, Keyword.get(opts, :instructions))
      |> maybe_put(:input_audio_format, Keyword.get(opts, :input_audio_format))
      |> maybe_put(:output_audio_format, Keyword.get(opts, :output_audio_format))
      |> maybe_put(:tools, Keyword.get(opts, :tools))

    %{type: "session.update", session: session}
  end

  @spec conversation_item_create(map()) :: map()
  def conversation_item_create(item) when is_map(item) do
    %{type: "conversation.item.create", item: item}
  end

  @spec input_audio_buffer_append(binary()) :: map()
  def input_audio_buffer_append(audio) when is_binary(audio) do
    %{type: "input_audio_buffer.append", audio: Base.encode64(audio)}
  end

  @spec input_audio_buffer_commit() :: map()
  def input_audio_buffer_commit do
    %{type: "input_audio_buffer.commit"}
  end

  @spec response_create(keyword()) :: map()
  def response_create(opts \\ []) do
    response =
      %{}
      |> maybe_put(:instructions, Keyword.get(opts, :instructions))
      |> maybe_put(:tools, Keyword.get(opts, :tools))
      |> maybe_put(:conversation, Keyword.get(opts, :conversation))
      |> maybe_put(:input, Keyword.get(opts, :input))
      |> maybe_put(:metadata, Keyword.get(opts, :metadata))
      |> maybe_put(:max_output_tokens, Keyword.get(opts, :max_output_tokens))
      |> maybe_put(:output_modalities, Keyword.get(opts, :output_modalities))
      |> maybe_put(:audio, Keyword.get(opts, :audio))

    %{type: "response.create", response: response}
  end

  @spec response_cancel() :: map()
  def response_cancel do
    %{type: "response.cancel"}
  end

  defp normalize_commands(events) do
    events
    |> Enum.to_list()
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case normalize_command(event) do
        {:ok, command} -> {:cont, {:ok, acc ++ [command]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_command(%Command{} = command), do: {:ok, command}

  defp normalize_command(%{type: "session.update", session: session}) when is_map(session) do
    {:ok, Command.session_update(session)}
  end

  defp normalize_command(%{type: "conversation.item.create", item: item}) when is_map(item) do
    {:ok, Command.conversation_item_create(item)}
  end

  defp normalize_command(%{type: "input_audio_buffer.append", audio: encoded})
       when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, audio} -> {:ok, Command.input_audio_append(audio)}
      :error -> {:error, invalid_command(encoded)}
    end
  end

  defp normalize_command(%{type: "input_audio_buffer.commit"}) do
    {:ok, Command.input_audio_commit()}
  end

  defp normalize_command(%{type: "response.create", response: response}) when is_map(response) do
    {:ok, Command.response_create(response)}
  end

  defp normalize_command(%{type: "response.cancel"}) do
    {:ok, Command.response_cancel()}
  end

  defp normalize_command(command), do: {:error, invalid_command(command)}

  defp legacy_chunks(%Event{type: :text_delta, data: text}) when is_binary(text), do: [text]

  defp legacy_chunks(%Event{type: :thinking_delta, data: text}) when is_binary(text),
    do: [{:thinking, text}]

  defp legacy_chunks(%Event{type: :audio_delta, data: data}) when is_binary(data),
    do: [{:audio, data}]

  defp legacy_chunks(%Event{type: :transcript_delta, data: text}) when is_binary(text),
    do: [{:transcript, text}]

  defp legacy_chunks(%Event{type: :tool_call_start, data: data}) when is_map(data),
    do: [{:tool_call_start, data}]

  defp legacy_chunks(%Event{type: :tool_call_delta, data: data}) when is_map(data),
    do: [{:tool_call_delta, data}]

  defp legacy_chunks(%Event{type: :usage, data: usage}) when is_map(usage), do: [{:usage, usage}]
  defp legacy_chunks(%Event{type: :meta, data: meta}) when is_map(meta), do: [{:meta, meta}]
  defp legacy_chunks(%Event{type: :error, data: error}) when is_map(error), do: [{:error, error}]

  defp legacy_chunks(%Event{type: :provider_event, data: event}) when is_map(event),
    do: [{:event, event}]

  defp legacy_chunks(_event), do: []

  defp invalid_command(command) do
    ArgumentError.exception("Unsupported OpenAI realtime command: #{inspect(command)}")
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
