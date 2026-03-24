defmodule ReqLlmNext.Extensions.Definitions.Anthropic do
  @moduledoc """
  Anthropic provider and Anthropic Messages family declarations.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :anthropic do
      default_family(:anthropic_messages)
      description("Anthropic provider and Anthropic Messages family")

      register do
        provider_module(ReqLlmNext.Providers.Anthropic)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Anthropic)

        utility_modules(
          provider_api: ReqLlmNext.Anthropic,
          files: ReqLlmNext.Anthropic.Files,
          token_count: ReqLlmNext.Anthropic.TokenCount,
          message_batches: ReqLlmNext.Anthropic.MessageBatches,
          tools: ReqLlmNext.Anthropic.Tools
        )
      end
    end
  end

  families do
    family :anthropic_messages do
      priority(100)
      description("Anthropic Messages family")

      match do
        provider_ids([:anthropic])
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.AnthropicMessages)

        surface_preparation_modules(
          anthropic_messages: ReqLlmNext.SurfacePreparation.AnthropicMessages
        )

        semantic_protocol_modules(
          anthropic_messages: ReqLlmNext.SemanticProtocols.AnthropicMessages
        )

        wire_modules(anthropic_messages_sse_json: ReqLlmNext.Wire.Anthropic)
        transport_modules(http: nil, http_sse: ReqLlmNext.Transports.HTTPStream)
        adapter_modules([ReqLlmNext.Adapters.Anthropic.Thinking])
      end
    end
  end
end
