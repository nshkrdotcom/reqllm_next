defmodule ReqLlmNext.SurfacePreparation.AnthropicMessages do
  @moduledoc """
  Anthropic Messages surface-owned request preparation.
  """

  alias ReqLlmNext.Anthropic.Tools, as: AnthropicTools
  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.Tool

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    opts =
      opts
      |> maybe_enable_files_api(prompt)
      |> normalize_context_management()

    {:ok, opts}
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    case validate_tools(opts) do
      :ok ->
        case validate_mcp_servers(opts) do
          :ok -> validate_context_management(opts)
          {:error, _} = error -> error
        end

      {:error, _} = error -> error
    end
  end

  defp maybe_enable_files_api(opts, %Context{messages: messages}) do
    if Keyword.has_key?(opts, :anthropic_files_api) do
      opts
    else
      Keyword.put(opts, :anthropic_files_api, context_uses_files_api?(messages))
    end
  end

  defp maybe_enable_files_api(opts, _prompt), do: opts

  defp normalize_context_management(opts) do
    case Keyword.get(opts, :context_management) do
      context_management when is_map(context_management) ->
        case build_context_management(context_management) do
          nil -> Keyword.delete(opts, :context_management)
          normalized -> Keyword.put(opts, :context_management, normalized)
        end

      _ ->
        opts
    end
  end

  defp context_uses_files_api?(messages) when is_list(messages) do
    Enum.any?(messages, fn message ->
      Enum.any?(message.content || [], &files_api_part?/1)
    end)
  end

  defp files_api_part?(%ContentPart{type: :document}), do: true

  defp files_api_part?(%ContentPart{type: :file, metadata: metadata}) do
    type = Map.get(metadata || %{}, :anthropic_type) || Map.get(metadata || %{}, "anthropic_type")
    source = Map.get(metadata || %{}, :source_type) || Map.get(metadata || %{}, "source_type")
    type in [:container_upload, "container_upload"] or source in [:file_id, "file_id"]
  end

  defp files_api_part?(_part), do: false

  defp validate_tools(opts) do
    tools = Keyword.get(opts, :tools, [])

    case Enum.find(tools, &invalid_tool_input?/1) do
      nil ->
        :ok

      invalid ->
        {:error, Error.Invalid.Parameter.exception(parameter: invalid_tool_message(invalid))}
    end
  end

  defp invalid_tool_input?(%Tool{}), do: false

  defp invalid_tool_input?(tool) when is_map(tool),
    do: not AnthropicTools.provider_native_tool?(tool)

  defp invalid_tool_input?(_tool), do: true

  defp invalid_tool_message(_tool) do
    "tools must be ReqLlmNext.Tool values or ReqLlmNext.Anthropic helper maps on Anthropic surfaces"
  end

  defp validate_mcp_servers(opts) do
    servers = Keyword.get(opts, :mcp_servers, [])

    case Enum.find(servers, &invalid_mcp_server?/1) do
      nil ->
        :ok

      invalid ->
        {:error, Error.Invalid.Parameter.exception(parameter: invalid_mcp_message(invalid))}
    end
  end

  defp invalid_mcp_server?(server), do: not AnthropicTools.provider_native_mcp_server?(server)

  defp invalid_mcp_message(_server) do
    "mcp_servers must come from ReqLlmNext.Anthropic.mcp_server/2 on Anthropic surfaces"
  end

  defp validate_context_management(opts) do
    case Keyword.get(opts, :context_management) do
      nil ->
        :ok

      %{edits: edits} when is_list(edits) ->
        with :ok <- validate_clear_thinking_dependency(edits, opts),
             :ok <- validate_edit_order(edits),
             nil <- Enum.find(edits, &invalid_context_edit?/1) do
          :ok
        else
          {:error, _} = error -> error
          invalid -> {:error, Error.Invalid.Parameter.exception(parameter: invalid_context_message(invalid))}
        end

      _ ->
        :ok
    end
  end

  defp validate_clear_thinking_dependency(edits, opts) do
    if Enum.any?(edits, &edit_type?(&1, "clear_thinking_20251015")) and not thinking_requested?(opts) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter:
           "context_management.edits clear_thinking_20251015 requires Anthropic thinking to be enabled via :thinking or :reasoning_effort"
       )}
    else
      :ok
    end
  end

  defp build_context_management(context_management) do
    edits =
      context_management
      |> existing_edits()
      |> maybe_append_compaction(context_management)

    if edits == [] do
      nil
    else
      %{edits: edits}
    end
  end

  defp existing_edits(%{edits: edits}) when is_list(edits), do: edits
  defp existing_edits(%{"edits" => edits}) when is_list(edits), do: edits
  defp existing_edits(_context_management), do: []

  defp maybe_append_compaction(edits, %{compact: true}),
    do: edits ++ [%{type: "compact_20260112"}]

  defp maybe_append_compaction(edits, %{compact: compact})
       when is_map(compact) and map_size(compact) > 0 do
    edits ++ [Map.put(compact, :type, "compact_20260112")]
  end

  defp maybe_append_compaction(edits, %{"compact" => true}),
    do: edits ++ [%{type: "compact_20260112"}]

  defp maybe_append_compaction(edits, %{"compact" => compact})
       when is_map(compact) and map_size(compact) > 0 do
    edits ++ [Map.put(compact, "type", "compact_20260112")]
  end

  defp maybe_append_compaction(edits, _context_management), do: edits

  defp validate_edit_order(edits) do
    clear_thinking_index = Enum.find_index(edits, &edit_type?(&1, "clear_thinking_20251015"))
    clear_tool_uses_index = Enum.find_index(edits, &edit_type?(&1, "clear_tool_uses_20250919"))

    if is_integer(clear_thinking_index) and is_integer(clear_tool_uses_index) and
         clear_thinking_index > clear_tool_uses_index do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "context_management.edits must list clear_thinking_20251015 before clear_tool_uses_20250919"
       )}
    else
      :ok
    end
  end

  defp invalid_context_edit?(edit) do
    cond do
      edit_type?(edit, "clear_tool_uses_20250919") ->
        false

      edit_type?(edit, "clear_thinking_20251015") ->
        false

      edit_type?(edit, "compact_20260112") ->
        false

      true ->
        true
    end
  end

  defp invalid_context_message(_invalid) do
    "context_management.edits must use Anthropic edit types clear_tool_uses_20250919, clear_thinking_20251015, or compact_20260112"
  end

  defp thinking_requested?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp edit_type?(%{type: type}, expected) when is_binary(type), do: type == expected
  defp edit_type?(%{"type" => type}, expected) when is_binary(type), do: type == expected
  defp edit_type?(_edit, _expected), do: false
end
