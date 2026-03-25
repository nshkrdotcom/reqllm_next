defmodule ReqLlmNext.SurfacePreparation.XAIResponses do
  @moduledoc """
  xAI Responses surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.Tool
  alias ReqLlmNext.XAI.Tools, as: XAITools

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, _prompt, opts) do
    xai_tools =
      opts
      |> extract_xai_tools()
      |> Enum.reject(&is_nil/1)

    normalized_opts =
      opts
      |> drop_xai_tool_opts()
      |> Keyword.update(:tools, xai_tools, &(&1 ++ xai_tools))

    {:ok, normalized_opts}
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_tools(opts) do
      opts
      |> drop_provider_native_tools()
      |> ReqLlmNext.SurfacePreparation.validate_canonical_inputs()
    end
  end

  defp extract_xai_tools(opts) do
    provider_options =
      case Keyword.get(opts, :provider_options, []) do
        map when is_map(map) -> Map.to_list(map)
        list when is_list(list) -> list
        _ -> []
      end

    Keyword.get(opts, :xai_tools, []) ++ Keyword.get(provider_options, :xai_tools, [])
  end

  defp drop_xai_tool_opts(opts) do
    provider_options =
      case Keyword.get(opts, :provider_options, []) do
        map when is_map(map) -> Map.to_list(map)
        list when is_list(list) -> list
        _ -> []
      end
      |> Keyword.delete(:xai_tools)

    opts
    |> Keyword.delete(:xai_tools)
    |> Keyword.put(:provider_options, provider_options)
  end

  defp validate_tools(opts) do
    tools = Keyword.get(opts, :tools, []) ++ extract_xai_tools(opts)

    case Enum.find(tools, &invalid_tool_input?/1) do
      nil ->
        :ok

      invalid ->
        {:error, Error.Invalid.Parameter.exception(parameter: invalid_tool_message(invalid))}
    end
  end

  defp invalid_tool_input?(%Tool{}), do: false
  defp invalid_tool_input?(tool) when is_map(tool), do: not XAITools.provider_native_tool?(tool)
  defp invalid_tool_input?(_tool), do: true

  defp invalid_tool_message(_tool) do
    "tools must be ReqLlmNext.Tool values or ReqLlmNext.XAI.Tools helper maps on xAI Responses surfaces"
  end

  defp drop_provider_native_tools(opts) do
    tools =
      opts
      |> Keyword.get(:tools, [])
      |> Enum.reject(&XAITools.provider_native_tool?/1)

    Keyword.put(opts, :tools, tools)
  end
end
