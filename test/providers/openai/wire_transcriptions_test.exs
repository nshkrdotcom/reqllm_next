defmodule ReqLlmNext.OpenAI.WireTranscriptionsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenAITranscriptions

  test "builds multipart transcription requests" do
    {:ok, request} =
      OpenAITranscriptions.build_request(
        ReqLlmNext.Providers.OpenAI,
        TestModels.openai_transcription(),
        {:binary, "audio-bytes", "audio/mpeg"},
        api_key: "test-key",
        language: "en",
        provider_options: [timestamp_granularities: [:segment]]
      )

    assert request.path == "/v1/audio/transcriptions"

    assert Enum.any?(request.headers, fn {key, value} ->
             String.downcase(key) == "content-type" and
               String.contains?(value, "multipart/form-data")
           end)

    body = IO.iodata_to_binary(request.body)
    assert body =~ "name=\"model\""
    assert body =~ "gpt-4o-transcribe"
    assert body =~ "name=\"language\""
    assert body =~ "name=\"timestamp_granularities[]\""
  end

  test "respects explicit transcription response_format options" do
    {:ok, request} =
      OpenAITranscriptions.build_request(
        ReqLlmNext.Providers.OpenAI,
        TestModels.openai_transcription(),
        {:binary, "audio-bytes", "audio/mpeg"},
        api_key: "test-key",
        response_format: :verbose_json
      )

    body = IO.iodata_to_binary(request.body)
    assert body =~ "name=\"response_format\""
    assert body =~ "verbose_json"
  end

  test "decodes verbose transcription JSON" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body:
          Jason.encode!(%{
            "text" => "Hello world",
            "language" => "en",
            "duration" => 1.0,
            "segments" => [%{"text" => "Hello world", "start" => 0.0, "end" => 1.0}]
          })
      }

    {:ok, result} =
      OpenAITranscriptions.decode_response(
        response,
        TestModels.openai_transcription(),
        {:binary, "audio", "audio/mpeg"},
        []
      )

    assert result.text == "Hello world"
    assert result.language == "en"
    assert result.duration_in_seconds == 1.0
    assert [%{text: "Hello world"}] = result.segments
  end

  test "decodes JSON string responses as plain text" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body: Jason.encode!("Hello world")
      }

    {:ok, result} =
      OpenAITranscriptions.decode_response(
        response,
        TestModels.openai_transcription(),
        {:binary, "audio", "audio/mpeg"},
        []
      )

    assert result.text == "Hello world"
  end
end
