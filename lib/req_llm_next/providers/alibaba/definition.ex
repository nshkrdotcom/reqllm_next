defmodule ReqLlmNext.Extensions.Definitions.Alibaba do
  @moduledoc """
  Alibaba DashScope provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :alibaba do
      default_family(:alibaba_chat_compatible)
      description("Alibaba DashScope provider using the OpenAI-compatible family")

      register do
        provider_module(ReqLlmNext.Providers.Alibaba)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Alibaba)
      end
    end
  end

  families do
    family :alibaba_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("Alibaba DashScope chat-completions family")

      match do
        provider_ids([:alibaba])
      end

      stack do
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.AlibabaChat)
      end
    end
  end
end
