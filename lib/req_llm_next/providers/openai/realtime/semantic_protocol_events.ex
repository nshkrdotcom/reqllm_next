defmodule ReqLlmNext.Providers.OpenAI.Realtime.SemanticProtocolEvents do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Realtime.Event

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(:done, _model), do: [Event.meta(%{terminal?: true, finish_reason: :stop})]

  def decode_event({:decode_error, decode_error}, _model) do
    [Event.error(%{type: "decode_error", message: inspect(decode_error)})]
  end

  def decode_event(%{"type" => "error", "error" => error}, _model) do
    [
      Event.error(%{
        type: error["type"] || "api_error",
        message: error["message"] || "Unknown realtime error",
        code: error["code"]
      })
    ]
  end

  def decode_event(%{"type" => "response.text.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [Event.text_delta(delta)]
  end

  def decode_event(%{"type" => "response.audio.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [Event.audio_delta(delta)]
  end

  def decode_event(%{"type" => "response.audio_transcript.delta", "delta" => delta}, _model)
      when is_binary(delta) and delta != "" do
    [Event.transcript_delta(delta)]
  end

  def decode_event(
        %{"type" => "response.output_item.added", "item" => %{"type" => "function_call"} = item},
        _model
      ) do
    index = item["output_index"] || 0
    call_id = item["call_id"] || item["id"]
    name = item["name"]

    if name && name != "" do
      [Event.tool_call_start(%{index: index, id: call_id, name: name})]
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
    [Event.tool_call_delta(%{index: index, function: %{"arguments" => fragment}})]
  end

  def decode_event(%{"type" => "response.done"} = event, _model) do
    usage = get_in(event, ["response", "usage"])

    meta =
      %{
        terminal?: true,
        finish_reason: :stop,
        response_id: get_in(event, ["response", "id"])
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    maybe_usage_event(usage) ++ [Event.meta(meta)]
  end

  def decode_event(%{"type" => _type} = event, _model) do
    [Event.provider_event(event)]
  end

  def decode_event(_event, _model), do: []

  defp maybe_usage_event(usage) when is_map(usage), do: [Event.usage(usage)]
  defp maybe_usage_event(_usage), do: []
end
