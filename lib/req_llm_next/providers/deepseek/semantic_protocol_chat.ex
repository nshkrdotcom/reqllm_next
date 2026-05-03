defmodule ReqLlmNext.SemanticProtocols.DeepSeekChat do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Response.Usage

  @finish_reasons %{
    "stop" => :stop,
    "length" => :length,
    "content_filter" => :content_filter,
    "tool_calls" => :tool_calls
  }

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
    decode_delta(delta) ++ maybe_finish_reason(payload) ++ maybe_extract_usage(payload, model)
  end

  def decode_event(%{"choices" => [%{"message" => message} | _]} = payload, model) do
    decode_message(message) ++ maybe_finish_reason(payload) ++ maybe_extract_usage(payload, model)
  end

  def decode_event(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  def decode_event(_event, _model), do: []

  defp decode_delta(delta) when is_map(delta) do
    []
    |> maybe_append_thinking(delta["reasoning_content"])
    |> maybe_append_text(delta["content"])
    |> maybe_append_tool_calls(delta["tool_calls"])
  end

  defp decode_message(message) when is_map(message) do
    []
    |> maybe_append_thinking(message["reasoning_content"])
    |> maybe_append_text(message["content"])
    |> maybe_append_tool_calls(message["tool_calls"])
  end

  defp maybe_finish_reason(%{"choices" => [%{"finish_reason" => reason} | _]}) do
    case Map.fetch(@finish_reasons, reason) do
      {:ok, finish_reason} -> [{:meta, %{finish_reason: finish_reason, terminal?: true}}]
      :error -> []
    end
  end

  defp maybe_finish_reason(_payload), do: []

  defp maybe_extract_usage(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  defp maybe_extract_usage(_payload, _model), do: []

  defp maybe_append_text(chunks, text) when is_binary(text) and text != "", do: chunks ++ [text]
  defp maybe_append_text(chunks, _text), do: chunks

  defp maybe_append_thinking(chunks, text) when is_binary(text) and text != "" do
    chunks ++ [{:thinking, text}]
  end

  defp maybe_append_thinking(chunks, _text), do: chunks

  defp maybe_append_tool_calls(chunks, tool_calls) when is_list(tool_calls) do
    chunks ++
      Enum.map(tool_calls, fn tc ->
        {:tool_call_delta,
         %{
           index: tc["index"] || 0,
           id: tc["id"],
           type: tc["type"],
           function: tc["function"]
         }}
      end)
  end

  defp maybe_append_tool_calls(chunks, _tool_calls), do: chunks
end
