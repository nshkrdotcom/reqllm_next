defmodule ReqLlmNext.Extensions.Definitions.OpenRouter do
  @moduledoc """
  OpenRouter provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :openrouter do
      default_family(:openrouter_chat_compatible)

      description(
        "OpenRouter provider using the OpenAI-compatible chat family with routing overrides"
      )

      register do
        provider_module(ReqLlmNext.Providers.OpenRouter)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenRouter)
      end
    end
  end

  families do
    family :openrouter_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("OpenRouter chat-completions family")

      match do
        provider_ids([:openrouter])
      end

      stack do
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.OpenRouterChat)
      end
    end
  end
end
