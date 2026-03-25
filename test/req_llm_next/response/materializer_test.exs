defmodule ReqLlmNext.Response.MaterializerTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response.Materializer

  describe "struct definition (Zoi)" do
    test "schema/0 returns Zoi schema" do
      assert is_struct(Materializer.schema())
    end

    test "new!/1 provides default values" do
      materialized = Materializer.new!(%{})

      assert materialized.output_items == []
      assert materialized.tool_acc == %{}
      assert materialized.usage == nil
      assert materialized.meta == %{}
    end

    test "new!/1 accepts explicit attrs" do
      materialized =
        Materializer.new!(%{
          output_items: [],
          tool_acc: %{0 => %{index: 0}},
          usage: %{total_tokens: 1},
          meta: %{finish_reason: :stop}
        })

      assert materialized.tool_acc == %{0 => %{index: 0}}
      assert materialized.usage == %{total_tokens: 1}
      assert materialized.meta == %{finish_reason: :stop}
    end
  end

  test "collect/1 materializes canonical output items across text, audio, transcript, provider items, and tools" do
    stream = [
      "Hello",
      {:thinking, " world"},
      {:audio, "YmFzZTY0"},
      {:transcript, "spoken"},
      {:provider_item, %{type: "web_search_call"}},
      {:tool_call_start, %{index: 0, id: "call_1", name: "get_weather"}},
      {:tool_call_delta, %{index: 0, function: %{"arguments" => "{\"city\":\"Austin\"}"}}},
      {:meta, %{finish_reason: :stop}}
    ]

    {:ok, materialized} = Materializer.collect(stream)

    assert Materializer.text(materialized) == "Hello"
    assert Materializer.thinking(materialized) == " world"
    assert Enum.any?(materialized.output_items, &(&1.type == :audio))
    assert Enum.any?(materialized.output_items, &(&1.type == :transcript))
    assert Enum.any?(materialized.output_items, &(&1.type == :provider_item))
    assert Enum.any?(materialized.output_items, &(&1.type == :tool_call))
    assert Materializer.finish_reason(materialized) == :stop
    assert length(Materializer.tool_calls(materialized)) == 1
  end
end
