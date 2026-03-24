defmodule ReqLlmNext.SurfacePreparation.OpenAIResponses do
  @moduledoc """
  OpenAI Responses surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.OpenAI.Tools, as: OpenAITools
  alias ReqLlmNext.Tool

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{wire_format: :openai_responses_ws_json}, _prompt, opts) do
    if Keyword.has_key?(opts, :temperature) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "temperature is not supported for OpenAI Responses WebSocket mode"
       )}
    else
      {:ok, opts}
    end
  end

  def prepare(%ExecutionSurface{}, _prompt, opts), do: {:ok, opts}

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_tools(opts) do
      opts
      |> drop_provider_native_tools()
      |> ReqLlmNext.SurfacePreparation.validate_canonical_inputs()
    end
  end

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
    do: not OpenAITools.provider_native_tool?(tool)

  defp invalid_tool_input?(_tool), do: true

  defp invalid_tool_message(_tool) do
    "tools must be ReqLlmNext.Tool values or ReqLlmNext.OpenAI helper maps on OpenAI Responses surfaces"
  end

  defp drop_provider_native_tools(opts) do
    tools =
      opts
      |> Keyword.get(:tools, [])
      |> Enum.reject(&OpenAITools.provider_native_tool?/1)

    Keyword.put(opts, :tools, tools)
  end
end
