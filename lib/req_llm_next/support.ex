defmodule ReqLlmNext.Support do
  @moduledoc """
  Support-tier inspection for resolved models.
  """

  alias ReqLlmNext.{ModelResolver, RuntimeMetadata}

  @type status :: :first_class | :best_effort | {:unsupported, term()}

  @spec support_status(ReqLlmNext.model_spec()) :: status()
  def support_status(model_spec) do
    case ModelResolver.resolve(model_spec) do
      {:ok, model} -> RuntimeMetadata.support_status(model)
      {:error, reason} -> {:unsupported, reason}
    end
  end
end
