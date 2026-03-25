defmodule ReqLlmNext.SemanticProtocols.ZenmuxChat do
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
    |> maybe_append_thinking(reasoning_text(delta))
    |> maybe_append_text(delta["content"])
    |> maybe_append_tool_calls(delta["tool_calls"])
  end

  defp decode_message(message) when is_map(message) do
    reasoning = reasoning_text(message)
    explicit_tool_calls = message["tool_calls"]
    parsed_tool_calls = parse_deepseek_tool_calls(reasoning)
    content = message["content"]
    cleaned_reasoning = clean_reasoning_text(reasoning)

    []
    |> maybe_append_thinking(reasoning)
    |> maybe_append_text(content)
    |> maybe_append_text(if(blank_text?(content), do: cleaned_reasoning, else: nil))
    |> maybe_append_tool_calls(explicit_tool_calls || parsed_tool_calls)
    |> maybe_append_reasoning_details(message["reasoning_details"])
  end

  defp maybe_finish_reason(%{"choices" => [%{"finish_reason" => reason} | _]})
       when reason in ["stop", "length", "content_filter", "tool_calls"] do
    [{:meta, %{finish_reason: String.to_atom(reason), terminal?: true}}]
  end

  defp maybe_finish_reason(_payload), do: []

  defp maybe_extract_usage(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  defp maybe_extract_usage(_payload, _model), do: []

  defp reasoning_text(message) when is_map(message) do
    cond do
      is_binary(message["reasoning_content"]) and message["reasoning_content"] != "" ->
        message["reasoning_content"]

      is_binary(message["reasoning"]) and message["reasoning"] != "" ->
        message["reasoning"]

      true ->
        nil
    end
  end

  defp maybe_append_text(chunks, text) when is_binary(text) and text != "", do: chunks ++ [text]
  defp maybe_append_text(chunks, _text), do: chunks

  defp maybe_append_thinking(chunks, text) when is_binary(text) and text != "" do
    chunks ++ [{:thinking, text}]
  end

  defp maybe_append_thinking(chunks, _text), do: chunks

  defp maybe_append_tool_calls(chunks, tool_calls)
       when is_list(tool_calls) and tool_calls != [] do
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

  defp maybe_append_reasoning_details(chunks, details) when is_list(details) do
    chunks ++ [{:provider_item, %{type: "reasoning_details", details: details}}]
  end

  defp maybe_append_reasoning_details(chunks, _details), do: chunks

  defp parse_deepseek_tool_calls(reasoning) when is_binary(reasoning) do
    ~r/<｜tool▁call▁begin｜>([^<]+)<｜tool▁sep｜>(\{.*?\})<｜tool▁call▁end｜>/s
    |> Regex.scan(reasoning, capture: :all_but_first)
    |> Enum.with_index()
    |> Enum.map(fn {[name, args_json], index} ->
      %{
        "id" => "call_#{index}",
        "type" => "function",
        "function" => %{"name" => name, "arguments" => args_json}
      }
    end)
  end

  defp parse_deepseek_tool_calls(_reasoning), do: []

  defp clean_reasoning_text(reasoning) when is_binary(reasoning) do
    reasoning
    |> String.replace(~r/<｜tool▁call▁begin｜>.*?<｜tool▁call▁end｜>/s, "")
    |> String.trim()
  end

  defp clean_reasoning_text(_reasoning), do: nil

  defp blank_text?(nil), do: true
  defp blank_text?(""), do: true
  defp blank_text?(parts) when is_list(parts), do: parts == []
  defp blank_text?(_value), do: false
end
