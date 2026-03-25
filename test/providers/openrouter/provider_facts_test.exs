defmodule ReqLlmNext.ModelProfile.ProviderFacts.OpenRouterTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.OpenRouter
  alias ReqLlmNext.TestModels

  test "extracts OpenRouter chat facts without responses or native media surfaces" do
    facts = OpenRouter.extract(TestModels.openrouter())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == false
    assert facts.media_api == nil
  end
end
