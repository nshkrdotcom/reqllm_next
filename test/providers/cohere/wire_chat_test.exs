defmodule ReqLlmNext.Wire.CohereChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Schema
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.CohereChat

  test "encodes Cohere streaming chat requests with native response_format and documents" do
    context =
      Context.new!([
        Context.system("Be concise"),
        Context.user("Return a compact answer")
      ])

    body =
      CohereChat.encode_body(
        TestModels.cohere(),
        context,
        operation: :object,
        compiled_schema: Schema.compile!(name: [type: :string]),
        _structured_output_strategy: :native_json_schema,
        max_tokens: 256,
        temperature: 0.2,
        top_p: 0.7,
        provider_options: [
          documents: [%{"text" => "RAG combines retrieval and generation"}],
          citation_options: %{"mode" => "accurate"},
          safety_mode: "STRICT",
          seed: 7,
          k: 40
        ]
      )

    assert body["model"] == "command-a-03-2025"
    assert body["stream"] == true

    assert body["messages"] == [
             %{"role" => "system", "content" => "Be concise"},
             %{"role" => "user", "content" => "Return a compact answer"}
           ]

    assert body["response_format"]["type"] == "json_object"
    assert is_map(body["response_format"]["json_schema"])
    assert body["documents"] == [%{"text" => "RAG combines retrieval and generation"}]
    assert body["citation_options"] == %{"mode" => "accurate"}
    assert body["safety_mode"] == "STRICT"
    assert body["seed"] == 7
    assert body["k"] == 40
    assert body["p"] == 0.7
  end

  test "decodes JSON SSE payloads" do
    chunks =
      %{
        data:
          Jason.encode!(%{
            "type" => "content-delta",
            "delta" => %{"message" => %{"content" => %{"text" => "Hi"}}}
          })
      }
      |> CohereChat.decode_wire_event()
      |> Enum.flat_map(
        &ReqLlmNext.SemanticProtocols.CohereChat.decode_event(&1, TestModels.cohere())
      )

    assert chunks == ["Hi"]
  end
end
