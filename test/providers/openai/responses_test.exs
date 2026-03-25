defmodule ReqLlmNext.OpenAI.ResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Responses
  alias ReqLlmNext.TestModels

  test "builds compact request bodies" do
    assert Responses.build_compact_body(
             summary_format: "bullet_points",
             metadata: %{job: "compact"}
           ) ==
             %{summary_format: "bullet_points", metadata: %{job: "compact"}}
  end

  test "builds count-input-tokens bodies from the Responses wire" do
    body =
      Responses.build_count_body(
        TestModels.openai_reasoning(),
        "Summarize the uploaded report",
        tools: [ReqLlmNext.OpenAI.web_search_tool()],
        conversation: "conv_123"
      )

    assert body.model == "o1-test"
    assert [%{role: "user"}] = body.input
    assert body.conversation == "conv_123"
    assert [%{type: "web_search"}] = body.tools
  end
end
