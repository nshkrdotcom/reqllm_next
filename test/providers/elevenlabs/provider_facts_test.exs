defmodule ReqLlmNext.Providers.ElevenLabs.ProviderFactsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.ElevenLabs
  alias ReqLlmNext.TestModels

  test "classifies speech models as speech-only media surfaces" do
    facts = ElevenLabs.extract(TestModels.elevenlabs_speech())

    assert facts.media_api == :speech
    assert facts.speech_supported? == true
    assert facts.transcription_supported? == false
    assert facts.chat_supported? == false
  end

  test "classifies scribe models as transcription-only media surfaces" do
    facts = ElevenLabs.extract(TestModels.elevenlabs_transcription())

    assert facts.media_api == :transcription
    assert facts.speech_supported? == false
    assert facts.transcription_supported? == true
    assert facts.chat_supported? == false
  end
end
