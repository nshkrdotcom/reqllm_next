defmodule ReqLlmNext.Extensions.Definitions.OpenAI do
  @moduledoc """
  OpenAI provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :openai do
      default_family(:openai_chat_compatible)
      description("OpenAI provider and OpenAI-compatible happy-path family")

      seams do
        provider_module(ReqLlmNext.Providers.OpenAI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenAI)
      end
    end
  end

  families do
    family :openai_responses_compatible do
      priority(200)
      description("OpenAI Responses family")

      criteria do
        provider_ids([:openai])
        facts(responses_api?: true)
      end

      seams do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIResponses)

        surface_preparation_modules(
          openai_responses: ReqLlmNext.SurfacePreparation.OpenAIResponses
        )

        semantic_protocol_modules(
          openai_responses: ReqLlmNext.SemanticProtocols.OpenAIResponses,
          openai_embeddings: nil
        )

        wire_modules(
          openai_responses_sse_json: ReqLlmNext.Wire.OpenAIResponses,
          openai_responses_ws_json: ReqLlmNext.Wire.OpenAIResponses,
          openai_embeddings_json: ReqLlmNext.Wire.OpenAIEmbeddings
        )

        transport_modules(
          http: nil,
          http_sse: ReqLlmNext.Transports.HTTPStream,
          websocket: ReqLlmNext.Transports.OpenAIResponsesWebSocket
        )
      end
    end
  end

  rules do
    rule :openai_reasoning_models do
      priority(200)
      description("Apply reasoning-model adapter behavior on OpenAI Responses models")

      criteria do
        family_ids([:openai_responses_compatible])
        features(reasoning: [supported: true])
      end

      seams do
        adapter_modules([ReqLlmNext.Adapters.OpenAI.Reasoning])
      end
    end
  end
end
