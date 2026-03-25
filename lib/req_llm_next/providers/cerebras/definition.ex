defmodule ReqLlmNext.Extensions.Definitions.Cerebras do
  @moduledoc """
  Cerebras provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :cerebras do
      default_family(:cerebras_chat_compatible)
      description("Cerebras provider using the OpenAI-compatible family with tool-schema deltas")

      register do
        provider_module(ReqLlmNext.Providers.Cerebras)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Cerebras)
      end
    end
  end

  families do
    family :cerebras_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("Cerebras chat-completions family")

      match do
        provider_ids([:cerebras])
      end

      stack do
        surface_preparation_modules(openai_chat: ReqLlmNext.SurfacePreparation.CerebrasChat)
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.CerebrasChat)
      end
    end
  end
end
