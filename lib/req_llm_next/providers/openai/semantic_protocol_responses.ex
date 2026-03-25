defmodule ReqLlmNext.SemanticProtocols.OpenAIResponses do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  @tool_usage_type_atoms %{
    "web_search" => :web_search,
    "web_search_preview" => :web_search_preview,
    "file_search" => :file_search,
    "mcp" => :mcp,
    "computer_use" => :computer_use,
    "computer_use_preview" => :computer_use,
    "code_interpreter" => :code_interpreter,
    "hosted_shell" => :hosted_shell,
    "apply_patch" => :apply_patch,
    "local_shell" => :local_shell,
    "tool_search" => :tool_search,
    "skills" => :skills,
    "image_generation" => :image_generation
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

  def decode_event(data, model) when is_map(data) do
    event_type = data["type"] || data["event"]

    case event_type do
      "response.output_text.delta" ->
        decode_text_delta(data)

      "response.reasoning.delta" ->
        decode_reasoning_delta(data)

      "response.output_item.added" ->
        decode_output_item_added(data)

      "response.function_call_arguments.delta" ->
        decode_function_call_args_delta(data)

      "response.function_call.delta" ->
        decode_function_call_delta(data)

      "response.usage" ->
        decode_usage_event(data, model)

      "response.completed" ->
        decode_completed_event(data, model)

      "response.incomplete" ->
        decode_incomplete_event(data)

      "response.output_text.done" ->
        []

      "response.output_item.done" ->
        decode_output_item_done(data)

      "response.function_call_arguments.done" ->
        []

      _ ->
        []
    end
  end

  def decode_event(_event, _model), do: []

  defp decode_text_delta(%{"delta" => text}) when is_binary(text) and text != "", do: [text]
  defp decode_text_delta(_), do: []

  defp decode_reasoning_delta(%{"delta" => text}) when is_binary(text) and text != "" do
    [{:thinking, text}]
  end

  defp decode_reasoning_delta(_), do: []

  defp decode_output_item_added(%{"item" => %{"type" => "function_call"} = item} = data) do
    index = data["output_index"] || 0
    call_id = item["call_id"] || item["id"]
    name = item["name"]

    if name && name != "" do
      [{:tool_call_start, %{index: index, id: call_id, name: name}}]
    else
      []
    end
  end

  defp decode_output_item_added(_), do: []

  defp decode_output_item_done(%{"item" => %{"type" => item_type} = item})
       when is_binary(item_type) do
    case provider_item(item, item_type) do
      nil -> []
      provider_item -> [{:provider_item, provider_item}]
    end
  end

  defp decode_output_item_done(_), do: []

  defp decode_function_call_args_delta(%{"delta" => fragment} = data)
       when is_binary(fragment) and fragment != "" do
    index = data["output_index"] || data["index"] || 0

    [{:tool_call_delta, %{index: index, function: %{"arguments" => fragment}}}]
  end

  defp decode_function_call_args_delta(_), do: []

  defp decode_function_call_delta(%{"delta" => delta} = data) when is_map(delta) do
    index = data["output_index"] || data["index"] || 0
    call_id = data["call_id"] || data["id"]

    chunks = []

    chunks =
      case delta["name"] do
        name when is_binary(name) and name != "" ->
          [{:tool_call_start, %{index: index, id: call_id, name: name}} | chunks]

        _ ->
          chunks
      end

    chunks =
      case delta["arguments"] do
        fragment when is_binary(fragment) and fragment != "" ->
          [{:tool_call_delta, %{index: index, function: %{"arguments" => fragment}}} | chunks]

        _ ->
          chunks
      end

    Enum.reverse(chunks)
  end

  defp decode_function_call_delta(_), do: []

  defp decode_usage_event(data, _model) do
    usage_data = data["usage"] || %{}
    tool_usage = extract_tool_calls_from_usage(usage_data)

    input_tokens = usage_data["input_tokens"] || 0
    output_tokens = usage_data["output_tokens"] || 0

    reasoning_tokens =
      get_in(usage_data, ["output_tokens_details", "reasoning_tokens"]) ||
        usage_data["reasoning_tokens"] ||
        0

    cached_tokens =
      get_in(usage_data, ["input_tokens_details", "cached_tokens"]) || 0

    usage = %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens
    }

    usage =
      if reasoning_tokens > 0,
        do: Map.put(usage, :reasoning_tokens, reasoning_tokens),
        else: usage

    usage =
      if cached_tokens > 0, do: Map.put(usage, :cache_read_tokens, cached_tokens), else: usage

    usage =
      if tool_usage != %{}, do: Map.put(usage, :tool_usage, tool_usage), else: usage

    [{:usage, usage}]
  end

  defp decode_completed_event(data, _model) do
    response = data["response"] || %{}
    response_id = response["id"]
    usage_data = response["usage"]
    provider_items = extract_provider_items(response)
    tool_usage = extract_tool_usage(response)

    meta = %{terminal?: true, finish_reason: :stop}
    meta = if response_id, do: Map.put(meta, :response_id, response_id), else: meta
    meta = if provider_items != [], do: Map.put(meta, :provider_items, provider_items), else: meta
    meta = if tool_usage != %{}, do: Map.put(meta, :tool_usage, tool_usage), else: meta

    if usage_data do
      input_tokens = usage_data["input_tokens"] || 0
      output_tokens = usage_data["output_tokens"] || 0

      reasoning_tokens =
        get_in(usage_data, ["output_tokens_details", "reasoning_tokens"]) ||
          usage_data["reasoning_tokens"] ||
          0

      usage = %{
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: usage_data["total_tokens"] || input_tokens + output_tokens
      }

      usage =
        if reasoning_tokens > 0,
          do: Map.put(usage, :reasoning_tokens, reasoning_tokens),
          else: usage

      usage =
        if tool_usage != %{},
          do: Map.put(usage, :tool_usage, tool_usage),
          else: usage

      [{:usage, usage}, {:meta, meta}]
    else
      [{:meta, meta}]
    end
  end

  defp decode_incomplete_event(data) do
    reason = data["reason"] || "incomplete"
    finish_reason = normalize_finish_reason(reason)

    [{:meta, %{terminal?: true, finish_reason: finish_reason}}]
  end

  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("max_tokens"), do: :length
  defp normalize_finish_reason("max_output_tokens"), do: :length
  defp normalize_finish_reason("tool_calls"), do: :tool_calls
  defp normalize_finish_reason("content_filter"), do: :content_filter
  defp normalize_finish_reason(_), do: :error

  defp extract_provider_items(%{"output" => output}) when is_list(output) do
    Enum.flat_map(output, fn
      %{"type" => item_type} = item when is_binary(item_type) ->
        case provider_item(item, item_type) do
          nil -> []
          provider_item -> [provider_item]
        end

      _other ->
        []
    end)
  end

  defp extract_provider_items(_response), do: []

  defp provider_item(item, item_type) do
    if String.ends_with?(item_type, "_call") and item_type != "function_call" do
      %{
        type: item_type,
        id: item["id"] || item["call_id"],
        status: item["status"],
        name: item["name"],
        action: item["action"],
        arguments: item["arguments"],
        result: item["result"],
        output: item["output"]
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end
  end

  defp extract_tool_usage(response) do
    output_counts = count_tool_calls_from_output(response)

    usage_counts =
      response
      |> Map.get("usage", %{})
      |> extract_tool_calls_from_usage()

    [output_counts, usage_counts]
    |> Enum.reject(&(&1 == %{}))
    |> Enum.reduce(%{}, fn counts, acc ->
      Map.merge(acc, counts, fn _key, left, right -> max(left, right) end)
    end)
  end

  defp count_tool_calls_from_output(%{"output" => output}) when is_list(output) do
    Enum.reduce(output, %{}, fn
      %{"type" => item_type}, acc when is_binary(item_type) ->
        case tool_usage_key_from_call_type(item_type) do
          nil -> acc
          tool -> Map.update(acc, tool, 1, &(&1 + 1))
        end

      _other, acc ->
        acc
    end)
  end

  defp count_tool_calls_from_output(_response), do: %{}

  defp extract_tool_calls_from_usage(usage) when is_map(usage) do
    details =
      get_in(usage, ["output_tokens_details"]) ||
        get_in(usage, [:output_tokens_details]) ||
        %{}

    extract_tool_counts_from_map(details, "_calls")
  end

  defp extract_tool_calls_from_usage(_usage), do: %{}

  defp extract_tool_counts_from_map(map, suffix) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      key = if is_atom(key), do: Atom.to_string(key), else: key

      cond do
        not is_binary(key) ->
          acc

        not String.ends_with?(key, suffix) ->
          acc

        not is_integer(value) ->
          acc

        true ->
          base_type = String.replace_suffix(key, suffix, "")

          case Map.get(@tool_usage_type_atoms, base_type) do
            nil -> acc
            tool -> Map.put(acc, tool, value)
          end
      end
    end)
  end

  defp extract_tool_counts_from_map(_map, _suffix), do: %{}

  defp tool_usage_key_from_call_type(call_type) when is_binary(call_type) do
    if String.ends_with?(call_type, "_call") do
      base_type = String.replace_suffix(call_type, "_call", "")
      Map.get(@tool_usage_type_atoms, base_type)
    end
  end
end
