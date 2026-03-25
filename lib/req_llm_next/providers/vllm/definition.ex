defmodule ReqLlmNext.Extensions.Definitions.VLLM do
  @moduledoc """
  vLLM provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :vllm do
      default_family(:openai_chat_compatible)
      description("vLLM self-hosted provider using the shared OpenAI-compatible happy path")

      register do
        provider_module(ReqLlmNext.Providers.VLLM)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.VLLM)
      end
    end
  end
end
