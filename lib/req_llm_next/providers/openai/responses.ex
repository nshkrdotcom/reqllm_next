defmodule ReqLlmNext.OpenAI.Responses do
  @moduledoc """
  OpenAI Responses utility helpers for retrieval, cancellation, and context management.
  """

  alias ReqLlmNext.{Context, Error, ModelResolver, OperationPlanner}
  alias ReqLlmNext.OpenAI.Client
  alias ReqLlmNext.Wire.OpenAIResponses

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(response_id, opts \\ []) when is_binary(response_id) do
    Client.json_request(:get, "/v1/responses/#{response_id}", nil, opts)
  end

  @spec cancel(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel(response_id, opts \\ []) when is_binary(response_id) do
    Client.json_request(:post, "/v1/responses/#{response_id}/cancel", %{}, opts)
  end

  @spec delete(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete(response_id, opts \\ []) when is_binary(response_id) do
    Client.json_request(:delete, "/v1/responses/#{response_id}", nil, opts)
  end

  @spec input_items(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def input_items(response_id, opts \\ []) when is_binary(response_id) do
    Client.json_request(
      :get,
      query_path("/v1/responses/#{response_id}/input_items", opts),
      nil,
      opts
    )
  end

  @spec compact(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def compact(response_id, opts \\ []) when is_binary(response_id) do
    Client.json_request(
      :post,
      "/v1/responses/#{response_id}/compact",
      build_compact_body(opts),
      opts
    )
  end

  @spec count_input_tokens(ReqLlmNext.model_spec(), String.t() | Context.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def count_input_tokens(model_source, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, plan} <- OperationPlanner.plan(model, :text, prompt, count_planning_opts(opts)),
         :ok <- ensure_openai_responses_surface(plan) do
      body = build_count_body(model, prompt, opts)
      Client.json_request(:post, "/v1/responses/input_tokens", body, opts)
    end
  end

  @doc false
  @spec build_count_body(LLMDB.Model.t(), String.t() | Context.t(), keyword()) :: map()
  def build_count_body(model, prompt, opts) do
    model
    |> OpenAIResponses.build_request_body(prompt, count_planning_opts(opts))
    |> Map.take([:model, :input, :tools])
    |> maybe_put(:conversation, Keyword.get(opts, :conversation))
  end

  @doc false
  @spec build_compact_body(keyword()) :: map()
  def build_compact_body(opts) do
    %{}
    |> maybe_put(:summary_format, Keyword.get(opts, :summary_format))
    |> maybe_put(:instructions, Keyword.get(opts, :instructions))
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
  end

  defp query_path(base, opts) do
    query =
      opts
      |> Keyword.take([:after, :before, :limit, :order])
      |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  defp ensure_openai_responses_surface(plan) do
    if plan.surface.semantic_protocol == :openai_responses do
      :ok
    else
      {:error,
       Error.Invalid.Capability.exception(
         capability: "response input token counting",
         model: plan.model.model_id,
         provider: plan.provider,
         reason: "requires an OpenAI Responses surface"
       )}
    end
  end

  defp count_planning_opts(opts) do
    opts
    |> Keyword.put(:operation, :text)
    |> Keyword.drop([:conversation])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
