defmodule ReqLlmNext.Providers.Cohere.ProviderFactsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Cohere
  alias ReqLlmNext.TestModels

  test "extracts native chat and structured-output facts" do
    facts = Cohere.extract(TestModels.cohere())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == true
    assert facts.context_management_supported? == false
    assert facts.media_api == nil
  end
end
