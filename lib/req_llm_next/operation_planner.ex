defmodule ReqLlmNext.OperationPlanner do
  @moduledoc """
  Builds deterministic execution plans from model facts, request mode, and policy.
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    Constraints,
    Error,
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
         {:ok, policy} <- PolicyRules.resolve(profile, mode, opts),
         {:ok, parameter_values} <- normalize_parameter_values(model, policy.surface, opts) do
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

  defp context_for(%ReqLlmNext.Context{} = context), do: context
  defp context_for(_), do: nil

  defp normalize_parameter_values(model, surface, opts) do
    normalized_opts =
      opts
      |> Keyword.drop([:_stream?, :_model_spec])
      |> then(&Constraints.apply(model, &1))

    with :ok <- validate_surface_parameters(surface, normalized_opts) do
      {:ok, Enum.into(normalized_opts, %{})}
    end
  end

  defp validate_surface_parameters(%{wire_format: :openai_responses_ws_json}, opts) do
    if Keyword.has_key?(opts, :temperature) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "temperature is not supported for OpenAI Responses WebSocket mode"
       )}
    else
      :ok
    end
  end

  defp validate_surface_parameters(_surface, _opts), do: :ok

  defp plan_adapters_for(model, %{wire_format: :openai_responses_ws_json}) do
    model
    |> AdapterPipeline.adapters_for()
    |> Enum.reject(&(&1 == ReqLlmNext.Adapters.OpenAI.GPT4oMini))
  end

  defp plan_adapters_for(model, _surface), do: AdapterPipeline.adapters_for(model)
end
