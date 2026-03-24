defmodule ReqLlmNext.ModelProfile.ProviderFacts do
  @moduledoc """
  Provider-scoped descriptive fact extraction for ModelProfile construction.
  """

  alias ReqLlmNext.Extensions

  @type extracted :: %{
          additional_document_input?: boolean(),
          citations_supported?: boolean(),
          context_management_supported?: boolean(),
          structured_outputs_native?: boolean(),
          responses_api?: boolean()
        }

  @spec extract(LLMDB.Model.t()) :: extracted()
  def extract(%LLMDB.Model{} = model) do
    default = default_facts()

    case Extensions.provider(Extensions.compiled_manifest(), model.provider) do
      {:ok, %{seams: %{provider_facts_module: module}}} when not is_nil(module) ->
        Map.merge(default, module.extract(model))

      _other ->
        default
    end
  end

  @spec default_facts() :: extracted()
  def default_facts do
    %{
      additional_document_input?: false,
      citations_supported?: false,
      context_management_supported?: false,
      structured_outputs_native?: false,
      responses_api?: false
    }
  end
end
