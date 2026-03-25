defmodule ReqLlmNext.ModelProfile.ProviderFacts.Groq do
  @moduledoc """
  Groq-specific descriptive fact extraction.
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
      chat_supported?: chat_supported_override(media_api)
    }
  end

  @spec media_api(LLMDB.Model.t()) :: :transcription | nil
  def media_api(%LLMDB.Model{} = model) do
    api = get_in(model, [Access.key(:extra, %{}), :api])
    tags = Map.get(model, :tags) || []

    cond do
      api == "audio" ->
        :transcription

      "transcription" in tags or "stt" in tags ->
        :transcription

      String.starts_with?(model.id || "", "whisper-") ->
        :transcription

      true ->
        nil
    end
  end

  defp chat_supported_override(:transcription), do: false
  defp chat_supported_override(_media_api), do: nil
end
