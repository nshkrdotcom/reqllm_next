defmodule ReqLlmNext.LiveVerifiers.OpenAITest do
  use ReqLlmNext.TestSupport.LiveVerifierCase, provider: :openai

  alias ReqLlmNext.Response

  @text_model "openai:gpt-4o-mini"
  @image_model "openai:gpt-image-1"
  @speech_model "openai:gpt-4o-mini-tts"
  @transcription_model "openai:gpt-4o-transcribe"

  test "verifies the baseline responses lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_text(
               @text_model,
               "Reply with the single word ready.",
               max_tokens: 32
             )

    assert %Response{} = response
    assert is_binary(Response.text(response))
    assert String.length(Response.text(response)) > 0
  end

  test "verifies image generation through the public media API" do
    assert {:ok, response} =
             ReqLlmNext.generate_image(
               @image_model,
               "A simple black triangle on a white background.",
               size: "1024x1024",
               quality: "low"
             )

    assert %Response{} = response
    assert length(Response.images(response)) > 0
    assert is_binary(Response.image_data(response)) or is_binary(Response.image_url(response))
  end

  test "verifies speech and transcription round-trip through OpenAI media lanes" do
    assert {:ok, speech} =
             ReqLlmNext.speak(
               @speech_model,
               "Hello from Req LLM Next live verifier.",
               voice: "alloy",
               output_format: :wav
             )

    assert is_binary(speech.audio)
    assert byte_size(speech.audio) > 0

    assert {:ok, transcript} =
             ReqLlmNext.transcribe(
               @transcription_model,
               {:binary, speech.audio, speech.media_type},
               language: "en"
             )

    assert is_binary(transcript.text)
    assert String.length(String.trim(transcript.text)) > 0
  end
end
