defmodule ReqLlmNext.OperationPlanner do
  @moduledoc """
  Builds deterministic execution plans from model facts, request mode, and policy.
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    ExecutionMode,
    ExecutionPlan,
    Extensions,
    ModelProfile,
    PolicyRules,
    SurfacePreparation,
    Validation
  }

  @type operation :: :text | :object | :embed | :image | :transcription | :speech

  @spec plan(LLMDB.Model.t(), operation(), term(), keyword()) ::
          {:ok, ExecutionPlan.t()} | {:error, term()}
  def plan(%LLMDB.Model{} = model, operation, prompt, opts \\ []) do
    with {:ok, profile} <- ModelProfile.from_model(model, spec: Keyword.get(opts, :_model_spec)),
         {:ok, mode} <- ExecutionMode.from_request(operation, prompt, opts),
         :ok <- Validation.validate!(profile, mode),
         {:ok, policy} <- PolicyRules.resolve(profile, mode, opts),
         {:ok, parameter_values} <-
           SurfacePreparation.prepare(model, profile, mode, policy.surface, prompt, opts) do
      {:ok,
       ExecutionPlan.new!(%{
         model: profile,
         mode: mode,
         surface: policy.surface,
         provider: profile.provider,
         session_runtime:
           session_runtime_for(profile, mode, policy.surface, policy.session_strategy),
         semantic_protocol: policy.surface.semantic_protocol,
         wire_format: policy.surface.wire_format,
         transport: policy.surface.transport,
         parameter_values: parameter_values,
         timeout_class: policy.timeout_class,
         timeout_ms: policy.timeout_ms,
         session_strategy: policy.session_strategy,
         fallback_surfaces: policy.fallback_surfaces,
         plan_adapters: plan_adapters_for(model, profile, mode, policy.surface)
       })}
    end
  end

  defp plan_adapters_for(model, profile, mode, surface) do
    case Extensions.resolve_compiled(extension_context(profile, mode, surface)) do
      {:ok, %{seams: %{adapter_modules: adapter_modules}}} ->
        AdapterPipeline.adapters_for(model, adapter_modules)

      {:error, :no_matching_family} ->
        []
    end
  end

  defp session_runtime_for(profile, mode, surface, %{mode: strategy_mode})
       when strategy_mode not in [:none, nil] do
    case Extensions.resolve_compiled(extension_context(profile, mode, surface)) do
      {:ok, %{seams: %{session_runtime_modules: modules}}} ->
        if Map.has_key?(modules, surface.semantic_protocol) do
          surface.semantic_protocol
        else
          :none
        end

      {:error, :no_matching_family} ->
        :none
    end
  end

  defp session_runtime_for(_profile, _mode, _surface, _strategy), do: :none

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
