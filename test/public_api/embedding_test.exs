defmodule ReqLlmNext.PublicAPI.EmbeddingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error

  describe "embed/3" do
    test "returns an error for an unknown model" do
      result = ReqLlmNext.embed("openai:nonexistent-model", "Hello world", [])

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "returns an error for empty input" do
      assert {:error, %Error.Invalid.Parameter{}} =
               ReqLlmNext.embed("openai:text-embedding-3-small", "", [])
    end
  end

  describe "embed!/3" do
    test "raises on invalid input" do
      assert_raise Error.Invalid.Parameter, fn ->
        ReqLlmNext.embed!("openai:text-embedding-3-small", "", [])
      end
    end

    test "raises for non-embedding models" do
      assert_raise Error.Invalid.Capability, fn ->
        ReqLlmNext.embed!("openai:gpt-4o-mini", "Hello", [])
      end
    end
  end

  describe "cosine_similarity/2" do
    test "returns 1.0 for identical vectors" do
      vec = [1.0, 0.0, 0.0]
      assert ReqLlmNext.cosine_similarity(vec, vec) == 1.0
    end

    test "returns 0.0 for orthogonal vectors" do
      assert ReqLlmNext.cosine_similarity([1.0, 0.0], [0.0, 1.0]) == 0.0
    end
  end

  describe "embedding_models/0" do
    test "returns string model specs" do
      models = ReqLlmNext.embedding_models()

      assert is_list(models)
      assert Enum.all?(models, &is_binary/1)
    end
  end
end
