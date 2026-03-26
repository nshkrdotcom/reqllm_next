defmodule ReqLlmNext.Extensions.Definitions.Google do
  @moduledoc """
  Google Gemini provider declarations.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :google do
      default_family(:google_generate_content)
      description("Google Gemini provider using the native generateContent family")

      register do
        provider_module(ReqLlmNext.Providers.Google)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Google)
      end
    end
  end

  families do
    family :google_generate_content do
      priority(225)
      description("Google Gemini generateContent family")

      match do
        provider_ids([:google])
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.GoogleGenerateContent)

        surface_preparation_modules(
          google_generate_content: ReqLlmNext.SurfacePreparation.GoogleGenerateContent
        )

        semantic_protocol_modules(
          google_generate_content: ReqLlmNext.SemanticProtocols.GoogleGenerateContent
        )

        wire_modules(google_generate_content_sse_json: ReqLlmNext.Wire.GoogleGenerateContent)
      end
    end
  end
end
