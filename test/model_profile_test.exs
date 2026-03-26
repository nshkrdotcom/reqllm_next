defmodule ReqLlmNext.ModelProfileTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile

  test "uses extension-backed surface catalogs for anthropic models" do
    {:ok, model} = LLMDB.model("anthropic:claude-haiku-4-5")
    {:ok, profile} = ModelProfile.from_model(model)

    assert profile.family == :anthropic_messages
    assert [%{id: :anthropic_messages_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses extension-backed rule overrides for openai responses models" do
    {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
    {:ok, profile} = ModelProfile.from_model(model)

    assert profile.family == :openai_responses_compatible

    assert [%{id: :openai_responses_text_http_sse}, %{id: :openai_responses_text_websocket}] =
             ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific deepseek family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.deepseek())

    assert profile.family == :deepseek_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific Google family with native generateContent surfaces" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.google())

    assert profile.family == :google_generate_content

    assert [%{id: :google_generate_content_text_http_sse}] =
             ModelProfile.surfaces_for(profile, :text)

    assert [%{id: :google_generate_content_object_http_sse}] =
             ModelProfile.surfaces_for(profile, :object)
  end

  test "uses provider-specific ElevenLabs family for speech models" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.elevenlabs_speech())

    assert profile.family == :elevenlabs_speech
    assert [%{id: :elevenlabs_speech_http}] = ModelProfile.surfaces_for(profile, :speech)
  end

  test "uses provider-specific ElevenLabs family for transcription models" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.elevenlabs_transcription())

    assert profile.family == :elevenlabs_transcriptions

    assert [%{id: :elevenlabs_transcription_http}] =
             ModelProfile.surfaces_for(profile, :transcription)
  end

  test "uses provider-specific Cohere family with native chat surfaces" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.cohere())

    assert profile.family == :cohere_chat
    assert [%{id: :cohere_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
    assert [%{id: :cohere_chat_object_http_sse}] = ModelProfile.surfaces_for(profile, :object)
  end

  test "uses provider-specific groq family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.groq())

    assert profile.family == :groq_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific openrouter family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.openrouter())

    assert profile.family == :openrouter_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses the shared openai-compatible family for vLLM provider defaults" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.vllm())

    assert profile.family == :openai_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific xai responses family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.xai())

    assert profile.family == :xai_responses_compatible
    assert [%{id: :xai_responses_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific venice family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.venice())

    assert profile.family == :venice_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific alibaba family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.alibaba())

    assert profile.family == :alibaba_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific cerebras family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.cerebras())

    assert profile.family == :cerebras_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific Z.AI family over the shared openai-compatible base" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.zai())

    assert profile.family == :zai_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "uses provider-specific Zenmux responses family by default" do
    {:ok, profile} = ModelProfile.from_model(ReqLlmNext.TestModels.zenmux())

    assert profile.family == :zenmux_responses_compatible
    assert [%{id: :zenmux_responses_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end

  test "falls back to the global openai-compatible family for unregistered providers" do
    model =
      LLMDB.Model.new!(%{
        id: "router-model",
        provider: :router,
        name: "OpenRouter Chat",
        capabilities: %{chat: true},
        extra: %{}
      })

    {:ok, profile} = ModelProfile.from_model(model)

    assert profile.family == :openai_chat_compatible
    assert [%{id: :openai_chat_text_http_sse}] = ModelProfile.surfaces_for(profile, :text)
  end
end
