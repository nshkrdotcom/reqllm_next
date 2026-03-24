defmodule ReqLlmNext.SupportMatrixTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Scenarios, SupportMatrix}

  test "coverage entries resolve to real models and supported scenarios" do
    for entry <-
          SupportMatrix.entries(:anthropic, :coverage) ++
            SupportMatrix.entries(:openai, :coverage) do
      {:ok, model} = LLMDB.model(entry.spec)
      supported_ids = Enum.map(Scenarios.for_model(model), & &1.id())

      assert entry.scenarios != []
      assert Enum.all?(entry.scenarios, &(&1 in supported_ids))
    end
  end

  test "websocket entries only target OpenAI responses models" do
    for entry <- SupportMatrix.entries(:openai, :websocket) do
      {:ok, model} = LLMDB.model(entry.spec)

      assert entry.opts[:transport] == :websocket
      assert entry.opts[:fixture_suffix] == "websocket"
      assert ReqLlmNext.Wire.Resolver.responses_api?(model)
    end
  end
end
