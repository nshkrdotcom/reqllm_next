defmodule ReqLlmNext.SemanticProtocols.OpenAIChat do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Response.Usage

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
    error_type = error["type"] || "api_error"
    [{:error, %{message: message, type: error_type, code: error["code"]}}]
  end

  def decode_event(%{"choices" => [%{"delta" => delta} | _]} = payload, model) do
    decode_delta(delta) ++ maybe_extract_usage(payload, model)
  end

  def decode_event(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  def decode_event(_event, _model), do: []

  defp maybe_extract_usage(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  defp maybe_extract_usage(_payload, _model), do: []

  defp decode_delta(%{"content" => content}) when is_binary(content), do: [content]

  defp decode_delta(%{"tool_calls" => tool_calls}) when is_list(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      {:tool_call_delta,
       %{
         index: tc["index"],
         id: tc["id"],
         type: tc["type"],
         function: tc["function"]
       }}
    end)
  end

  defp decode_delta(_), do: []
end
