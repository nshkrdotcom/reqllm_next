defmodule ReqLlmNext.Extensions.Definitions.OpenAI do
  @moduledoc """
  OpenAI provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :openai do
      default_family(:openai_chat_compatible)
      description("OpenAI provider and OpenAI-compatible happy-path family")

      register do
        provider_module(ReqLlmNext.Providers.OpenAI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenAI)
      end
    end
  end

  families do
    family :openai_responses_compatible do
      extends(:openai_chat_compatible)
      priority(200)
      description("OpenAI Responses family")

      match do
        facts(responses_api?: true)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIResponses)

        surface_preparation_modules(
          openai_responses: ReqLlmNext.SurfacePreparation.OpenAIResponses
        )

        session_runtime_modules(openai_responses: ReqLlmNext.SessionRuntimes.OpenAIResponses)

        semantic_protocol_modules(openai_responses: ReqLlmNext.SemanticProtocols.OpenAIResponses)

        wire_modules(
          openai_responses_sse_json: ReqLlmNext.Wire.OpenAIResponses,
          openai_responses_ws_json: ReqLlmNext.Wire.OpenAIResponses
        )

        transport_modules(websocket: ReqLlmNext.Transports.OpenAIResponsesWebSocket)
      end
    end
  end

  rules do
    rule :openai_reasoning_models do
      priority(200)
      description("Apply reasoning-model adapter behavior on OpenAI Responses models")

      match do
        family_ids([:openai_responses_compatible])
        features(reasoning: [supported: true])
      end

      patch do
        adapter_modules([ReqLlmNext.Adapters.OpenAI.Reasoning])
      end
    end
  end
end
