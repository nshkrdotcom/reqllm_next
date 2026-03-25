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
          responses_api?: boolean(),
          media_api: :images | :transcription | :speech | nil,
          image_generation_supported?: boolean(),
          transcription_supported?: boolean(),
          speech_supported?: boolean(),
          chat_supported?: boolean() | nil
        }

  @type extracted_patch :: %{
          optional(:additional_document_input?) => boolean(),
          optional(:citations_supported?) => boolean(),
          optional(:context_management_supported?) => boolean(),
          optional(:structured_outputs_native?) => boolean(),
          optional(:responses_api?) => boolean(),
          optional(:media_api) => :images | :transcription | :speech | nil,
          optional(:image_generation_supported?) => boolean(),
          optional(:transcription_supported?) => boolean(),
          optional(:speech_supported?) => boolean(),
          optional(:chat_supported?) => boolean() | nil
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
      responses_api?: false,
      media_api: nil,
      image_generation_supported?: false,
      transcription_supported?: false,
      speech_supported?: false,
      chat_supported?: nil
    }
  end
end
