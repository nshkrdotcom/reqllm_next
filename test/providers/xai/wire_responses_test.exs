defmodule ReqLlmNext.Wire.XAIResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.XAIResponses

  test "encodes xAI provider-native tools onto the Responses request body" do
    body =
      XAIResponses.build_request_body(
        TestModels.xai(),
        "What happened today?",
        tools: [
          ReqLlmNext.XAI.Tools.web_search(),
          ReqLlmNext.XAI.Tools.x_search(),
          ReqLlmNext.XAI.Tools.code_execution()
        ]
      )

    assert body.model == "grok-4"
    assert Enum.map(body.tools, & &1.type) == ["web_search", "x_search", "code_execution"]
  end

  test "preserves canonical function tools alongside xAI built-in tools" do
    tool =
      ReqLlmNext.Tool.new!(
        name: "lookup",
        description: "Look up a record",
        parameter_schema: [id: [type: :string, required: true]],
        callback: fn _args -> {:ok, "found"} end
      )

    body =
      XAIResponses.build_request_body(
        TestModels.xai(),
        "Find the record",
        tools: [tool, ReqLlmNext.XAI.Tools.web_search()]
      )

    assert Enum.any?(body.tools, &(&1.type == "function"))
    assert Enum.any?(body.tools, &(&1.type == "web_search"))
  end

  test "decodes responses events through the xAI semantic protocol" do
    ["Answer"] =
      XAIResponses.decode_sse_event(
        %{data: Jason.encode!(%{"type" => "response.output_text.delta", "delta" => "Answer"})},
        TestModels.xai()
      )
  end
end
