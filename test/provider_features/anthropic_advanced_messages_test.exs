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

    assert get_in(response.provider_meta, [:anthropic_server_tool_use, "name"]) in [
             "web_search",
             "code_execution"
           ]

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
    assert is_binary(Response.text(response))

    assert get_in(response.provider_meta, [:anthropic_server_tool_use, "name"]) ==
             "bash_code_execution"

    fixture = load_fixture("code_execution")

    assert get_in(fixture, ["request", "body", "canonical_json", "tools"]) == [
             %{"name" => "code_execution", "type" => "code_execution_20250825"}
           ]
  end

  test "supports web fetch server tools and preserves provider items" do
    {:ok, response} =
      ReqLlmNext.generate_text(
        @model_spec,
        "Fetch https://docs.anthropic.com and tell me the docs host in one sentence.",
        fixture: "web_fetch",
        max_tokens: 256,
        tools: [ReqLlmNext.Anthropic.web_fetch_tool(citations: %{enabled: true})]
      )

    assert %Response{} = response
    assert is_binary(Response.text(response))

    assert Enum.any?(Response.provider_items(response), fn item ->
             item["anthropic_type"] == "web_fetch_result"
           end)

    fixture = load_fixture("web_fetch")

    assert get_in(fixture, ["request", "body", "canonical_json", "tools"]) == [
             %{
               "citations" => %{"enabled" => true},
               "name" => "web_fetch",
               "type" => "web_fetch_20250910"
             }
           ]
  end

  test "accepts context management edit strategies on the native messages lane" do
    {:ok, response} =
      ReqLlmNext.generate_text(
        @model_spec,
        "Reply with the word acknowledged.",
        fixture: "context_management_edit",
        max_tokens: 64,
        thinking: %{type: "adaptive"},
        context_management: %{
          edits: [
            %{type: "clear_thinking_20251015"},
            %{type: "clear_tool_uses_20250919"}
          ]
        }
      )

    assert %Response{} = response
    assert is_binary(Response.text(response))
    assert String.length(Response.text(response)) > 0

    fixture = load_fixture("context_management_edit")

    assert get_in(fixture, ["request", "headers", "anthropic-beta"]) =~
             "context-management-2025-06-27"

    assert get_in(fixture, ["request", "body", "canonical_json", "thinking"]) == %{
             "type" => "adaptive"
           }

    assert get_in(fixture, ["request", "body", "canonical_json", "context_management", "edits"]) ==
             [
               %{"type" => "clear_thinking_20251015"},
               %{"type" => "clear_tool_uses_20250919"}
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
    Path.expand("../fixtures/anthropic/claude_sonnet_4_6/#{name}.json", __DIR__)
    |> File.read!()
    |> Jason.decode!()
  end

  defp recording_fixtures? do
    System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") == "record"
  end
end
