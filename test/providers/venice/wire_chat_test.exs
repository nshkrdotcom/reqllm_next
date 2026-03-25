defmodule ReqLlmNext.Wire.VeniceChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.VeniceChat

  test "encodes provider-specific Venice request fields" do
    body =
      VeniceChat.encode_body(
        TestModels.venice(%{id: "venice-uncensored"}),
        "Explain the result",
        provider_options: [
          character_slug: "assistant-char",
          enable_web_search: "auto",
          enable_web_scraping: true,
          enable_web_citations: true,
          return_search_results_as_documents: true,
          include_venice_system_prompt: false
        ]
      )

    assert body.model == "venice-uncensored"

    assert body.venice_parameters == %{
             character_slug: "assistant-char",
             enable_web_search: "auto",
             enable_web_scraping: true,
             enable_web_citations: true,
             return_search_results_as_documents: true,
             include_venice_system_prompt: false
           }
  end

  test "merges raw venice_parameters with lifted Venice options" do
    body =
      VeniceChat.encode_body(
        TestModels.venice(),
        "Explain the result",
        provider_options: [
          venice_parameters: %{enable_web_search: "off", disable_thinking: true},
          enable_web_search: "on",
          enable_web_citations: true
        ]
      )

    assert body.venice_parameters == %{
             enable_web_search: "on",
             disable_thinking: true,
             enable_web_citations: true
           }
  end

  test "decodes SSE events through the OpenAI-compatible semantic protocol" do
    ["Answer"] =
      VeniceChat.decode_sse_event(
        %{data: Jason.encode!(%{"choices" => [%{"delta" => %{"content" => "Answer"}}]})},
        TestModels.venice()
      )
  end
end
