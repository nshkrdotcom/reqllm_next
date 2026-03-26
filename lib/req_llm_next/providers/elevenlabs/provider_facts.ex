defmodule ReqLlmNext.ModelProfile.ProviderFacts.ElevenLabs do
  @moduledoc """
  ElevenLabs-specific descriptive fact extraction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    media_api = media_api(model)

    %{
      responses_api?: false,
      structured_outputs_native?: false,
      citations_supported?: false,
      context_management_supported?: false,
      media_api: media_api,
      transcription_supported?: media_api == :transcription,
      speech_supported?: media_api == :speech,
      chat_supported?: false
    }
  end

  @spec media_api(LLMDB.Model.t()) :: :speech | :transcription
  def media_api(%LLMDB.Model{} = model) do
    api = get_in(model, [Access.key(:extra, %{}), :api])
    model_id = String.downcase(model.id || "")
    capabilities = Map.get(model, :capabilities) || %{}

    cond do
      api in ["speech-to-text", "speech_to_text", "transcription", "stt"] ->
        :transcription

      api in ["text-to-speech", "text_to_speech", "speech", "tts"] ->
        :speech

      transcription_capability?(capabilities) ->
        :transcription

      String.contains?(model_id, "scribe") ->
        :transcription

      true ->
        :speech
    end
  end

  defp transcription_capability?(capabilities) when is_map(capabilities) do
    case Map.get(capabilities, :transcription) do
      true -> true
      %{enabled: true} -> true
      _ -> false
    end
  end

  defp transcription_capability?(_capabilities), do: false
end
