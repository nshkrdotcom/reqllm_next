defmodule ReqLlmNext.Extensions.Definitions.Zenmux do
  @moduledoc """
  Zenmux provider declarations layered on top of the OpenAI-compatible families.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :zenmux do
      default_family(:zenmux_responses_compatible)
      description("Zenmux provider using Responses-first defaults with chat fallback")

      register do
        provider_module(ReqLlmNext.Providers.Zenmux)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Zenmux)
      end
    end
  end

  families do
    family :zenmux_responses_compatible do
      extends(:openai_responses_compatible)
      priority(175)
      description("Zenmux Responses family")

      match do
        provider_ids([:zenmux])
        facts(responses_api?: true)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.ZenmuxResponses)
        wire_modules(openai_responses_sse_json: ReqLlmNext.Wire.ZenmuxResponses)
      end
    end

    family :zenmux_chat_compatible do
      extends(:openai_chat_compatible)
      priority(175)
      description("Zenmux chat-completions family")

      match do
        provider_ids([:zenmux])
        facts(responses_api?: false)
      end

      stack do
        semantic_protocol_modules(openai_chat: ReqLlmNext.SemanticProtocols.ZenmuxChat)
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.ZenmuxChat)
      end
    end
  end
end
