defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.ZenmuxResponses do
  @moduledoc """
  Zenmux Responses surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(:text, response_surfaces(model, :text, provider_facts))
        |> Helpers.maybe_put_surfaces(:object, response_surfaces(model, :object, provider_facts)),
      session_capabilities: %{persistent: true, continuation_strategies: [:previous_response_id]}
    }
  end

  defp response_surfaces(model, operation, provider_facts) do
    if Helpers.chat_supported?(model, provider_facts) do
      [
        Helpers.chat_surface(
          :zenmux_responses,
          operation,
          :openai_responses,
          :openai_responses_sse_json,
          :http_sse,
          Helpers.surface_features(model, operation, provider_facts),
          []
        )
      ]
    else
      []
    end
  end
end
