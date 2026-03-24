defmodule ReqLlmNext.ModelProfile.ProviderFacts.Anthropic do
  @moduledoc """
  Anthropic-specific descriptive fact extraction for ModelProfile construction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted()
  def extract(%LLMDB.Model{} = model) do
    %{
      additional_document_input?: capability_enabled?(model, [:code_execution, :supported]),
      citations_supported?: capability_enabled?(model, [:citations, :supported]),
      context_management_supported?:
        capability_enabled?(model, [:context_management, :supported]),
      structured_outputs_native?: capability_enabled?(model, [:structured_outputs, :supported]),
      responses_api?: false
    }
  end

  defp capability_enabled?(%LLMDB.Model{} = model, path) when is_list(path) do
    get_in(model, [Access.key(:extra, %{}), Access.key(:capabilities, %{}) | path]) == true
  end
end
