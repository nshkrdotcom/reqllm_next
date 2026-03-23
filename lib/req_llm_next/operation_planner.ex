defmodule ReqLlmNext.OperationPlanner do
  @moduledoc """
  Builds deterministic execution plans from model facts, request mode, and policy.
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    Constraints,
    ExecutionMode,
    ExecutionPlan,
    ModelProfile,
    PolicyRules,
    Validation
  }

  @type operation :: :text | :object | :embed

  @spec plan(LLMDB.Model.t(), operation(), term(), keyword()) ::
          {:ok, ExecutionPlan.t()} | {:error, term()}
  def plan(%LLMDB.Model{} = model, operation, prompt, opts \\ []) do
    with :ok <- Validation.validate!(model, operation, context_for(prompt), opts),
         {:ok, profile} <- ModelProfile.from_model(model, spec: Keyword.get(opts, :_model_spec)),
         {:ok, mode} <- ExecutionMode.from_request(operation, prompt, opts),
         {:ok, policy} <- PolicyRules.resolve(profile, mode, opts) do
      {:ok,
       ExecutionPlan.new!(%{
         model: profile,
         mode: mode,
         surface: policy.surface,
         provider: profile.provider,
         semantic_protocol: policy.surface.semantic_protocol,
         wire_format: policy.surface.wire_format,
         transport: policy.surface.transport,
         parameter_values: normalize_parameter_values(model, opts),
         timeout_class: policy.timeout_class,
         timeout_ms: policy.timeout_ms,
         session_strategy: policy.session_strategy,
         fallback_surfaces: policy.fallback_surfaces,
         plan_adapters: AdapterPipeline.adapters_for(model)
       })}
    end
  end

  defp context_for(%ReqLlmNext.Context{} = context), do: context
  defp context_for(_), do: nil

  defp normalize_parameter_values(model, opts) do
    normalized_opts =
      opts
      |> Keyword.drop([:_stream?, :_model_spec])
      |> then(&Constraints.apply(model, &1))

    Enum.into(normalized_opts, %{})
  end
end
