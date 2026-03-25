defmodule ReqLlmNext.OpenAI.BatchesTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.Batches
  alias ReqLlmNext.OpenAI.Client
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

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

  test "creates batches from request lists through upload plus batch creation" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request -> OpenAIUtilityHarness.json_response(200, %{"id" => "file_123"}) end,
        fn _request ->
          OpenAIUtilityHarness.json_response(200, %{"id" => "batch_123", "status" => "validating"})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "batch_123", "status" => "validating"}} =
             Batches.create(
               [
                 %{
                   custom_id: "req-1",
                   method: "POST",
                   url: "/v1/responses",
                   body: %{model: "gpt-4.1-mini"}
                 }
               ],
               endpoint: "/v1/responses",
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 1, upload_request}
    assert upload_request.request_line == "POST /v1/files HTTP/1.1"
    assert upload_request.body =~ "\"custom_id\":\"req-1\""

    assert_receive {:utility_request, 2, batch_request}
    assert batch_request.request_line == "POST /v1/batches HTTP/1.1"

    body = Jason.decode!(batch_request.body)

    assert body["input_file_id"] == "file_123"
    assert body["endpoint"] == "/v1/responses"
    assert body["completion_window"] == "24h"
  end
end
