defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIResponses do
  @moduledoc """
  OpenAI Responses surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(:text, response_surfaces(model, :text, provider_facts))
        |> Helpers.maybe_put_surfaces(:object, response_surfaces(model, :object, provider_facts))
        |> Helpers.maybe_put_surfaces(:embed, embed_surfaces(model)),
      session_capabilities: %{persistent: true, continuation_strategies: [:previous_response_id]}
    }
  end

  defp response_surfaces(model, operation, provider_facts) do
    if Helpers.chat_supported?(model) do
      [
        Helpers.chat_surface(
          :openai_responses,
          operation,
          :openai_responses,
          :openai_responses_sse_json,
          :http_sse,
          Helpers.surface_features(model, operation, provider_facts),
          [Helpers.surface_id(:openai_responses, operation, :websocket)]
        ),
        Helpers.chat_surface(
          :openai_responses,
          operation,
          :openai_responses,
          :openai_responses_ws_json,
          :websocket,
          Map.put(
            Helpers.surface_features(model, operation, provider_facts),
            :persistent_session,
            true
          ),
          [Helpers.surface_id(:openai_responses, operation, :http_sse)]
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
