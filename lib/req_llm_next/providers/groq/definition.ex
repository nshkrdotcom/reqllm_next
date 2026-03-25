defmodule ReqLlmNext.Extensions.Definitions.Groq do
  @moduledoc """
  Groq provider declarations layered on top of the OpenAI-compatible family.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :groq do
      default_family(:groq_chat_compatible)
      description("Groq provider using the OpenAI-compatible family with narrow overrides")

      register do
        provider_module(ReqLlmNext.Providers.Groq)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.Groq)
      end
    end
  end

  families do
    family :groq_chat_compatible do
      extends(:openai_chat_compatible)
      priority(150)
      description("Groq chat-completions family")

      match do
        provider_ids([:groq])
      end

      stack do
        wire_modules(openai_chat_sse_json: ReqLlmNext.Wire.GroqChat)
      end
    end

    family :groq_transcriptions do
      extends(:groq_chat_compatible)
      priority(250)
      description("Groq Audio Transcriptions family")

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
  end
end
