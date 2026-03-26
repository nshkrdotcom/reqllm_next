defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.ElevenLabsMedia do
  @moduledoc """
  ElevenLabs media surface catalog for speech and transcription operations.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = _model, provider_facts) when is_map(provider_facts) do
    %{
      surfaces: %{operation(provider_facts) => [surface(provider_facts)]},
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp operation(%{media_api: :speech}), do: :speech
  defp operation(%{media_api: :transcription}), do: :transcription

  defp surface(%{media_api: :speech}) do
    Helpers.request_surface(
      :elevenlabs_speech_http,
      :speech,
      :elevenlabs_speech,
      :elevenlabs_speech_json
    )
  end

  defp surface(%{media_api: :transcription}) do
    Helpers.request_surface(
      :elevenlabs_transcription_http,
      :transcription,
      :elevenlabs_transcription,
      :elevenlabs_transcription_multipart
    )
  end
end
