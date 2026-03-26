defmodule ReqLlmNext.Extensions.Definitions.ElevenLabs do
  @moduledoc """
  ElevenLabs provider declarations.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :elevenlabs do
      default_family(:elevenlabs_speech)
      description("ElevenLabs provider for speech generation and transcription")

      register do
        provider_module(ReqLlmNext.Providers.ElevenLabs)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.ElevenLabs)
      end
    end
  end

  families do
    family :elevenlabs_speech do
      priority(225)
      description("ElevenLabs text-to-speech family")

      match do
        provider_ids([:elevenlabs])
        facts(media_api: :speech)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.ElevenLabsMedia)

        surface_preparation_modules(
          elevenlabs_speech: ReqLlmNext.SurfacePreparation.ElevenLabsSpeech
        )

        semantic_protocol_modules(elevenlabs_speech: nil)

        wire_modules(elevenlabs_speech_json: ReqLlmNext.Wire.ElevenLabsSpeech)
      end
    end

    family :elevenlabs_transcriptions do
      priority(250)
      description("ElevenLabs speech-to-text family")

      match do
        provider_ids([:elevenlabs])
        facts(media_api: :transcription)
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.ElevenLabsMedia)

        surface_preparation_modules(
          elevenlabs_transcription: ReqLlmNext.SurfacePreparation.ElevenLabsTranscriptions
        )

        semantic_protocol_modules(elevenlabs_transcription: nil)

        wire_modules(elevenlabs_transcription_multipart: ReqLlmNext.Wire.ElevenLabsTranscriptions)
      end
    end
  end
end
