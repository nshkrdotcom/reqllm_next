defmodule ReqLlmNext.Extensions.Definitions.Cohere do
  @moduledoc """
  Cohere provider declarations.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :cohere do
      default_family(:cohere_chat)
      description("Cohere provider using the native chat family")

      register do
        provider_module(ReqLlmNext.Providers.Cohere)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Cohere)
      end
    end
  end

  families do
    family :cohere_chat do
      priority(225)
      description("Cohere chat family")

      match do
        provider_ids([:cohere])
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.CohereChat)

        surface_preparation_modules(cohere_chat: ReqLlmNext.SurfacePreparation.CohereChat)

        semantic_protocol_modules(cohere_chat: ReqLlmNext.SemanticProtocols.CohereChat)

        wire_modules(cohere_chat_sse_json: ReqLlmNext.Wire.CohereChat)
      end
    end
  end
end
