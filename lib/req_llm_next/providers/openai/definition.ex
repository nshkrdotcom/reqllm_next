defmodule ReqLlmNext.Extensions.Definitions.OpenAI do
  @moduledoc """
  OpenAI provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :openai do
      default_family(:openai_chat_compatible)
      description("OpenAI provider and OpenAI-compatible happy-path family")

      register do
        provider_module(ReqLlmNext.Providers.OpenAI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenAI)

        utility_modules(
          provider_api: ReqLlmNext.OpenAI,
          tools: ReqLlmNext.OpenAI.Tools,
          files: ReqLlmNext.OpenAI.Files,
          vector_stores: ReqLlmNext.OpenAI.VectorStores,
          responses: ReqLlmNext.OpenAI.Responses,
          background: ReqLlmNext.OpenAI.Background,
          batches: ReqLlmNext.OpenAI.Batches,
          moderations: ReqLlmNext.OpenAI.Moderations,
          conversations: ReqLlmNext.OpenAI.Conversations,
          videos: ReqLlmNext.OpenAI.Videos,
          webhooks: ReqLlmNext.OpenAI.Webhooks,
          realtime: ReqLlmNext.Providers.OpenAI.Realtime.Adapter
        )
      end
    end
  end

  families do
    family :openai_images do
      extends(:openai_chat_compatible)
      priority(250)
      description("OpenAI Images API family")

      match do
        facts(media_api: :images)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIMedia)

        surface_preparation_modules(openai_images: ReqLlmNext.SurfacePreparation.OpenAIImages)

        semantic_protocol_modules(openai_images: nil)

        wire_modules(openai_images_json: ReqLlmNext.Wire.OpenAIImages)
      end
    end

    family :openai_transcriptions do
      extends(:openai_chat_compatible)
      priority(250)
      description("OpenAI Audio Transcriptions family")

      match do
        facts(media_api: :transcription)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIMedia)

        surface_preparation_modules(
          openai_transcription: ReqLlmNext.SurfacePreparation.OpenAITranscriptions
        )

        semantic_protocol_modules(openai_transcription: nil)

        wire_modules(openai_transcription_multipart: ReqLlmNext.Wire.OpenAITranscriptions)
      end
    end

    family :openai_speech do
      extends(:openai_chat_compatible)
      priority(250)
      description("OpenAI Audio Speech family")

      match do
        facts(media_api: :speech)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIMedia)

        surface_preparation_modules(openai_speech: ReqLlmNext.SurfacePreparation.OpenAISpeech)

        semantic_protocol_modules(openai_speech: nil)

        wire_modules(openai_speech_json: ReqLlmNext.Wire.OpenAISpeech)
      end
    end

    family :openai_responses_compatible do
      extends(:openai_chat_compatible)
      priority(200)
      description("OpenAI Responses family")

      match do
        facts(responses_api?: true)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAIResponses)

        surface_preparation_modules(
          openai_responses: ReqLlmNext.SurfacePreparation.OpenAIResponses
        )

        session_runtime_modules(openai_responses: ReqLlmNext.SessionRuntimes.OpenAIResponses)

        semantic_protocol_modules(openai_responses: ReqLlmNext.SemanticProtocols.OpenAIResponses)

        wire_modules(
          openai_responses_sse_json: ReqLlmNext.Wire.OpenAIResponses,
          openai_responses_ws_json: ReqLlmNext.Wire.OpenAIResponses
        )

        transport_modules(websocket: ReqLlmNext.Transports.OpenAIResponsesWebSocket)
      end
    end
  end

  rules do
    rule :openai_reasoning_models do
      priority(200)
      description("Apply reasoning-model adapter behavior on OpenAI Responses models")

      match do
        family_ids([:openai_responses_compatible])
        features(reasoning: [supported: true])
      end

      patch do
        adapter_modules([ReqLlmNext.Adapters.OpenAI.Reasoning])
      end
    end
  end
end
