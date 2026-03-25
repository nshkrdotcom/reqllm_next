defmodule ReqLlmNext.OpenAI.Background do
  @moduledoc """
  OpenAI background response helpers.
  """

  alias ReqLlmNext.{
    Error,
    ModelResolver,
    ObjectPrompt,
    OperationPlanner,
    Schema
  }

  alias ReqLlmNext.OpenAI.{Client, Responses}
  alias ReqLlmNext.Wire.OpenAIResponses

  @type operation :: :text | :object

  @spec submit(ReqLlmNext.model_spec(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def submit(model_source, prompt, opts \\ []) do
    operation = Keyword.get(opts, :operation, :text)

    with {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, planning_opts, execution_prompt} <-
           planning_input(model_source, model, operation, prompt, opts),
         {:ok, plan} <- OperationPlanner.plan(model, operation, execution_prompt, planning_opts),
         {:ok, execution_prompt} <- execution_prompt(execution_prompt, plan, planning_opts),
         :ok <- ensure_openai_responses_surface(plan) do
      body = encode_background_body(model, execution_prompt, planning_opts)
      Client.json_request(:post, OpenAIResponses.path(), body, opts)
    end
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(response_id, opts \\ []), do: Responses.get(response_id, opts)

  @spec cancel(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel(response_id, opts \\ []), do: Responses.cancel(response_id, opts)

  defp planning_input(model_source, _model, :text, prompt, opts) do
    planning_opts =
      opts
      |> Keyword.put(:latency_class, :background)
      |> Keyword.put(:background, true)
      |> Keyword.put(:_model_spec, inspect(model_source))

    {:ok, planning_opts, prompt}
  end

  defp planning_input(model_source, _model, :object, prompt, opts) do
    with {:ok, schema} <- Keyword.fetch(opts, :schema),
         {:ok, compiled_schema} <- Schema.compile(schema),
         planning_opts <-
           opts
           |> Keyword.put(:compiled_schema, compiled_schema)
           |> Keyword.put(:operation, :object)
           |> Keyword.put(:latency_class, :background)
           |> Keyword.put(:background, true)
           |> Keyword.put(:_model_spec, inspect(model_source)) do
      {:ok, planning_opts, prompt}
    else
      :error ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "background object requests require :schema"
         )}

      {:error, {:invalid_schema, _reason}} = error ->
        error
    end
  end

  defp ensure_openai_responses_surface(plan) do
    if plan.surface.semantic_protocol == :openai_responses do
      :ok
    else
      {:error,
       Error.Invalid.Capability.exception(
         capability: "background responses",
         model: plan.model.model_id,
         provider: plan.provider,
         reason: "requires an OpenAI Responses surface"
       )}
    end
  end

  defp encode_background_body(model, prompt, opts) do
    OpenAIResponses.encode_body(model, prompt, Keyword.put(opts, :background, true))
  end

  @doc false
  @spec build_request_body(LLMDB.Model.t(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          map()
  def build_request_body(model, prompt, opts) do
    encode_background_body(model, prompt, opts)
  end

  defp execution_prompt(prompt, plan, opts) do
    case {plan.mode.operation, plan.surface.features.structured_output} do
      {:object, :prompt_and_parse} ->
        {:ok, ObjectPrompt.for_prompt_and_parse(prompt, Keyword.fetch!(opts, :compiled_schema))}

      _ ->
        {:ok, prompt}
    end
  end
end
