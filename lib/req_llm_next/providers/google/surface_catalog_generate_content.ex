defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.GoogleGenerateContent do
  @moduledoc """
  Google Gemini generateContent surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

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
end
