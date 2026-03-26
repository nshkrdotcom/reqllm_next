defmodule ReqLlmNext.SemanticProtocols.CohereChat do
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

  def decode_event(
        %{
          "type" => "content-delta",
          "delta" => %{"message" => %{"content" => %{"text" => text}}}
        },
        _model
      )
      when is_binary(text) do
    [text]
  end

  def decode_event(%{"type" => type, "delta" => delta}, _model)
      when type in ["citation-start", "citation-end", "content-start", "content-end"] and
             is_map(delta) do
    [{:provider_item, %{type: type, metadata: delta}}]
  end

  def decode_event(%{"type" => "message-end", "delta" => delta}, _model) when is_map(delta) do
    usage_chunks = decode_usage(delta["usage"])
    finish_reason = normalize_finish_reason(delta["finish_reason"])

    usage_chunks ++ [{:meta, %{finish_reason: finish_reason, terminal?: true}}]
  end

  def decode_event(%{"type" => "message-start", "id" => id, "delta" => delta}, _model)
      when is_binary(id) and is_map(delta) do
    [{:provider_item, %{type: "message_start", id: id, metadata: delta}}]
  end

  def decode_event(%{"type" => type} = event, _model) when is_binary(type) do
    [{:provider_item, Map.put(event, :type, type)}]
  end

  def decode_event(_event, _model), do: []

  defp decode_usage(%{"tokens" => tokens}) when is_map(tokens) do
    input_tokens = tokens["input_tokens"] || 0
    output_tokens = tokens["output_tokens"] || 0

    [
      {:usage,
       %{
         input_tokens: input_tokens,
         output_tokens: output_tokens,
         total_tokens: input_tokens + output_tokens
       }}
    ]
  end

  defp decode_usage(_usage), do: []

  defp normalize_finish_reason("COMPLETE"), do: :stop
  defp normalize_finish_reason("MAX_TOKENS"), do: :length
  defp normalize_finish_reason("ERROR"), do: :error
  defp normalize_finish_reason("SAFETY"), do: :content_filter
  defp normalize_finish_reason(_reason), do: :stop
end
