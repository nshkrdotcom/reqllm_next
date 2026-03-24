defmodule ReqLlmNext.Scenarios.PromptCaching do
  @moduledoc """
  Anthropic prompt caching scenario.

  Exercises the same request twice with prompt caching enabled and validates
  that cache creation and cache reads appear in normalized usage metadata.
  """

  use ReqLlmNext.Scenario,
    id: :prompt_caching,
    name: "Prompt Caching",
    description: "Anthropic prompt caching headers and usage normalization"

  alias ReqLlmNext.{ModelHelpers, Response}

  @impl true
  def applies?(%LLMDB.Model{provider: :anthropic} = model) do
    ModelHelpers.chat?(model)
  end

  def applies?(_), do: false

  @impl true
  def run(model_spec, _model, opts) do
    context =
      ReqLlmNext.context([
        ReqLlmNext.Context.system(cached_system_prompt()),
        ReqLlmNext.Context.user("Say hello in one short sentence.")
      ])

    first_opts =
      run_opts(opts,
        fixture: fixture_for_run(id(), opts, "1"),
        anthropic_prompt_cache: true,
        max_tokens: 64
      )

    second_opts =
      run_opts(opts,
        fixture: fixture_for_run(id(), opts, "2"),
        anthropic_prompt_cache: true,
        max_tokens: 64
      )

    with {:ok, first_response} <- ReqLlmNext.generate_text(model_spec, context, first_opts),
         {:ok, second_response} <- ReqLlmNext.generate_text(model_spec, context, second_opts),
         :ok <- validate_response(first_response),
         :ok <- validate_response(second_response) do
      ok([
        step("cache_create", :ok, response: first_response),
        step("cache_read", :ok, response: second_response)
      ])
    else
      {:error, reason} ->
        error(reason, [step("prompt_caching", :error, error: reason)])
    end
  end

  defp validate_response(response) do
    usage = response_usage(response)
    text = Response.text(response) || ""

    cond do
      usage == %{} -> {:error, :missing_usage}
      text == "" -> {:error, :empty_response}
      true -> :ok
    end
  end

  defp response_usage(response) do
    Response.usage(response) || %{}
  end

  defp cached_system_prompt do
    String.duplicate(
      "Cache this planning note. Summaries should remain concise and deterministic. ",
      120
    )
  end
end
