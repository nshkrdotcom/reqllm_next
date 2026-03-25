defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIImages do
  @moduledoc """
  OpenAI image-generation surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = _model, _provider_facts) do
    %{
      surfaces: %{
        image: [
          Helpers.request_surface(
            :openai_images_image_http,
            :image,
            :openai_images,
            :openai_images_json
          )
        ]
      },
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end
end
