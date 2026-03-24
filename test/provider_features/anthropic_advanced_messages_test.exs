defmodule ReqLlmNext.ProviderFeatures.AnthropicAdvancedMessagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Context, Response}

  @model_spec "anthropic:claude-sonnet-4-6"

  test "supports file-backed document requests with citations enabled" do
    context =
      ReqLlmNext.context([
        Context.user([
          Context.ContentPart.text("Answer with the exact percentage from the document."),
          document_part()
        ])
      ])

    {:ok, response} =
      ReqLlmNext.generate_text(@model_spec, context,
        fixture: "document_citations",
        max_tokens: 256
      )

    assert %Response{} = response
    assert is_binary(Response.text(response))
    assert Response.text(response) =~ "12"

    fixture = load_fixture("document_citations")
    [message] = get_in(fixture, ["request", "body", "canonical_json", "messages"])
    [_text_part, document_part] = message["content"]

    assert document_part["type"] == "document"
    assert get_in(document_part, ["source", "type"]) == "file"
    assert document_part["citations"] == %{"enabled" => true}
  end

  test "supports web search server tools and preserves provider metadata" do
    {:ok, response} =
      ReqLlmNext.generate_text(
        @model_spec,
        "Tell me the official Anthropic docs host.",
        fixture: "web_search",
        max_tokens: 256,
        tools: [ReqLlmNext.Anthropic.web_search_tool(dynamic_filtering: true)]
      )

    assert %Response{} = response
    assert is_binary(Response.text(response))
    assert String.length(Response.text(response)) > 0
    assert get_in(response.provider_meta, [:anthropic_server_tool_use, "name"]) == "web_search"

    fixture = load_fixture("web_search")

    assert get_in(fixture, ["request", "body", "canonical_json", "tools"]) == [
             %{"name" => "web_search", "type" => "web_search_20260209"}
           ]
  end

  test "supports code execution server tools and preserves provider metadata" do
    {:ok, response} =
      ReqLlmNext.generate_text(
        @model_spec,
        "Use code execution to compute the sum of the first ten prime numbers. Reply with the number only.",
        fixture: "code_execution",
        max_tokens: 256,
        tools: [ReqLlmNext.Anthropic.code_execution_tool()]
      )

    assert %Response{} = response
    assert Response.text(response) == "129"

    assert get_in(response.provider_meta, [:anthropic_server_tool_use, "name"]) ==
             "bash_code_execution"

    fixture = load_fixture("code_execution")

    assert get_in(fixture, ["request", "body", "canonical_json", "tools"]) == [
             %{"name" => "code_execution", "type" => "code_execution_20250825"}
           ]
  end

  defp document_part do
    ReqLlmNext.Anthropic.document_file_id(document_file_id(), %{
      title: "Quarterly Report",
      citations: %{enabled: true}
    })
  end

  defp document_file_id do
    if recording_fixtures?() do
      {:ok, upload} =
        ReqLlmNext.Anthropic.upload_file(
          "Quarterly revenue increased by 12 percent year over year.",
          filename: "report.txt"
        )

      upload["id"] || upload[:id]
    else
      "file_replay_document"
    end
  end

  defp load_fixture(name) do
    "/Users/mhostetler/Source/ReqLLM/reqllm_next/test/fixtures/anthropic/claude_sonnet_4_6/#{name}.json"
    |> File.read!()
    |> Jason.decode!()
  end

  defp recording_fixtures? do
    System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") == "record"
  end
end
