defmodule ReqLlmNext.ModelProfile.ProviderFacts.AlibabaTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Alibaba
  alias ReqLlmNext.TestModels

  test "extracts Alibaba chat facts without responses or native media surfaces" do
    facts = Alibaba.extract(TestModels.alibaba())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == false
    assert facts.media_api == nil
  end
end
