defmodule ReqLlmNext.ModelResolver do
  @moduledoc """
  Thin runtime boundary over the `llm_db` package.

  String model specs are delegated to `LLMDB.model/1`.
  Already-resolved `%LLMDB.Model{}` values pass through unchanged.

  Accepted public input forms are:
  - `"provider:model_id"` strings (e.g., `"openai:gpt-4o"`)
  - `LLMDB.Model` structs (passthrough)
  """

  @spec resolve(ReqLlmNext.model_spec()) ::
          {:ok, LLMDB.Model.t()} | {:error, term()}
  def resolve(%LLMDB.Model{} = model), do: {:ok, model}

  def resolve(model_spec) when is_binary(model_spec) do
    case LLMDB.model(model_spec) do
      {:ok, model} -> {:ok, model}
      {:error, reason} -> {:error, {:model_not_found, model_spec, reason}}
    end
  end

  def resolve(other), do: {:error, {:invalid_model_spec, other}}
end
