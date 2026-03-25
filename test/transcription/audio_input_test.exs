defmodule ReqLlmNext.Transcription.AudioInputTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Transcription.AudioInput

  test "resolves binary audio input" do
    assert {:ok, audio} = AudioInput.resolve({:binary, "abc", "audio/mpeg"})
    assert audio.data == "abc"
    assert audio.media_type == "audio/mpeg"
    assert audio.filename == "audio.mp3"
  end

  test "resolves base64 audio input" do
    encoded = Base.encode64("abc")
    assert {:ok, audio} = AudioInput.resolve({:base64, encoded, "audio/mpeg"})
    assert audio.data == "abc"
  end

  test "rejects invalid base64 input" do
    assert {:error, error} = AudioInput.resolve({:base64, "not-base64", "audio/mpeg"})
    assert Exception.message(error) =~ "invalid base64"
  end

  test "reads file paths and infers media type" do
    path = Path.join(System.tmp_dir!(), "reqllm-next-audio-input-test.mp3")
    File.write!(path, "audio-bytes")

    try do
      assert {:ok, audio} = AudioInput.resolve(path)
      assert audio.data == "audio-bytes"
      assert audio.media_type == "audio/mpeg"
      assert audio.filename == "reqllm-next-audio-input-test.mp3"
    after
      File.rm(path)
    end
  end
end
