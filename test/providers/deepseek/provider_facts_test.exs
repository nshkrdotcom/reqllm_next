defmodule ReqLlmNext.ModelProfile.ProviderFacts.DeepSeekTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.DeepSeek
  alias ReqLlmNext.TestModels

  test "extracts DeepSeek chat facts without media or responses surfaces" do
    facts = DeepSeek.extract(TestModels.deepseek())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == false
    assert facts.media_api == nil
  end
end
