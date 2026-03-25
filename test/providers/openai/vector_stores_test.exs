defmodule ReqLlmNext.OpenAI.VectorStoresTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.VectorStores

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
end
