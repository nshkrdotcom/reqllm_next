defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.CohereChat do
  @moduledoc """
  Cohere chat surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(:text, chat_surfaces(model, :text, provider_facts))
        |> Helpers.maybe_put_surfaces(:object, chat_surfaces(model, :object, provider_facts)),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp chat_surfaces(model, operation, provider_facts) do
    if Helpers.chat_supported?(model, provider_facts) do
      [
        Helpers.chat_surface(
          :cohere_chat,
          operation,
          :cohere_chat,
          :cohere_chat_sse_json,
          :http_sse,
          surface_features(model, operation, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp surface_features(model, operation, provider_facts) do
    model
    |> Helpers.surface_features(operation, provider_facts)
    |> Map.put(:tools, false)
    |> Map.put(:reasoning, false)
  end
end
