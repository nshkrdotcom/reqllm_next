defmodule ReqLlmNext.OperationPlanner do
  @moduledoc """
  Builds deterministic execution plans from model facts, request mode, and policy.
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    ExecutionMode,
    ExecutionPlan,
    ModelProfile,
    PolicyRules,
    SurfacePreparation,
    Validation
  }

  @type operation :: :text | :object | :embed

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
         semantic_protocol: policy.surface.semantic_protocol,
         wire_format: policy.surface.wire_format,
         transport: policy.surface.transport,
         parameter_values: parameter_values,
         timeout_class: policy.timeout_class,
         timeout_ms: policy.timeout_ms,
         session_strategy: policy.session_strategy,
         fallback_surfaces: policy.fallback_surfaces,
         plan_adapters: plan_adapters_for(model, policy.surface)
       })}
    end
  end

  defp plan_adapters_for(model, _surface), do: AdapterPipeline.adapters_for(model)
end
