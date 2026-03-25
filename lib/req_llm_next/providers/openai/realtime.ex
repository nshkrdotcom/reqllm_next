defmodule ReqLlmNext.OpenAI.Realtime do
  @moduledoc """
  OpenAI Realtime WebSocket helpers.
  """

  alias ReqLlmNext.ModelResolver
  alias ReqLlmNext.OpenAI.Realtime.{SemanticProtocol, Transport, Wire}
  alias ReqLlmNext.Providers.OpenAI

  @spec stream(ReqLlmNext.model_spec(), Enumerable.t() | [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(model_source, events, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source) do
      Transport.stream(OpenAI, SemanticProtocol, Wire, model, Enum.to_list(events), opts)
    end
  end

  @spec websocket_url(ReqLlmNext.model_spec(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def websocket_url(model_source, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source) do
      {:ok, Wire.websocket_url(OpenAI.base_url(), model, opts)}
    end
  end

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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
