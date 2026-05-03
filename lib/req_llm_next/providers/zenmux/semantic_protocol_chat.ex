defmodule ReqLlmNext.SemanticProtocols.ZenmuxChat do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Response.Usage

  @finish_reasons %{
    "stop" => :stop,
    "length" => :length,
    "content_filter" => :content_filter,
    "tool_calls" => :tool_calls
  }
  @tool_begin "<｜tool▁call▁begin｜>"
  @tool_sep "<｜tool▁sep｜>"
  @tool_end "<｜tool▁call▁end｜>"

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
    parse_tool_calls(reasoning, 0, [])
  end

  defp parse_deepseek_tool_calls(_reasoning), do: []

  defp clean_reasoning_text(reasoning) when is_binary(reasoning) do
    reasoning |> remove_tool_call_segments([]) |> String.trim()
  end

  defp clean_reasoning_text(_reasoning), do: nil

  defp parse_tool_calls(text, index, acc) do
    with {:ok, after_begin} <- after_marker(text, @tool_begin),
         {:ok, name, after_sep} <- take_until_marker(after_begin, @tool_sep),
         {:ok, args_json, rest} <- take_until_marker(after_sep, @tool_end) do
      tool_call = %{
        "id" => "call_#{index}",
        "type" => "function",
        "function" => %{"name" => name, "arguments" => args_json}
      }

      parse_tool_calls(rest, index + 1, [tool_call | acc])
    else
      _ -> Enum.reverse(acc)
    end
  end

  defp remove_tool_call_segments(text, acc) do
    case split_around_marker(text, @tool_begin) do
      {:ok, before_begin, after_begin} ->
        case after_marker(after_begin, @tool_end) do
          {:ok, rest} -> remove_tool_call_segments(rest, [before_begin | acc])
          :error -> IO.iodata_to_binary(Enum.reverse([text | acc]))
        end

      :error ->
        IO.iodata_to_binary(Enum.reverse([text | acc]))
    end
  end

  defp after_marker(text, marker) do
    case split_around_marker(text, marker) do
      {:ok, _before_marker, after_marker_text} -> {:ok, after_marker_text}
      :error -> :error
    end
  end

  defp take_until_marker(text, marker) do
    case split_around_marker(text, marker) do
      {:ok, before_marker, after_marker_text} -> {:ok, before_marker, after_marker_text}
      :error -> :error
    end
  end

  defp split_around_marker(text, marker) do
    case :binary.match(text, marker) do
      {index, size} ->
        before_marker = binary_part(text, 0, index)
        after_marker_text = binary_part(text, index + size, byte_size(text) - index - size)
        {:ok, before_marker, after_marker_text}

      :nomatch ->
        :error
    end
  end

  defp blank_text?(nil), do: true
  defp blank_text?(""), do: true
  defp blank_text?(parts) when is_list(parts), do: parts == []
  defp blank_text?(_value), do: false
end
