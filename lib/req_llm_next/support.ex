defmodule ReqLlmNext.Support do
  @moduledoc """
  Support-tier inspection for resolved models.
  """

  alias ReqLlmNext.{ModelProfile, ModelResolver, RuntimeMetadata}

  @type status :: :first_class | :best_effort | {:unsupported, term()}

  @spec support_status(LLMDB.Model.t()) :: status()
  def support_status(%LLMDB.Model{} = model) do
    case ModelProfile.from_model(model) do
      {:ok, profile} ->
        cond do
          Enum.any?(profile.operations, fn {_operation, facts} -> facts.supported == true end) and
              RuntimeMetadata.registered_provider?(model.provider) ->
            :first_class

          true ->
            RuntimeMetadata.support_status(model)
        end

      {:error, _reason} ->
        RuntimeMetadata.support_status(model)
    end
  end

  @spec support_status(ReqLlmNext.model_spec()) :: status()
  def support_status(model_spec) when is_binary(model_spec) do
    case ModelResolver.resolve(model_spec) do
      {:ok, model} -> support_status(model)
      {:error, reason} -> {:unsupported, reason}
    end
  end
end
