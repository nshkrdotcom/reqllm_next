defmodule ReqLlmNext.Extensions.Definitions.OpenAICompatible do
  @moduledoc """
  Default OpenAI-compatible execution family declarations.
  """

  use ReqLlmNext.Extensions.Definition

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

        semantic_protocol_modules(
          openai_chat: ReqLlmNext.SemanticProtocols.OpenAIChat,
          openai_embeddings: nil
        )

        wire_modules(
          openai_chat_sse_json: ReqLlmNext.Wire.OpenAIChat,
          openai_embeddings_json: ReqLlmNext.Wire.OpenAIEmbeddings
        )

        transport_modules(http: nil, http_sse: ReqLlmNext.Transports.HTTPStream)
      end
    end
  end
end
