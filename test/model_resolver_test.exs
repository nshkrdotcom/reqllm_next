defmodule ReqLlmNext.ModelResolverTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelResolver

  describe "resolve/1" do
    test "resolves string model spec" do
      {:ok, model} = ModelResolver.resolve("openai:gpt-4o-mini")

      assert model.id == "gpt-4o-mini"
      assert model.provider == :openai
    end

    test "resolves anthropic model spec" do
      {:ok, model} = ModelResolver.resolve("anthropic:claude-sonnet-4-20250514")

      assert model.id == "claude-sonnet-4-20250514"
      assert model.provider == :anthropic
    end

    test "passes through LLMDB.Model struct" do
      {:ok, original} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, resolved} = ModelResolver.resolve(original)

      assert resolved == original
    end

    test "passes through handcrafted LLMDB.Model struct" do
      handcrafted =
        LLMDB.Model.new!(%{
          id: "ollama:llama3-local",
          provider: :openai,
          name: "Local Llama 3",
          capabilities: %{chat: true},
          extra: %{
            wire: %{protocol: "openai_chat"}
          }
        })

      assert {:ok, ^handcrafted} = ModelResolver.resolve(handcrafted)
    end

    test "returns error for unknown model" do
      result = ModelResolver.resolve("openai:nonexistent-model-xyz")

      assert {:error, {:model_not_found, "openai:nonexistent-model-xyz", _reason}} = result
    end

    test "returns error for invalid spec format" do
      result = ModelResolver.resolve("invalid-format")

      assert {:error, {:model_not_found, "invalid-format", _reason}} = result
    end

    test "rejects tuple model specs" do
      assert {:error, {:invalid_model_spec, {:openai, "gpt-4o-mini"}}} =
               ModelResolver.resolve({:openai, "gpt-4o-mini"})
    end
  end
end
