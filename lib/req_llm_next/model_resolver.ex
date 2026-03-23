defmodule ReqLlmNext.ModelResolver do
  @moduledoc """
  Thin runtime boundary over the `llm_db` package.

  String `model_spec` values are delegated to `LLMDB.model/1`.
  `%LLMDB.Model{}` values pass through unchanged, whether they came from `LLMDB`
  catalog lookup or were handcrafted locally for development.

  Accepted public input forms are:
  - `LLMDB` string `model_spec` values, including both `"provider:model"` and
    `"model@provider"` forms plus any provider-specific parsing behavior owned by `LLMDB`
  - `LLMDB.Model` structs, including handcrafted local structs (passthrough)
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
