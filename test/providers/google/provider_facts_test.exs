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
end
