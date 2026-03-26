defmodule ReqLlmNext.Wire.ElevenLabsSpeechTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.ElevenLabsSpeech

  test "builds ElevenLabs speech requests with xi-api-key auth and voice settings" do
    {:ok, request} =
      ElevenLabsSpeech.build_request(
        ReqLlmNext.Providers.ElevenLabs,
        TestModels.elevenlabs_speech(),
        "Hello world",
        api_key: "test-key",
        voice: "voice-123",
        language: "es",
        output_format: :pcm,
        provider_options: [stability: 0.4, similarity_boost: 0.8, seed: 7]
      )

    assert request.host == "api.elevenlabs.io"
    assert request.path == "/v1/text-to-speech/voice-123"
    assert request.query == "output_format=pcm_44100"
    assert {"xi-api-key", "test-key"} in request.headers

    body = Jason.decode!(request.body)

    assert body["text"] == "Hello world"
    assert body["model_id"] == "eleven_multilingual_v2"
    assert body["language_code"] == "es"
    assert body["seed"] == 7
    assert body["voice_settings"]["stability"] == 0.4
    assert body["voice_settings"]["similarity_boost"] == 0.8
  end

  test "decodes ElevenLabs speech responses into canonical speech results" do
    assert {:ok, result} =
             ElevenLabsSpeech.decode_response(
               %Finch.Response{
                 status: 200,
                 body: <<0, 1, 2>>,
                 headers: [{"content-type", "audio/pcm"}, {"request-id", "req-123"}]
               },
               TestModels.elevenlabs_speech(),
               "Hello",
               output_format: :pcm
             )

    assert result.audio == <<0, 1, 2>>
    assert result.media_type == "audio/pcm"
    assert result.format == "pcm"
    assert result.provider_meta == %{request_id: "req-123"}
  end
end
