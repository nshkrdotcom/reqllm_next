defmodule ReqLlmNext.ModelProfile.ProviderFacts.VeniceTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Venice
  alias ReqLlmNext.TestModels

  test "extracts Venice chat facts without responses or native media surfaces" do
    facts = Venice.extract(TestModels.venice())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == false
    assert facts.media_api == nil
  end
end
