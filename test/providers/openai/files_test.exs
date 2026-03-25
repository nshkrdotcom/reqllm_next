defmodule ReqLlmNext.OpenAI.FilesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Client
  alias ReqLlmNext.OpenAI.Files

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
end
