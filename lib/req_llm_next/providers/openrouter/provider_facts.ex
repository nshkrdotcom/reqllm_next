defmodule ReqLlmNext.ModelProfile.ProviderFacts.OpenRouter do
  @moduledoc """
  OpenRouter-specific descriptive fact extraction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = _model) do
    %{
      responses_api?: false,
      structured_outputs_native?: false,
      citations_supported?: false,
      context_management_supported?: false,
      media_api: nil
    }
  end
end
