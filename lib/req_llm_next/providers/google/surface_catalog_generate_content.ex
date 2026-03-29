defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.GoogleGenerateContent do
  @moduledoc """
  Google Gemini generateContent surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers
  alias ReqLlmNext.ModelHelpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(
          :text,
          generate_content_surfaces(model, :text, provider_facts)
        )
        |> Helpers.maybe_put_surfaces(
          :object,
          generate_content_surfaces(model, :object, provider_facts)
        )
        |> Helpers.maybe_put_surfaces(
          :embed,
          embedding_surfaces(model, provider_facts)
        )
        |> Helpers.maybe_put_surfaces(
          :image,
          image_surfaces(model, provider_facts)
        ),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp generate_content_surfaces(model, operation, provider_facts) do
    if Helpers.chat_supported?(model, provider_facts) do
      [
        Helpers.chat_surface(
          :google_generate_content,
          operation,
          :google_generate_content,
          :google_generate_content_sse_json,
          :http_sse,
          Helpers.surface_features(model, operation, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp embedding_surfaces(model, provider_facts) do
    if embeddings_supported?(model, provider_facts) do
      [
        Helpers.request_surface(
          :google_embeddings_embed_http,
          :embed,
          :google_embeddings,
          :google_embeddings_json
        )
      ]
    else
      []
    end
  end

  defp image_surfaces(model, provider_facts) do
    if image_generation_supported?(model, provider_facts) do
      [
        Helpers.request_surface(
          :google_images_image_http,
          :image,
          :google_images,
          :google_images_json
        )
      ]
    else
      []
    end
  end

  defp embeddings_supported?(model, _provider_facts) do
    ModelHelpers.embeddings?(model) or :embedding in (model.modalities[:output] || [])
  end

  defp image_generation_supported?(model, provider_facts) do
    provider_facts.image_generation_supported? or
      ModelHelpers.supports_image_generation?(model)
  end
end
