defmodule ReqLlmNext.OpenAI.Realtime.SemanticProtocol do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(:done, _model), do: [nil]

  def decode_event({:decode_error, decode_error}, _model) do
    [
      {:error,
       %{
         message: "Failed to decode Realtime event: #{inspect(decode_error)}",
         type: "decode_error"
       }}
    ]
  end

  def decode_event(%{"type" => "error", "error" => error}, _model) do
    [
      {:error,
       %{
         type: error["type"] || "api_error",
         message: error["message"] || "Unknown realtime error",
         code: error["code"]
       }}
    ]
  end

  def decode_event(%{"type" => "response.text.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [delta]
  end

  def decode_event(%{"type" => "response.audio.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [{:audio, delta}]
  end

  def decode_event(%{"type" => "response.audio_transcript.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [{:transcript, delta}]
  end

  def decode_event(
        %{"type" => "response.output_item.added", "item" => %{"type" => "function_call"} = item},
        _model
      ) do
    index = item["output_index"] || 0
    call_id = item["call_id"] || item["id"]
    name = item["name"]

    if name && name != "" do
      [{:tool_call_start, %{index: index, id: call_id, name: name}}]
    else
      []
    end
  end

  def decode_event(
        %{"type" => "response.function_call_arguments.delta", "delta" => fragment} = data,
        _model
      )
      when is_binary(fragment) and fragment != "" do
    index = data["output_index"] || data["index"] || 0
    [{:tool_call_delta, %{index: index, function: %{"arguments" => fragment}}}]
  end

  def decode_event(%{"type" => "response.done"} = event, _model) do
    meta =
      %{terminal?: true, finish_reason: :stop}
      |> maybe_put(:response_id, get_in(event, ["response", "id"]))

    [{:meta, meta}]
  end

  def decode_event(%{"type" => _type} = event, _model) do
    [{:event, event}]
  end

  def decode_event(_event, _model), do: []

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
