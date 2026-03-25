defmodule ReqLlmNext.Extensions.Definitions.ZAI do
  @moduledoc """
  Z.AI provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :zai do
      default_family(:zai_chat_compatible)
      description("Z.AI provider using the OpenAI-compatible family with thinking deltas")

      register do
        provider_module(ReqLlmNext.Providers.ZAI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.ZAI)
      end
    end
  end

  families do
    family :zai_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("Z.AI chat-completions family")

      match do
        provider_ids([:zai])
      end

      stack do
        surface_preparation_modules(openai_chat: ReqLlmNext.SurfacePreparation.ZAIChat)
        semantic_protocol_modules(openai_chat: ReqLlmNext.SemanticProtocols.ZAIChat)
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.ZAIChat)
      end
    end
  end
end
