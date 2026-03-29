defmodule ReqLlmNext.Wire.GoogleEmbeddingsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.GoogleEmbeddings

  test "builds single embedding requests against the selected API version" do
    {:ok, request} =
      GoogleEmbeddings.build_request(
        ReqLlmNext.Providers.Google,
        TestModels.google(%{
          id: "gemini-embedding-001",
          capabilities: %{chat: false, embeddings: true},
          modalities: %{input: [:text], output: [:embedding]}
        }),
        "hello",
        api_key: "test-key",
        provider_options: [
          google_api_version: "v1",
          dimensions: 256,
          task_type: "RETRIEVAL_QUERY"
        ]
      )

    assert request.scheme == :https
    assert request.host == "generativelanguage.googleapis.com"
    assert request.path == "/v1/models/gemini-embedding-001:embedContent"

    assert Jason.decode!(request.body) == %{
             "model" => "models/gemini-embedding-001",
             "content" => %{"parts" => [%{"text" => "hello"}]},
             "outputDimensionality" => 256,
             "taskType" => "RETRIEVAL_QUERY"
           }
  end

  test "builds batch embedding requests for list input" do
    {:ok, request} =
      GoogleEmbeddings.build_request(
        ReqLlmNext.Providers.Google,
        TestModels.google(%{
          id: "gemini-embedding-001",
          capabilities: %{chat: false, embeddings: true},
          modalities: %{input: [:text], output: [:embedding]}
        }),
        ["hello", "world"],
        api_key: "test-key"
      )

    assert request.path == "/v1beta/models/gemini-embedding-001:batchEmbedContents"

    assert Jason.decode!(request.body) == %{
             "requests" => [
               %{
                 "model" => "models/gemini-embedding-001",
                 "content" => %{"parts" => [%{"text" => "hello"}]}
               },
               %{
                 "model" => "models/gemini-embedding-001",
                 "content" => %{"parts" => [%{"text" => "world"}]}
               }
             ]
           }
  end

  test "extracts single and batch embeddings from Google responses" do
    assert {:ok, [0.1, 0.2, 0.3]} =
             GoogleEmbeddings.extract_embeddings(
               %{"embedding" => %{"values" => [0.1, 0.2, 0.3]}},
               "hello"
             )

    assert {:ok, [[0.1, 0.2], [0.3, 0.4]]} =
             GoogleEmbeddings.extract_embeddings(
               %{
                 "embeddings" => [
                   %{"values" => [0.1, 0.2]},
                   %{"values" => [0.3, 0.4]}
                 ]
               },
               ["hello", "world"]
             )
  end
end
