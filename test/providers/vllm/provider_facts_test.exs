defmodule ReqLlmNext.ModelProfile.ProviderFacts.VLLMTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.VLLM
  alias ReqLlmNext.TestModels

  test "extracts vLLM chat facts without responses or native media surfaces" do
    facts = VLLM.extract(TestModels.vllm())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == false
    assert facts.media_api == nil
  end
end
