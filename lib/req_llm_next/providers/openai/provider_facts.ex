defmodule ReqLlmNext.ModelProfile.ProviderFacts.OpenAI do
  @moduledoc """
  OpenAI-specific descriptive fact extraction for ModelProfile construction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted()
  def extract(%LLMDB.Model{} = model) do
    %{
      additional_document_input?: attachments_supported?(model),
      citations_supported?: false,
      context_management_supported?: false,
      structured_outputs_native?: false,
      responses_api?: responses_api?(model)
    }
  end

  @spec attachments_supported?(LLMDB.Model.t()) :: boolean()
  def attachments_supported?(%LLMDB.Model{} = model) do
    get_in(model, [Access.key(:extra, %{}), :attachment]) == true
  end

  @spec responses_api?(LLMDB.Model.t()) :: boolean()
  def responses_api?(%LLMDB.Model{} = model) do
    wire_protocol =
      case get_in(model, [Access.key(:extra, %{}), :wire, :protocol]) do
        protocol when is_binary(protocol) -> protocol
        protocol when is_atom(protocol) -> Atom.to_string(protocol)
        _ -> nil
      end

    api = get_in(model, [Access.key(:extra, %{}), :api])

    wire_protocol == "openai_responses" or api == "responses"
  end
end
