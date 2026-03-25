defmodule ReqLlmNext.ModelProfile.ProviderFacts.OpenAI do
  @moduledoc """
  OpenAI-specific descriptive fact extraction for ModelProfile construction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    media_api = media_api(model)

    %{
      additional_document_input?: attachments_supported?(model),
      citations_supported?: false,
      context_management_supported?: false,
      structured_outputs_native?: false,
      responses_api?: responses_api?(model),
      media_api: media_api,
      image_generation_supported?: media_api == :images,
      transcription_supported?: media_api == :transcription,
      speech_supported?: media_api == :speech,
      chat_supported?: chat_supported_override(media_api)
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

  @spec media_api(LLMDB.Model.t()) :: :images | :transcription | :speech | nil
  def media_api(%LLMDB.Model{} = model) do
    api = get_in(model, [Access.key(:extra, %{}), :api])
    model_id = model.id || ""

    cond do
      api == "images" ->
        :images

      String.starts_with?(model_id, "tts-") or String.ends_with?(model_id, "-tts") ->
        :speech

      String.starts_with?(model_id, "whisper-") or String.contains?(model_id, "transcribe") ->
        :transcription

      true ->
        nil
    end
  end

  defp chat_supported_override(media_api) when media_api in [:images, :transcription, :speech],
    do: false

  defp chat_supported_override(_media_api), do: nil
end
