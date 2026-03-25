defmodule ReqLlmNext.Response.MaterializerTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response.Materializer

  describe "struct definition (Zoi)" do
    test "schema/0 returns Zoi schema" do
      assert is_struct(Materializer.schema())
    end

    test "new!/1 provides default values" do
      materialized = Materializer.new!(%{})

      assert materialized.content_parts == []
      assert materialized.tool_acc == %{}
      assert materialized.provider_items == []
      assert materialized.usage == nil
      assert materialized.meta == %{}
    end

    test "new!/1 accepts explicit attrs" do
      materialized =
        Materializer.new!(%{
          content_parts: [],
          tool_acc: %{0 => %{index: 0}},
          provider_items: [%{type: "web_search_call"}],
          usage: %{total_tokens: 1},
          meta: %{finish_reason: :stop}
        })

      assert materialized.tool_acc == %{0 => %{index: 0}}
      assert materialized.provider_items == [%{type: "web_search_call"}]
      assert materialized.usage == %{total_tokens: 1}
      assert materialized.meta == %{finish_reason: :stop}
    end
  end
end
