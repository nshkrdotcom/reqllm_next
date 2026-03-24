defmodule ReqLlmNext.AdaptersTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Adapters.OpenAI.Reasoning
  alias ReqLlmNext.Adapters.Pipeline

  describe "Pipeline.adapters_for/1" do
    test "returns no adapter for gpt-4o-mini" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      assert Pipeline.adapters_for(model) == []
    end

    test "finds reasoning adapter for reasoning models" do
      {:ok, model} = LLMDB.model("openai:o4-mini")
      assert Reasoning in Pipeline.adapters_for(model)
    end

    test "finds thinking adapter for anthropic models" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      assert ReqLlmNext.Adapters.Anthropic.Thinking in Pipeline.adapters_for(model)
    end
  end

  describe "Pipeline.apply/2" do
    test "passes gpt-4o-mini opts through unchanged" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      opts = [max_tokens: 100]

      assert Pipeline.apply(model, opts) == opts
    end

    test "applies reasoning adapter transforms" do
      {:ok, model} = LLMDB.model("openai:o4-mini")
      opts = [max_tokens: 100, temperature: 0.5]

      result = Pipeline.apply(model, opts)

      assert result[:max_completion_tokens] == 100
      refute Keyword.has_key?(result, :max_tokens)
      refute Keyword.has_key?(result, :temperature)
      assert result[:_adapter_applied] == Reasoning
    end
  end
end
