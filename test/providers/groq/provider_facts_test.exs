defmodule ReqLlmNext.ModelProfile.ProviderFacts.GroqTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.Groq
  alias ReqLlmNext.TestModels

  test "extracts Groq chat facts without responses or native media surfaces" do
    facts = Groq.extract(TestModels.groq())

    assert facts.responses_api? == false
    assert facts.structured_outputs_native? == false
    assert facts.media_api == nil
    assert facts.chat_supported? == nil
  end

  test "extracts transcription facts for Groq audio models" do
    facts = Groq.extract(TestModels.groq_transcription())

    assert facts.media_api == :transcription
    assert facts.transcription_supported? == true
    assert facts.chat_supported? == false
  end
end
