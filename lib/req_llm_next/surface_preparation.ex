defmodule ReqLlmNext.SurfacePreparation do
  @moduledoc """
  Surface-owned parameter preparation and validation before execution.
  """

  alias ReqLlmNext.{
    Constraints,
    Error,
    ExecutionMode,
    ExecutionSurface,
    Extensions,
    ModelProfile,
    Tool
  }

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
      |> Keyword.put(:_request_input, prompt)

    with {:ok, preparation_module, prepared_opts} <-
           prepare_surface(profile, mode, surface, prompt, normalized_opts),
         :ok <- validate_surface_inputs(preparation_module, surface, prepared_opts),
         :ok <- validate_surface_parameters(surface, prepared_opts) do
      {:ok, prepared_opts |> Keyword.delete(:_request_input) |> Enum.into(%{})}
    end
  end

  defp prepare_surface(profile, mode, surface, prompt, opts) do
    case surface_preparation_module(profile, mode, surface) do
      nil ->
        {:ok, nil, opts}

      module ->
        with {:ok, prepared_opts} <- module.prepare(surface, prompt, opts) do
          {:ok, module, prepared_opts}
        end
    end
  end

  @spec validate_canonical_inputs(keyword()) :: :ok | {:error, term()}
  def validate_canonical_inputs(opts) when is_list(opts) do
    case validate_canonical_tool_inputs(opts) do
      :ok -> validate_no_mcp_servers(opts)
      {:error, _} = error -> error
    end
  end

  defp validate_surface_inputs(nil, _surface, opts) do
    validate_canonical_inputs(opts)
  end

  defp validate_surface_inputs(module, surface, opts) do
    if function_exported?(module, :validate, 2) do
      module.validate(surface, opts)
    else
      validate_canonical_inputs(opts)
    end
  end

  defp validate_canonical_tool_inputs(opts) do
    tools = Keyword.get(opts, :tools, [])

    case Enum.find(tools, &invalid_canonical_tool_input?/1) do
      nil ->
        :ok

      %Tool{} ->
        :ok

      _invalid ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "tools must be ReqLlmNext.Tool values on canonical cross-provider surfaces"
         )}
    end
  end

  defp invalid_canonical_tool_input?(%Tool{}), do: false
  defp invalid_canonical_tool_input?(_tool), do: true

  defp validate_no_mcp_servers(opts) do
    servers = Keyword.get(opts, :mcp_servers, [])

    case Enum.find(servers, fn _server -> true end) do
      nil ->
        :ok

      _invalid ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "mcp_servers are only supported on provider-native surfaces"
         )}
    end
  end

  defp surface_preparation_module(profile, mode, surface) do
    case Extensions.resolve_compiled(extension_context(profile, mode, surface)) do
      {:ok, %{seams: %{surface_preparation_modules: modules}}} ->
        Map.get(modules, surface.semantic_protocol)

      {:error, :no_matching_family} ->
        nil
    end
  end

  defp validate_surface_parameters(_surface, _opts), do: :ok

  defp extension_context(profile, mode, surface) do
    %{
      provider: profile.provider,
      family: profile.family,
      model_id: profile.model_id,
      operation: mode.operation,
      transport: surface.transport,
      semantic_protocol: surface.semantic_protocol,
      stream?: mode.stream?,
      tools?: mode.tools?,
      structured?: mode.structured_output?,
      features: profile.features
    }
  end
end
