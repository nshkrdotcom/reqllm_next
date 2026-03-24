defmodule ReqLlmNext.Anthropic.FilesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic.Client
  alias ReqLlmNext.Anthropic.Files

  test "infers content types from filenames" do
    assert Files.content_type_for("report.pdf") == "application/pdf"
    assert Files.content_type_for("data.csv") == "text/csv"
    assert Files.content_type_for("notes.txt") == "text/plain"
    assert Files.content_type_for("archive.bin") == "application/octet-stream"
  end

  test "builds multipart bodies for uploads" do
    {boundary, body} =
      Client.build_multipart_body([
        {:file, "file", "report.pdf", "application/pdf", "pdf-bytes"}
      ])

    payload = IO.iodata_to_binary(body)

    assert boundary =~ "reqllmnext_"
    assert payload =~ "Content-Disposition: form-data; name=\"file\"; filename=\"report.pdf\""
    assert payload =~ "Content-Type: application/pdf"
    assert payload =~ "pdf-bytes"
  end

  test "supports richer content type inference for common file formats" do
    assert Files.content_type_for("notes.md") == "text/markdown"
    assert Files.content_type_for("data.json") == "application/json"

    assert Files.content_type_for("sheet.xlsx") ==
             "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    assert Files.content_type_for("diagram.xml") == "application/xml"
    assert Files.content_type_for("image.webp") == "image/webp"
  end
end
