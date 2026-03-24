defmodule ReqLlmNext.Scenarios.EmbeddingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Embedding
  alias ReqLlmNext.TestModels
  import ReqLlmNext.ScenarioTestHelpers

  describe "metadata and applicability" do
    test "reports metadata and embedding support" do
      assert_scenario_metadata(Embedding, :embedding, "Embedding")
      assert Embedding.applies?(embedding_model())
      refute Embedding.applies?(TestModels.openai_embedding())
      refute Embedding.applies?(TestModels.openai())
      refute Embedding.applies?(TestModels.openai_reasoning())
      refute Embedding.applies?(nil)
      refute Embedding.applies?(%{})
      refute Embedding.applies?("not a model")
    end
  end

  describe "embedding shape validation" do
    test "accepts valid 3-element embedding results" do
      assert validate_embeddings_result({:ok, [[0.1], [0.2], [0.3]]}) == :ok
    end

    test "rejects invalid result shapes and API failures" do
      assert validate_embeddings_result({:ok, "not a list"}) == %{
               status: :error,
               error: {:unexpected_embedding_format, "not a list"}
             }

      assert validate_embeddings_result({:ok, [[0.1, 0.2], [0.3, 0.4]]}) == %{
               status: :error,
               error: {:unexpected_embedding_format, [[0.1, 0.2], [0.3, 0.4]]}
             }

      assert validate_embeddings_result({:error, :api_timeout}) == %{
               status: :error,
               error: :api_timeout
             }
    end

    test "checks valid individual embeddings" do
      assert valid_embedding?([0.1, 0.2, 0.3])
      assert valid_embedding?([1, 2, 3])
      assert valid_embedding?([0.0])
      refute valid_embedding?([])
      refute valid_embedding?("string")
      refute valid_embedding?(nil)
      refute valid_embedding?(123)
      refute valid_embedding?([0.1, "string", 0.3])
      refute valid_embedding?([:atom])
    end
  end

  describe "similarity calculations" do
    test "computes expected cosine similarity values" do
      vec = [1.0, 0.0, 0.0]
      assert_in_delta cosine_similarity(vec, vec), 1.0, 0.0001
      assert_in_delta cosine_similarity([1.0, 0.0], [0.0, 1.0]), 0.0, 0.0001
      assert_in_delta cosine_similarity([1.0, 0.0], [-1.0, 0.0]), -1.0, 0.0001
      assert cosine_similarity([0.0, 0.0], [1.0, 1.0]) == 0.0
    end

    test "detects dimension mismatch and similarity ordering" do
      e1 = [0.1, 0.2, 0.3]
      e2 = [0.4, 0.5, 0.6]
      e3 = [0.7, 0.8, 0.9]
      refute length(e1) != length(e2) or length(e1) != length(e3)

      mismatch = length(e1) != length(e2) or length(e1) != length([0.1, 0.2])
      assert mismatch

      similar_1 = [0.9, 0.1, 0.0]
      similar_2 = [0.85, 0.15, 0.0]
      different = [-0.5, 0.5, 0.5]

      sim_12 = cosine_similarity(similar_1, similar_2)
      sim_13 = cosine_similarity(similar_1, different)
      sim_23 = cosine_similarity(similar_2, different)

      assert sim_12 > sim_13 and sim_12 > sim_23

      opposite = cosine_similarity([1.0, 0.0], [-1.0, 0.0])
      nearby = cosine_similarity([1.0, 0.0], [1.0, 0.01])
      refute opposite > nearby and opposite > cosine_similarity([-1.0, 0.0], [1.0, 0.01])
    end
  end

  defp embedding_model do
    TestModels.openai_embedding(%{
      capabilities: %{
        chat: false,
        embeddings: true,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      }
    })
  end
end
