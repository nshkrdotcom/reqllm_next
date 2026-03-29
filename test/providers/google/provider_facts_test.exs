defmodule ReqLlmNext.ModelProfile.ProviderFacts.GoogleTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Google
  alias ReqLlmNext.TestModels

  test "extracts native Gemini generateContent facts" do
    facts = Google.extract(TestModels.google())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == true
    assert facts.media_api == nil
  end

  test "marks embedding models as non-chat" do
    facts =
      Google.extract(
        TestModels.google(%{
          id: "gemini-embedding-001",
          capabilities: %{chat: false, embeddings: true},
          modalities: %{input: [:text], output: [:embedding]}
        })
      )

    assert facts.chat_supported? == false
    assert facts.media_api == nil
  end

  test "marks image-generation models as image-only media surfaces" do
    facts =
      Google.extract(
        TestModels.google(%{
          id: "gemini-2.5-flash-image",
          capabilities: %{chat: false, embeddings: false},
          modalities: %{input: [:text, :image], output: [:text, :image]}
        })
      )

    assert facts.image_generation_supported? == true
    assert facts.media_api == :images
    assert facts.chat_supported? == false
  end

  test "marks obviously non-chat Google model families as unsupported for chat" do
    facts =
      Google.extract(%LLMDB.Model{
        id: "veo-3.0-generate-preview",
        provider: :google,
        capabilities: nil,
        modalities: nil
      })

    assert facts.chat_supported? == false
  end
end
