defmodule ReqLlmNext.ModelProfile.ProviderFacts.ZenmuxTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Zenmux
  alias ReqLlmNext.TestModels

  test "extracts Responses-first facts for Zenmux language models" do
    facts = Zenmux.extract(TestModels.zenmux())

    assert facts.responses_api? == true
    assert facts.structured_outputs_native? == true
    assert facts.citations_supported? == true
    assert facts.media_api == nil
  end

  test "honors explicit chat-only metadata overrides" do
    facts = Zenmux.extract(TestModels.zenmux(%{extra: %{api: "chat"}}))

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == true
  end
end
