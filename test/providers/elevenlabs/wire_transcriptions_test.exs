defmodule ReqLlmNext.Wire.ElevenLabsTranscriptionsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.ElevenLabsTranscriptions

  test "builds ElevenLabs transcription multipart requests with query and form fields" do
    {:ok, request} =
      ElevenLabsTranscriptions.build_request(
        ReqLlmNext.Providers.ElevenLabs,
        TestModels.elevenlabs_transcription(),
        {:binary, "audio-bytes", "audio/mpeg"},
        api_key: "test-key",
        language: "en",
        provider_options: [
          enable_logging: false,
          diarize: true,
          timestamps_granularity: "word",
          keyterms: ["ReqLlmNext", "ElevenLabs"]
        ]
      )

    assert request.host == "api.elevenlabs.io"
    assert request.path == "/v1/speech-to-text"
    assert request.query == "enable_logging=false"
    assert {"xi-api-key", "test-key"} in request.headers

    body = request.body

    assert body =~ "name=\"model_id\"\r\n\r\nscribe_v2\r\n"
    assert body =~ "name=\"language_code\"\r\n\r\nen\r\n"
    assert body =~ "name=\"diarize\"\r\n\r\ntrue\r\n"
    assert body =~ "name=\"timestamps_granularity\"\r\n\r\nword\r\n"
    assert body =~ "name=\"keyterms\"\r\n\r\nReqLlmNext\r\n"
    assert body =~ "name=\"keyterms\"\r\n\r\nElevenLabs\r\n"
  end

  test "decodes ElevenLabs transcription responses into canonical transcription results" do
    body =
      Jason.encode!(%{
        "text" => "Hello world",
        "language_code" => "en",
        "words" => [
          %{
            "text" => "Hello",
            "start" => 0.0,
            "end" => 0.5,
            "speaker_id" => "speaker_a"
          },
          %{
            "text" => "world",
            "start" => 0.5,
            "end" => 1.0,
            "speaker_id" => "speaker_a"
          }
        ]
      })

    assert {:ok, result} =
             ElevenLabsTranscriptions.decode_response(
               %Finch.Response{status: 200, body: body},
               TestModels.elevenlabs_transcription(),
               {:binary, "audio", "audio/mpeg"},
               []
             )

    assert result.text == "Hello world"
    assert result.language == "en"
    assert result.duration_in_seconds == 1.0

    assert [%{text: "Hello", speaker: "speaker_a"}, %{text: "world", speaker: "speaker_a"}] =
             result.segments
  end
end
