defmodule ReqLlmNext.Wire.ResolverTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Error, Providers}
  alias ReqLlmNext.TestModels

  alias ReqLlmNext.Wire.{
    Anthropic,
    DeepSeekChat,
    GroqChat,
    OpenAIChat,
    OpenAIEmbeddings,
    OpenAIImages,
    OpenAISpeech,
    OpenRouterChat,
    OpenAITranscriptions,
    Resolver
  }

  describe "resolve!/1" do
    test "returns provider and wire module for OpenAI model" do
      model = TestModels.openai()
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end

    test "returns provider and wire module for Anthropic model" do
      model = TestModels.anthropic()
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.Anthropic
      assert result.wire_mod == Anthropic
    end
  end

  describe "provider_module!/1" do
    test "returns OpenAI provider for OpenAI model" do
      model = TestModels.openai()
      assert Resolver.provider_module!(model) == Providers.OpenAI
    end

    test "returns Anthropic provider for Anthropic model" do
      model = TestModels.anthropic()
      assert Resolver.provider_module!(model) == Providers.Anthropic
    end

    test "raises for unknown provider" do
      model = TestModels.minimal(%{provider: :unknown_provider})

      assert_raise ArgumentError, ~r/provider module/, fn ->
        Resolver.provider_module!(model)
      end
    end
  end

  describe "wire_module!/1" do
    test "infers OpenAIChat for openai provider" do
      model = TestModels.openai()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for groq provider" do
      model = TestModels.groq()
      assert Resolver.wire_module!(model) == GroqChat
    end

    test "infers OpenAIChat for openrouter provider" do
      model = TestModels.openrouter()
      assert Resolver.wire_module!(model) == OpenRouterChat
    end

    test "infers OpenAIChat for xai provider" do
      model = TestModels.xai()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for vllm provider" do
      model = TestModels.vllm()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers DeepSeekChat for deepseek provider" do
      model = TestModels.deepseek()
      assert Resolver.wire_module!(model) == DeepSeekChat
    end

    test "infers Anthropic for anthropic provider" do
      model = TestModels.anthropic()
      assert Resolver.wire_module!(model) == Anthropic
    end

    test "infers OpenAIImages for image-generation models" do
      model = TestModels.openai_image()
      assert Resolver.wire_module!(model) == OpenAIImages
    end

    test "infers OpenAITranscriptions for transcription models" do
      model = TestModels.openai_transcription()
      assert Resolver.wire_module!(model) == OpenAITranscriptions
    end

    test "infers OpenAISpeech for speech-generation models" do
      model = TestModels.openai_speech()
      assert Resolver.wire_module!(model) == OpenAISpeech
    end

    test "defaults to OpenAIChat for unknown provider" do
      model = TestModels.minimal(%{provider: :some_other})
      assert Resolver.wire_module!(model) == OpenAIChat
    end
  end

  describe "resolve!/2 with :embed operation" do
    test "returns OpenAI embeddings wire for OpenAI embedding model" do
      model = TestModels.openai_embedding()
      result = Resolver.resolve!(model, :embed)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIEmbeddings
    end

    test "raises for unsupported provider" do
      model = TestModels.anthropic()

      assert_raise Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        Resolver.resolve!(model, :embed)
      end
    end

    test "resolve!/2 with non-embed operation delegates to resolve!/1" do
      model = TestModels.openai()
      result = Resolver.resolve!(model, :text)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end

    test "returns OpenAI images wire for image models" do
      model = TestModels.openai_image()
      result = Resolver.resolve!(model, :image)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIImages
    end

    test "returns OpenAI transcription wire for transcription models" do
      model = TestModels.openai_transcription()
      result = Resolver.resolve!(model, :transcription)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAITranscriptions
    end

    test "returns OpenAI speech wire for speech models" do
      model = TestModels.openai_speech()
      result = Resolver.resolve!(model, :speech)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAISpeech
    end
  end
end
