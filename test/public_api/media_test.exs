defmodule ReqLlmNext.PublicAPI.MediaTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error
  alias ReqLlmNext.Response

  describe "generate_image/3" do
    test "replays OpenAI image generation through the public API" do
      assert {:ok, response} =
               ReqLlmNext.generate_image(
                 "openai:gpt-image-1",
                 "A paper kite floating over a lake",
                 fixture: "generate_image_basic"
               )

      assert %ReqLlmNext.Response{} = response
      assert Response.image_data(response) == <<1, 2, 3>>
      assert Response.image_url(response) == nil
      assert length(Response.images(response)) == 1
      assert Response.text(response) == ""
    end

    test "returns a structured capability error when the model does not support image generation" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.generate_image("openai:gpt-4o-mini", "Draw a kite")

      assert Exception.message(error) =~ "does not support image"
    end

    test "bang form raises the same structured error" do
      assert_raise Error.Invalid.Capability, fn ->
        ReqLlmNext.generate_image!("openai:gpt-4o-mini", "Draw a kite")
      end
    end

    test "anthropic models reject image generation explicitly" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.generate_image("anthropic:claude-sonnet-4-6", "Draw a kite")

      assert Exception.message(error) =~ "does not support image"
    end
  end

  describe "transcribe/3" do
    test "replays OpenAI transcription through the public API" do
      assert {:ok, result} =
               ReqLlmNext.transcribe(
                 "openai:gpt-4o-transcribe",
                 {:binary, "fake audio", "audio/mpeg"},
                 fixture: "transcribe_basic"
               )

      assert result.text == "Hello world"
      assert result.language == "en"
      assert result.duration_in_seconds == 1.0
      assert [%{text: "Hello world"}] = result.segments
    end

    test "returns a structured capability error when the model does not support transcription" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.transcribe("openai:gpt-4o-mini", {:binary, "audio", "audio/mpeg"})

      assert Exception.message(error) =~ "does not support transcription"
    end

    test "bang form raises the same structured error" do
      assert_raise Error.Invalid.Capability, fn ->
        ReqLlmNext.transcribe!("openai:gpt-4o-mini", {:binary, "audio", "audio/mpeg"})
      end
    end

    test "anthropic models reject transcription explicitly" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.transcribe(
                 "anthropic:claude-sonnet-4-6",
                 {:binary, "audio", "audio/mpeg"}
               )

      assert Exception.message(error) =~ "does not support transcription"
    end
  end

  describe "speak/3" do
    test "replays OpenAI speech generation through the public API" do
      assert {:ok, result} =
               ReqLlmNext.speak(
                 "openai:gpt-4o-mini-tts",
                 "Hello from ReqLlmNext",
                 fixture: "speak_basic",
                 voice: "alloy"
               )

      assert result.audio == <<0, 1, 2, 3>>
      assert result.media_type == "audio/mpeg"
      assert result.format == "mp3"
    end

    test "returns a structured capability error when the model does not support speech generation" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.speak("openai:gpt-4o-mini", "Hello")

      assert Exception.message(error) =~ "does not support speech"
    end

    test "bang form raises the same structured error" do
      assert_raise Error.Invalid.Capability, fn ->
        ReqLlmNext.speak!("openai:gpt-4o-mini", "Hello")
      end
    end

    test "anthropic models reject speech generation explicitly" do
      assert {:error, %Error.Invalid.Capability{} = error} =
               ReqLlmNext.speak("anthropic:claude-sonnet-4-6", "Hello")

      assert Exception.message(error) =~ "does not support speech"
    end
  end
end
