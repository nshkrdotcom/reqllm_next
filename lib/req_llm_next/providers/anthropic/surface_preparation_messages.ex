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
    {:ok, maybe_enable_files_api(prompt, opts)}
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    case validate_tools(opts) do
      :ok -> validate_mcp_servers(opts)
      {:error, _} = error -> error
    end
  end

  defp maybe_enable_files_api(%Context{messages: messages}, opts) do
    if Keyword.has_key?(opts, :anthropic_files_api) do
      opts
    else
      Keyword.put(opts, :anthropic_files_api, context_uses_files_api?(messages))
    end
  end

  defp maybe_enable_files_api(_prompt, opts), do: opts

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
end
