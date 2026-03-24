defmodule ReqLlmNext.SurfacePreparation do
  @moduledoc """
  Surface-owned parameter preparation and validation before execution.
  """

  alias ReqLlmNext.{
    Constraints,
    Error,
    ExecutionMode,
    ExecutionSurface,
    ModelProfile,
    Tool
  }

  alias ReqLlmNext.Anthropic.Tools, as: AnthropicTools
  alias ReqLlmNext.SurfacePreparation.{AnthropicMessages, OpenAIResponses}

  @meta_opts [:_stream?, :_model_spec]

  @spec prepare(
          LLMDB.Model.t(),
          ModelProfile.t(),
          ExecutionMode.t(),
          ExecutionSurface.t(),
          term(),
          keyword()
        ) :: {:ok, map()} | {:error, term()}
  def prepare(
        %LLMDB.Model{} = model,
        %ModelProfile{} = profile,
        %ExecutionMode{} = mode,
        %ExecutionSurface{} = surface,
        prompt,
        opts
      ) do
    normalized_opts =
      opts
      |> Keyword.drop(@meta_opts)
      |> then(&Constraints.apply(model, &1))

    with {:ok, prepared_opts} <- prepare_surface(profile, mode, surface, prompt, normalized_opts),
         :ok <- validate_tool_inputs(surface, prepared_opts),
         :ok <- validate_mcp_servers(surface, prepared_opts),
         :ok <- validate_surface_parameters(surface, prepared_opts) do
      {:ok, Enum.into(prepared_opts, %{})}
    end
  end

  defp prepare_surface(
         _profile,
         _mode,
         %{semantic_protocol: :anthropic_messages} = surface,
         prompt,
         opts
       ) do
    AnthropicMessages.prepare(surface, prompt, opts)
  end

  defp prepare_surface(
         _profile,
         _mode,
         %{semantic_protocol: :openai_responses} = surface,
         prompt,
         opts
       ) do
    OpenAIResponses.prepare(surface, prompt, opts)
  end

  defp prepare_surface(_profile, _mode, _surface, _prompt, opts), do: {:ok, opts}

  defp validate_tool_inputs(surface, opts) do
    tools = Keyword.get(opts, :tools, [])

    case Enum.find(tools, &invalid_tool_input?(surface, &1)) do
      nil ->
        :ok

      %Tool{} ->
        :ok

      invalid ->
        {:error,
         Error.Invalid.Parameter.exception(parameter: invalid_tool_message(surface, invalid))}
    end
  end

  defp invalid_tool_input?(_surface, %Tool{}), do: false

  defp invalid_tool_input?(%ExecutionSurface{semantic_protocol: :anthropic_messages}, tool)
       when is_map(tool) do
    not AnthropicTools.provider_native_tool?(tool)
  end

  defp invalid_tool_input?(%ExecutionSurface{}, tool) when is_map(tool), do: true
  defp invalid_tool_input?(_surface, _tool), do: true

  defp invalid_tool_message(%ExecutionSurface{semantic_protocol: :anthropic_messages}, _tool) do
    "tools must be ReqLlmNext.Tool values or ReqLlmNext.Anthropic helper maps on Anthropic surfaces"
  end

  defp invalid_tool_message(%ExecutionSurface{}, _tool) do
    "tools must be ReqLlmNext.Tool values on non-Anthropic surfaces"
  end

  defp validate_mcp_servers(surface, opts) do
    servers = Keyword.get(opts, :mcp_servers, [])

    case Enum.find(servers, &invalid_mcp_server?(surface, &1)) do
      nil ->
        :ok

      invalid ->
        {:error,
         Error.Invalid.Parameter.exception(parameter: invalid_mcp_message(surface, invalid))}
    end
  end

  defp invalid_mcp_server?(%ExecutionSurface{semantic_protocol: :anthropic_messages}, server) do
    not AnthropicTools.provider_native_mcp_server?(server)
  end

  defp invalid_mcp_server?(%ExecutionSurface{}, _server), do: true

  defp invalid_mcp_message(%ExecutionSurface{semantic_protocol: :anthropic_messages}, _server) do
    "mcp_servers must come from ReqLlmNext.Anthropic.mcp_server/2 on Anthropic surfaces"
  end

  defp invalid_mcp_message(%ExecutionSurface{}, _server) do
    "mcp_servers are only supported on Anthropic surfaces"
  end

  defp validate_surface_parameters(_surface, _opts), do: :ok
end
