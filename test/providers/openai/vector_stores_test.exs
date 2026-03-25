defmodule ReqLlmNext.OpenAI.VectorStoresTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.VectorStores
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

  test "builds create bodies for vector stores" do
    body =
      VectorStores.build_create_body(
        name: "docs",
        file_ids: ["file_1", "file_2"],
        metadata: %{team: "docs"}
      )

    assert body.name == "docs"
    assert body.file_ids == ["file_1", "file_2"]
    assert body.metadata == %{team: "docs"}
  end

  test "builds update bodies for vector stores" do
    body =
      VectorStores.build_update_body(
        name: "updated",
        metadata: %{scope: "public"}
      )

    assert body.name == "updated"
    assert body.metadata == %{scope: "public"}
  end

  test "builds query paths for list endpoints" do
    path = VectorStores.build_query_path("/v1/vector_stores", limit: 20, order: "desc")

    assert path =~ "/v1/vector_stores?"
    assert path =~ "limit=20"
    assert path =~ "order=desc"
  end

  test "attaches files to vector stores through the utility client" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request -> OpenAIUtilityHarness.json_response(200, %{"id" => "vsfile_123", "status" => "completed"}) end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "vsfile_123", "status" => "completed"}} =
             VectorStores.attach_file(
               "vs_123",
               "file_123",
               attributes: %{scope: "docs"},
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 1, request}
    assert request.request_line == "POST /v1/vector_stores/vs_123/files HTTP/1.1"

    body = Jason.decode!(request.body)

    assert body == %{"file_id" => "file_123", "attributes" => %{"scope" => "docs"}}
  end
end
