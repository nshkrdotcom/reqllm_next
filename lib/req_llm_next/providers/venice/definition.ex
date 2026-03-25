defmodule ReqLlmNext.Extensions.Definitions.Venice do
  @moduledoc """
  Venice provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :venice do
      default_family(:venice_chat_compatible)
      description("Venice provider using the OpenAI-compatible family with Venice routing deltas")

      register do
        provider_module(ReqLlmNext.Providers.Venice)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Venice)
      end
    end
  end

  families do
    family :venice_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("Venice chat-completions family")

      match do
        provider_ids([:venice])
      end

      stack do
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.VeniceChat)
      end
    end
  end
end
