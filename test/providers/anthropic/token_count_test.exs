defmodule ReqLlmNext.Anthropic.TokenCountTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic.TokenCount
  alias ReqLlmNext.TestModels

  test "builds a count_tokens body from the messages wire without streaming" do
    model = TestModels.anthropic()
    body = TokenCount.build_body(model, "Hello", max_tokens: 128)

    assert body.model == "test-model"
    assert body.messages == [%{role: "user", content: "Hello"}]
    assert body.max_tokens == 128
    refute Map.has_key?(body, :stream)
  end
end
