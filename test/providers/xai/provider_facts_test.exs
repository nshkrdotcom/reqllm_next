defmodule ReqLlmNext.ModelProfile.ProviderFacts.XAITest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.XAI
  alias ReqLlmNext.TestModels

  test "extracts Responses-first facts for modern xAI language models" do
    facts = XAI.extract(TestModels.xai())

    assert facts.responses_api? == true
    assert facts.structured_outputs_native? == true
    assert facts.media_api == nil
  end

  test "treats legacy grok-2 models as non-native structured-output models" do
    facts = XAI.extract(TestModels.xai_legacy())

    assert facts.responses_api? == true
    assert facts.structured_outputs_native? == false
  end

  test "extracts image-generation facts for xAI media models" do
    facts = XAI.extract(TestModels.xai_image())

    assert facts.media_api == :images
    assert facts.image_generation_supported? == true
    assert facts.chat_supported? == false
  end
end
