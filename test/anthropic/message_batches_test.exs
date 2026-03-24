defmodule ReqLlmNext.Anthropic.MessageBatchesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic.MessageBatches
  alias ReqLlmNext.TestModels

  test "builds batch request envelopes from the Anthropic messages wire" do
    assert {:ok, request} =
             MessageBatches.build_request("req-1", TestModels.anthropic(), "Hello",
               max_tokens: 256
             )

    assert request.custom_id == "req-1"
    assert request.params.model == "test-model"
    assert request.params.messages == [%{role: "user", content: "Hello"}]
    refute Map.has_key?(request.params, :stream)
  end
end
