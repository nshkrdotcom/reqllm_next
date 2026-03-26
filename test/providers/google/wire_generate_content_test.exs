defmodule ReqLlmNext.Wire.GoogleGenerateContentTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.Wire.GoogleGenerateContent

  test "builds Google generateContent request bodies with native tools and schema" do
    tool =
      Tool.new!(
        name: "lookup_weather",
        description: "Look up weather",
        parameter_schema: [location: [type: :string, required: true]],
        callback: fn _args -> {:ok, %{}} end
      )

    schema = ReqLlmNext.Schema.compile!(name: [type: :string])

    context =
      Context.new!([
        Context.system("Be concise"),
        Context.user([ContentPart.text("Describe the weather")])
      ])

    body =
      GoogleGenerateContent.encode_body(
        TestModels.google(%{id: "gemini-2.5-flash"}),
        context,
        operation: :object,
        compiled_schema: schema,
        _structured_output_strategy: :native_json_schema,
        tools: [tool],
        tool_choice: %{type: "tool", name: "lookup_weather"},
        max_tokens: 256,
        temperature: 0.4,
        top_p: 0.9,
        provider_options: [
          google_candidate_count: 2,
          google_grounding: %{enable: true},
          google_thinking_budget: 512,
          cached_content: "cachedContents/abc123"
        ]
      )

    assert body.systemInstruction == %{parts: [%{text: "Be concise"}]}
    assert [%{role: "user", parts: [%{text: "Describe the weather"}]}] = body.contents
    assert body.cachedContent == "cachedContents/abc123"
    assert body.generationConfig.maxOutputTokens == 256
    assert body.generationConfig.temperature == 0.4
    assert body.generationConfig.topP == 0.9
    assert body.generationConfig.candidateCount == 2
    assert body.generationConfig.responseMimeType == "application/json"
    assert is_map(body.generationConfig.responseJsonSchema)
    assert [%{"googleSearch" => %{}} | _rest] = body.tools

    assert body.toolConfig == %{
             "functionCallingConfig" => %{
               "mode" => "ANY",
               "allowedFunctionNames" => ["lookup_weather"]
             }
           }
  end

  test "builds dynamic stream request URLs with the selected API version" do
    {:ok, request} =
      GoogleGenerateContent.build_request(
        ReqLlmNext.Providers.Google,
        TestModels.google(%{id: "gemini-2.5-flash"}),
        "Hello",
        api_key: "test-key",
        provider_options: [google_api_version: "v1"]
      )

    assert request.scheme == :https
    assert request.host == "generativelanguage.googleapis.com"
    assert request.path == "/v1/models/gemini-2.5-flash:streamGenerateContent"
    assert request.query == "alt=sse"
  end

  test "decodes streaming candidate payloads through the provider semantic protocol" do
    chunks =
      %{
        data:
          Jason.encode!(%{
            "candidates" => [%{"content" => %{"parts" => [%{"text" => "Answer"}]}}]
          })
      }
      |> GoogleGenerateContent.decode_wire_event()
      |> Enum.flat_map(
        &ReqLlmNext.SemanticProtocols.GoogleGenerateContent.decode_event(&1, TestModels.google())
      )

    assert chunks == ["Answer"]
  end
end
