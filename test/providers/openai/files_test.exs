defmodule ReqLlmNext.OpenAI.FilesTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.Client
  alias ReqLlmNext.OpenAI.Files
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

  test "infers content types for common OpenAI file uploads" do
    assert Files.content_type_for("input.jsonl") == "application/jsonl"
    assert Files.content_type_for("report.pdf") == "application/pdf"
    assert Files.content_type_for("audio.mp3") == "audio/mpeg"
    assert Files.content_type_for("image.webp") == "image/webp"
  end

  test "builds multipart upload bodies with purpose and file parts" do
    {boundary, body} =
      Client.build_multipart_body([
        {:field, "purpose", "assistants"},
        {:file, "file", "batch.jsonl", "application/jsonl", "{\"custom_id\":\"req-1\"}\n"}
      ])

    payload = IO.iodata_to_binary(body)

    assert boundary =~ "reqllmnext_"
    assert payload =~ "name=\"purpose\""
    assert payload =~ "assistants"
    assert payload =~ "filename=\"batch.jsonl\""
    assert payload =~ "application/jsonl"
  end

  test "uploads multipart files and lists with query params" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request -> OpenAIUtilityHarness.json_response(200, %{"id" => "file_123"}) end,
        fn _request -> OpenAIUtilityHarness.json_response(200, %{"data" => []}) end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "file_123"}} =
             Files.upload_binary(
               ~s({"custom_id":"req-1"}) <> "\n",
               filename: "batch.jsonl",
               purpose: "batch",
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 1, upload_request}
    assert upload_request.request_line == "POST /v1/files HTTP/1.1"
    assert upload_request.headers["authorization"] == "Bearer test-key"
    assert upload_request.headers["content-type"] =~ "multipart/form-data; boundary="
    assert upload_request.body =~ "name=\"purpose\""
    assert upload_request.body =~ "batch"
    assert upload_request.body =~ "filename=\"batch.jsonl\""

    assert {:ok, %{"data" => []}} =
             Files.list(
               limit: 10,
               purpose: "batch",
               base_url: server.base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, 2, list_request}
    assert list_request.request_line == "GET /v1/files?limit=10&purpose=batch HTTP/1.1"
  end
end
