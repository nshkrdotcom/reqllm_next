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
