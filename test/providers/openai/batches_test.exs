defmodule ReqLlmNext.OpenAI.BatchesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Batches
  alias ReqLlmNext.OpenAI.Client

  test "builds JSONL batch input payloads" do
    payload =
      Batches.build_input_jsonl([
        %{
          custom_id: "req-1",
          method: "POST",
          url: "/v1/responses",
          body: %{model: "gpt-4.1-mini"}
        },
        %{
          custom_id: "req-2",
          method: "POST",
          url: "/v1/responses",
          body: %{model: "gpt-4.1-mini"}
        }
      ])

    assert String.ends_with?(payload, "\n")
    assert payload =~ "\"custom_id\":\"req-1\""
    assert payload =~ "\"custom_id\":\"req-2\""
  end

  test "parses JSONL batch results" do
    assert {:ok, [%{"custom_id" => "req-1"}, %{"custom_id" => "req-2"}]} =
             Client.parse_jsonl("""
             {"custom_id":"req-1","response":{"status_code":200}}
             {"custom_id":"req-2","response":{"status_code":500}}
             """)
  end
end
