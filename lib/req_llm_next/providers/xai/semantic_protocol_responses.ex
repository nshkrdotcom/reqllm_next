defmodule ReqLlmNext.SemanticProtocols.XAIResponses do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.SemanticProtocols.OpenAIResponses

  @tool_usage_type_atoms %{
    "x_search" => :x_search,
    "code_execution" => :code_execution,
    "collections_search" => :collections_search,
    "file_search" => :file_search
  }

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(data, model) when is_map(data) do
    case data["type"] || data["event"] do
      "response.usage" ->
        augment_usage(OpenAIResponses.decode_event(data, model), data["usage"] || %{})

      "response.completed" ->
        response = data["response"] || %{}
        augment_usage(OpenAIResponses.decode_event(data, model), response["usage"] || %{})

      _ ->
        OpenAIResponses.decode_event(data, model)
    end
  end

  def decode_event(event, model), do: OpenAIResponses.decode_event(event, model)

  defp augment_usage(chunks, usage_data) when is_list(chunks) and is_map(usage_data) do
    extra = extract_tool_calls_from_usage(usage_data)

    if extra == %{} do
      chunks
    else
      Enum.map(chunks, fn
        {:usage, usage} when is_map(usage) ->
          {:usage, Map.update(usage, :tool_usage, extra, &Map.merge(&1, extra))}

        other ->
          other
      end)
    end
  end

  defp extract_tool_calls_from_usage(usage) when is_map(usage) do
    details =
      get_in(usage, ["output_tokens_details"]) ||
        get_in(usage, [:output_tokens_details]) ||
        %{}

    Enum.reduce(details, %{}, fn {key, value}, acc ->
      key = if is_atom(key), do: Atom.to_string(key), else: key

      cond do
        not is_binary(key) ->
          acc

        not String.ends_with?(key, "_calls") ->
          acc

        not is_integer(value) ->
          acc

        true ->
          base_type = String.replace_suffix(key, "_calls", "")

          case Map.get(@tool_usage_type_atoms, base_type) do
            nil -> acc
            tool -> Map.put(acc, tool, value)
          end
      end
    end)
  end
end
