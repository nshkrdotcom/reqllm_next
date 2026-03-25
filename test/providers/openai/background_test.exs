defmodule ReqLlmNext.OpenAI.BackgroundTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.Background
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

  test "encodes background responses through the Responses wire" do
    body =
      Background.build_request_body(
        TestModels.openai_reasoning(),
        "Summarize the attached report",
        background: true,
        metadata: %{job: "nightly"},
        service_tier: "flex"
      )

    assert body.background == true
    assert body.metadata == %{job: "nightly"}
    assert body.service_tier == "flex"
    assert body.model == "o1-test"
  end

  test "submits background requests through the responses endpoint" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request ->
          OpenAIUtilityHarness.json_response(200, %{"id" => "resp_bg_123", "status" => "queued"})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "resp_bg_123", "status" => "queued"}} =
             Background.submit(
               TestModels.openai_reasoning(),
               "Summarize the attached report",
               background: true,
               metadata: %{job: "nightly"},
               service_tier: "flex",
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 1, request}
    assert request.request_line == "POST /v1/responses HTTP/1.1"
    assert request.headers["authorization"] == "Bearer test-key"

    body = Jason.decode!(request.body)

    assert body["background"] == true
    assert body["metadata"] == %{"job" => "nightly"}
    assert body["service_tier"] == "flex"
    assert body["input"] != nil
  end
end
