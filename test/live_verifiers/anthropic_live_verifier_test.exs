defmodule ReqLlmNext.LiveVerifiers.AnthropicTest do
  use ReqLlmNext.TestSupport.LiveVerifierCase, provider: :anthropic

  alias ReqLlmNext.Response

  @baseline_model "anthropic:claude-haiku-4-5"
  @advanced_model "anthropic:claude-sonnet-4-6"

  test "verifies the baseline native messages lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_text(
               @baseline_model,
               "Reply with the single word ready.",
               max_tokens: 32
             )

    assert %Response{} = response
    assert is_binary(Response.text(response))
    assert String.length(Response.text(response)) > 0
  end

  test "verifies the web fetch server tool lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_text(
               @advanced_model,
               "Fetch https://docs.anthropic.com and answer with the docs host in one sentence.",
               max_tokens: 128,
               tools: [ReqLlmNext.Anthropic.web_fetch_tool(citations: %{enabled: true})]
             )

    assert %Response{} = response

    assert Enum.any?(Response.provider_items(response), fn item ->
             item["anthropic_type"] == "web_fetch_result"
           end)
  end

  test "verifies context-management edits on the native messages lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_text(
               @advanced_model,
               "Reply with the word acknowledged.",
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
  end
end
