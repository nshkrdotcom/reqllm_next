defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIMedia do
  @moduledoc """
  OpenAI media surface catalogs for image, transcription, and speech operations.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = _model, provider_facts) when is_map(provider_facts) do
    %{surfaces: %{operation(provider_facts) => [surface(provider_facts)]}, session_capabilities: media_session_capabilities()}
  end

  defp operation(%{media_api: :images}), do: :image
  defp operation(%{media_api: :transcription}), do: :transcription
  defp operation(%{media_api: :speech}), do: :speech

  defp surface(%{media_api: :images}) do
    Helpers.request_surface(:openai_images_image_http, :image, :openai_images, :openai_images_json)
  end

  defp surface(%{media_api: :transcription}) do
    Helpers.request_surface(
      :openai_transcription_http,
      :transcription,
      :openai_transcription,
      :openai_transcription_multipart
    )
  end

  defp surface(%{media_api: :speech}) do
    Helpers.request_surface(:openai_speech_http, :speech, :openai_speech, :openai_speech_json)
  end

  defp media_session_capabilities do
    %{persistent: false, continuation_strategies: []}
  end
end
