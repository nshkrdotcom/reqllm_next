defmodule ReqLlmNext.ModelProfile.ProviderFacts.OpenAITest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelProfile.ProviderFacts.OpenAI
  alias ReqLlmNext.TestModels

  describe "extract/1" do
    test "treats attachment-capable models as supporting document inputs" do
      model = TestModels.openai(%{extra: %{attachment: true}})

      assert %{additional_document_input?: true} = OpenAI.extract(model)
    end

    test "does not claim document inputs when attachment support is absent" do
      model = TestModels.openai(%{extra: %{attachment: false}})

      assert %{additional_document_input?: false} = OpenAI.extract(model)
    end
  end
end
