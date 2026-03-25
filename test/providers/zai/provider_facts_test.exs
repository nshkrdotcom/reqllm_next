defmodule ReqLlmNext.ModelProfile.ProviderFacts.ZAITest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.ZAI
  alias ReqLlmNext.TestModels

  test "extracts Z.AI chat facts without responses or native media surfaces" do
    facts = ZAI.extract(TestModels.zai())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == false
    assert facts.media_api == nil
  end
end
