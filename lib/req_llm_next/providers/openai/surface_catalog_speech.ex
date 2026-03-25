defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAISpeech do
  @moduledoc """
  OpenAI speech-generation surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = _model, _provider_facts) do
    %{
      surfaces: %{
        speech: [
          Helpers.request_surface(
            :openai_speech_http,
            :speech,
            :openai_speech,
            :openai_speech_json
          )
        ]
      },
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end
end
