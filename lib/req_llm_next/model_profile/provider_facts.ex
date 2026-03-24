defmodule ReqLlmNext.ModelProfile.ProviderFacts do
  @moduledoc """
  Provider-scoped descriptive fact extraction for ModelProfile construction.
  """

  alias ReqLlmNext.ModelProfile.ProviderFacts.{Anthropic, OpenAI}

  @type extracted :: %{
          additional_document_input?: boolean(),
          citations_supported?: boolean(),
          context_management_supported?: boolean(),
          structured_outputs_native?: boolean(),
          responses_api?: boolean()
        }

  @spec extract(LLMDB.Model.t()) :: extracted()
  def extract(%LLMDB.Model{provider: :anthropic} = model), do: Anthropic.extract(model)
  def extract(%LLMDB.Model{provider: :openai} = model), do: OpenAI.extract(model)

  def extract(%LLMDB.Model{}) do
    %{
      additional_document_input?: false,
      citations_supported?: false,
      context_management_supported?: false,
      structured_outputs_native?: false,
      responses_api?: false
    }
  end
end
