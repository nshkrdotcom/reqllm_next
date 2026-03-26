defmodule ReqLlmNext.SemanticProtocols.GoogleGenerateContent do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(:done, _model), do: [nil]

  def decode_event({:decode_error, decode_error}, _model) do
    [
      {:error,
       %{
         message: "Failed to decode SSE event: #{inspect(decode_error)}",
         type: "decode_error"
       }}
    ]
  end

  def decode_event(%{"error" => error}, _model) do
    message = error["message"] || "Unknown API error"
    error_type = error["status"] || error["code"] || "api_error"
    [{:error, %{message: message, type: error_type}}]
  end

  def decode_event(
        %{"candidates" => [%{"content" => %{"parts" => parts}} = candidate | _]} = payload,
        _model
      )
      when is_list(parts) do
    part_chunks = decode_parts(parts)
    provider_chunks = decode_provider_metadata(candidate)
    usage_chunks = decode_usage(payload["usageMetadata"])
    meta_chunks = decode_finish_reason(candidate, part_chunks)

    part_chunks ++ provider_chunks ++ usage_chunks ++ meta_chunks
  end

  def decode_event(%{"usageMetadata" => usage_metadata}, _model) when is_map(usage_metadata) do
    decode_usage(usage_metadata)
  end

  def decode_event(_event, _model), do: []

  defp decode_parts(parts) do
    parts
    |> Enum.with_index()
    |> Enum.flat_map(fn {part, index} ->
      cond do
        is_binary(part["text"]) and part["text"] != "" and part["thought"] == true ->
          [{:thinking, part["text"]}]

        is_binary(part["text"]) and part["text"] != "" ->
          [part["text"]]

        is_map(part["functionCall"]) ->
          decode_function_call(part["functionCall"], index)

        true ->
          []
      end
    end)
  end

  defp decode_function_call(call, index) do
    id = call["id"] || "call_#{index}"
    name = call["name"]
    arguments = Jason.encode!(call["args"] || %{})

    [
      {:tool_call_start, %{index: index, id: id, name: name}},
      {:tool_call_delta,
       %{
         index: index,
         id: id,
         type: "function",
         function: %{"name" => name, "arguments" => arguments}
       }}
    ]
  end

  defp decode_provider_metadata(candidate) do
    []
    |> maybe_append_provider_item("grounding_metadata", candidate["groundingMetadata"])
    |> maybe_append_provider_item("url_context_metadata", candidate["urlContextMetadata"])
  end

  defp maybe_append_provider_item(chunks, _type, nil), do: chunks

  defp maybe_append_provider_item(chunks, type, metadata) when is_map(metadata) do
    chunks ++ [{:provider_item, %{type: type, metadata: metadata}}]
  end

  defp decode_usage(usage_metadata) when is_map(usage_metadata) do
    prompt = usage_metadata["promptTokenCount"] || 0
    total = usage_metadata["totalTokenCount"] || prompt
    reasoning = usage_metadata["thoughtsTokenCount"] || 0
    cached = usage_metadata["cachedContentTokenCount"] || 0
    completion = usage_metadata["candidatesTokenCount"] || max(0, total - prompt - reasoning)

    usage =
      %{
        input_tokens: prompt,
        output_tokens: completion,
        total_tokens: total
      }
      |> maybe_put(:reasoning_tokens, reasoning)
      |> maybe_put(:cache_read_tokens, cached)

    [{:usage, usage}]
  end

  defp decode_usage(_usage_metadata), do: []

  defp decode_finish_reason(candidate, part_chunks) do
    case candidate["finishReason"] do
      nil ->
        []

      finish_reason ->
        normalized =
          if tool_chunks?(part_chunks) and finish_reason == "STOP" do
            :tool_calls
          else
            normalize_finish_reason(finish_reason)
          end

        [{:meta, %{finish_reason: normalized, terminal?: true}}]
    end
  end

  defp normalize_finish_reason("STOP"), do: :stop
  defp normalize_finish_reason("MAX_TOKENS"), do: :length
  defp normalize_finish_reason("SAFETY"), do: :content_filter
  defp normalize_finish_reason("RECITATION"), do: :content_filter
  defp normalize_finish_reason("BLOCKLIST"), do: :content_filter
  defp normalize_finish_reason("PROHIBITED_CONTENT"), do: :content_filter
  defp normalize_finish_reason("SPII"), do: :content_filter
  defp normalize_finish_reason("IMAGE_SAFETY"), do: :content_filter
  defp normalize_finish_reason("MALFORMED_FUNCTION_CALL"), do: :error
  defp normalize_finish_reason(_), do: :error

  defp tool_chunks?(chunks) do
    Enum.any?(chunks, &match?({:tool_call_start, _}, &1))
  end

  defp maybe_put(map, _key, 0), do: map
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
