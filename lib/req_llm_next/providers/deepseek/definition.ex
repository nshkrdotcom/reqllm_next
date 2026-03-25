defmodule ReqLlmNext.Extensions.Definitions.DeepSeek do
  @moduledoc """
  DeepSeek provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :deepseek do
      default_family(:deepseek_chat_compatible)

      description(
        "DeepSeek provider using the OpenAI-compatible chat family with narrow overrides"
      )

      register do
        provider_module(ReqLlmNext.Providers.DeepSeek)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.DeepSeek)
      end
    end
  end

  families do
    family :deepseek_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("DeepSeek chat-completions family")

      match do
        provider_ids([:deepseek])
      end

      stack do
        semantic_protocol_modules(openai_chat: ReqLlmNext.SemanticProtocols.DeepSeekChat)
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.DeepSeekChat)
      end
    end
  end
end
