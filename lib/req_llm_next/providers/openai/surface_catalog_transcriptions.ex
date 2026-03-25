defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAITranscriptions do
  @moduledoc """
  OpenAI transcription surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = _model, _provider_facts) do
    %{
      surfaces: %{
        transcription: [
          Helpers.request_surface(
            :openai_transcription_http,
            :transcription,
            :openai_transcription,
            :openai_transcription_multipart
          )
        ]
      },
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end
end
