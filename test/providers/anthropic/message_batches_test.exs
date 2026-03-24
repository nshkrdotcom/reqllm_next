defmodule ReqLlmNext.Anthropic.MessageBatchesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic.Client
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

  test "parses batch results jsonl payloads" do
    assert {:ok,
            [
              %{"custom_id" => "req-1", "result" => %{"type" => "succeeded"}},
              %{"custom_id" => "req-2", "result" => %{"type" => "errored"}}
            ]} =
             Client.parse_jsonl("""
             {"custom_id":"req-1","result":{"type":"succeeded"}}
             {"custom_id":"req-2","result":{"type":"errored"}}
             """)
  end
end
