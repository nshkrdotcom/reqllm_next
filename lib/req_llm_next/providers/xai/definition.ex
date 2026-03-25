defmodule ReqLlmNext.Extensions.Definitions.XAI do
  @moduledoc """
  xAI provider declarations layered on top of OpenAI-compatible families.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :xai do
      default_family(:xai_responses_compatible)
      description("xAI provider using Responses-first text surfaces and image deltas")

      register do
        provider_module(ReqLlmNext.Providers.XAI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.XAI)

        utility_modules(tools: ReqLlmNext.XAI.Tools)
      end
    end
  end

  families do
    family :xai_responses_compatible do
      extends(:openai_responses_compatible)
      priority(150)
      description("xAI Responses family")

      match do
        provider_ids([:xai])
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.XAIResponses)

        surface_preparation_modules(openai_responses: ReqLlmNext.SurfacePreparation.XAIResponses)

        semantic_protocol_modules(openai_responses: ReqLlmNext.SemanticProtocols.XAIResponses)

        wire_modules(openai_responses_sse_json: ReqLlmNext.Wire.XAIResponses)
      end
    end

    family :xai_images do
      extends(:xai_responses_compatible)
      priority(250)
      description("xAI image generation family")

      match do
        facts(responses_api?: false, media_api: :images)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIMedia)
        surface_preparation_modules(openai_images: ReqLlmNext.SurfacePreparation.OpenAIImages)
        semantic_protocol_modules(openai_images: nil)
        wire_modules(openai_images_json: ReqLlmNext.Wire.OpenAIImages)
      end
    end
  end
end
