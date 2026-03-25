defmodule ReqLlmNext.MediaResultContractsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Speech.Result, as: SpeechResult
  alias ReqLlmNext.Transcription.Result, as: TranscriptionResult

  describe "ReqLlmNext.Transcription.Result" do
    test "builds a Zoi-backed transcription result" do
      result =
        TranscriptionResult.new!(%{
          text: "hello world",
          segments: [%{text: "hello world", start_second: 0.0, end_second: 1.0}],
          language: "en",
          duration_in_seconds: 1.0
        })

      assert result.text == "hello world"
      assert result.language == "en"
      assert is_list(result.segments)
      assert result.provider_meta == %{}
    end
  end

  describe "ReqLlmNext.Speech.Result" do
    test "builds a Zoi-backed speech result" do
      result =
        SpeechResult.new!(%{
          audio: <<0, 1, 2>>,
          media_type: "audio/mpeg",
          format: "mp3"
        })

      assert result.audio == <<0, 1, 2>>
      assert result.media_type == "audio/mpeg"
      assert result.format == "mp3"
      assert result.provider_meta == %{}
    end
  end
end
