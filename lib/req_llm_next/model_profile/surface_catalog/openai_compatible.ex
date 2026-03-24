defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible do
  @moduledoc """
  Default OpenAI-compatible surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(:text, text_surfaces(model, provider_facts))
        |> Helpers.maybe_put_surfaces(:object, object_surfaces(model, provider_facts))
        |> Helpers.maybe_put_surfaces(:embed, embed_surfaces(model)),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp text_surfaces(model, provider_facts) do
    if Helpers.chat_supported?(model) do
      [
        Helpers.chat_surface(
          :openai_chat,
          :text,
          :openai_chat,
          :openai_chat_sse_json,
          :http_sse,
          Helpers.surface_features(model, :text, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp object_surfaces(model, provider_facts) do
    if Helpers.chat_supported?(model) do
      [
        Helpers.chat_surface(
          :openai_chat,
          :object,
          :openai_chat,
          :openai_chat_sse_json,
          :http_sse,
          Helpers.surface_features(model, :object, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp embed_surfaces(model) do
    if Helpers.embeddings_supported?(model) do
      [Helpers.embedding_surface()]
    else
      []
    end
  end
end
