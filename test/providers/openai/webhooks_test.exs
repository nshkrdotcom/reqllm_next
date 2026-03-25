defmodule ReqLlmNext.OpenAI.WebhooksTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Webhooks

  test "parses webhook event payloads" do
    body = ~s({"type":"response.completed","data":{"id":"resp_123"}})

    assert {:ok, event} = Webhooks.parse(body)
    assert Webhooks.event_type(event) == "response.completed"
    assert Webhooks.response_event?(event)
    assert Webhooks.terminal?(event)
    assert Webhooks.resource_id(event) == "resp_123"
    assert Webhooks.category(event) == :response
  end

  test "categorizes batch webhook events" do
    event = %{"type" => "batch.failed", "data" => %{"id" => "batch_123"}}

    assert Webhooks.batch_event?(event)
    assert Webhooks.terminal?(event)
    assert Webhooks.category(event) == :batch
  end
end
