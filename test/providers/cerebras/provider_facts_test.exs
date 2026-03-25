defmodule ReqLlmNext.ModelProfile.ProviderFacts.CerebrasTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Cerebras
  alias ReqLlmNext.TestModels

  test "extracts Cerebras chat facts without responses or native media surfaces" do
    facts = Cerebras.extract(TestModels.cerebras())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == false
    assert facts.media_api == nil
  end
end
