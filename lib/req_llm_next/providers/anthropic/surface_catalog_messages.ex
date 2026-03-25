defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.AnthropicMessages do
  @moduledoc """
  Anthropic Messages surface catalog.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers

  @spec build(LLMDB.Model.t(), map()) :: %{surfaces: map(), session_capabilities: map()}
  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces:
        %{}
        |> Helpers.maybe_put_surfaces(:text, text_surfaces(model, provider_facts))
        |> Helpers.maybe_put_surfaces(:object, object_surfaces(model, provider_facts)),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp text_surfaces(model, provider_facts) do
    if Helpers.chat_supported?(model, provider_facts) do
      [
        Helpers.chat_surface(
          :anthropic_messages,
          :text,
          :anthropic_messages,
          :anthropic_messages_sse_json,
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
    if Helpers.chat_supported?(model, provider_facts) do
      [
        Helpers.chat_surface(
          :anthropic_messages,
          :object,
          :anthropic_messages,
          :anthropic_messages_sse_json,
          :http_sse,
          Helpers.surface_features(model, :object, provider_facts),
          []
        )
      ]
    else
      []
    end
  end
end
