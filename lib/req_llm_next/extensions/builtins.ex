defmodule ReqLlmNext.Extensions.Builtins do
  @moduledoc """
  Built-in extension declarations for the providers and execution families
  supported by ReqLlmNext.
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

    provider :anthropic do
      default_family(:anthropic_messages)
      description("Anthropic provider and Anthropic Messages family")

      seams do
        provider_module(ReqLlmNext.Providers.Anthropic)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Anthropic)
      end
    end
  end

  families do
    family :openai_chat_compatible do
      priority(100)
      default?(true)
      description("Default OpenAI-compatible chat family")

      criteria do
        provider_ids([:openai])
      end

      seams do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible)
      end
    end

    family :anthropic_messages do
      priority(100)
      description("Anthropic Messages family")

      criteria do
        provider_ids([:anthropic])
      end

      seams do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.AnthropicMessages)
      end
    end
  end

  rules do
    rule :openai_responses do
      priority(200)
      description("Opt into the OpenAI Responses family when model facts require it")

      criteria do
        provider_ids([:openai])
        facts(responses_api?: true)
      end

      seams do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIResponses)

        surface_preparation_modules(
          openai_responses: ReqLlmNext.SurfacePreparation.OpenAIResponses
        )
      end
    end
  end
end
