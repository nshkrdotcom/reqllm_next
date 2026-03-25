defmodule ReqLlmNext.OpenAI.ClientTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.Client
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

  setup do
    test_pid = self()
    handler_id = "req-llm-next-openai-client-test-#{System.unique_integer([:positive])}"

    events = [
      [:req_llm_next, :provider, :request, :start],
      [:req_llm_next, :provider, :request, :stop]
    ]

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_event/4,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  def handle_event(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end

  test "json_request emits provider telemetry and decodes JSON responses" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request ->
          OpenAIUtilityHarness.json_response(200, %{"id" => "batch_123", "status" => "queued"})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "batch_123", "status" => "queued"}} =
             Client.json_request(
               :post,
               "/v1/batches",
               %{hello: "world"},
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 1, request}
    assert request.request_line == "POST /v1/batches HTTP/1.1"
    assert request.headers["authorization"] == "Bearer test-key"
    assert request.headers["content-type"] == "application/json"
    assert Jason.decode!(request.body) == %{"hello" => "world"}

    assert_receive {:telemetry_event, [:req_llm_next, :provider, :request, :start], %{},
                    start_metadata}

    assert start_metadata.provider == :openai
    assert start_metadata.utility_path == "/v1/batches"
    assert start_metadata.http_method == :post

    assert_receive {:telemetry_event, [:req_llm_next, :provider, :request, :stop], measurements,
                    stop_metadata}

    assert is_integer(measurements.duration)
    assert stop_metadata.provider == :openai
    assert stop_metadata.provider_request_status == :ok
    assert stop_metadata.utility_path == "/v1/batches"
  end

  test "download_request preserves binary payloads and content type" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request -> OpenAIUtilityHarness.binary_response(200, "audio/mpeg", <<1, 2, 3, 4>>) end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, response} =
             Client.download_request(
               "/v1/files/file_123/content",
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert response.data == <<1, 2, 3, 4>>
    assert response.content_type == "audio/mpeg"
  end

  test "parse_jsonl returns a structured parse error for invalid lines" do
    assert {:error, error} =
             Client.parse_jsonl("""
             {"custom_id":"req-1"}
             not-json
             """)

    assert Exception.message(error) =~ "Failed to parse OpenAI JSONL response"
  end
end
