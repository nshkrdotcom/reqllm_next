defmodule ReqLlmNext.OpenAI.WireSpeechTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenAISpeech

  test "encodes speech requests with defaults" do
    body = OpenAISpeech.encode_body(TestModels.openai_speech(), "Hello", [])

    assert body["model"] == "gpt-4o-mini-tts"
    assert body["input"] == "Hello"
    assert body["voice"] == "alloy"
    assert body["response_format"] == "mp3"
  end

  test "build_request prefers normalized prepared text when present" do
    {:ok, request} =
      OpenAISpeech.build_request(
        ReqLlmNext.Providers.OpenAI,
        TestModels.openai_speech(),
        "  Hello  ",
        api_key: "test-key",
        _prepared_text: "Hello"
      )

    body = request.body |> IO.iodata_to_binary() |> Jason.decode!()
    assert body["input"] == "Hello"
  end

  test "decodes binary speech responses" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "audio/mpeg"}],
        body: <<0, 1, 2, 3>>
      }

    {:ok, result} =
      OpenAISpeech.decode_response(response, TestModels.openai_speech(), "Hello",
        output_format: :mp3
      )

    assert result.audio == <<0, 1, 2, 3>>
    assert result.media_type == "audio/mpeg"
    assert result.format == "mp3"
  end
end
