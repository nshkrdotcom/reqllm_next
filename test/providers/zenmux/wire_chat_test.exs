defmodule ReqLlmNext.Wire.ZenmuxChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.ZenmuxChat

  test "encodes Zenmux chat request fields" do
    body =
      ZenmuxChat.encode_body(
        TestModels.zenmux(%{extra: %{api: "chat"}}),
        "Explain the result",
        provider_options: [
          provider: %{routing: %{type: "priority"}},
          model_routing_config: %{preference: "quality"},
          reasoning: %{depth: "full"},
          web_search_options: %{search_context_size: "medium"},
          verbosity: "high"
        ],
        max_tokens: 512,
        reasoning_effort: :high
      )

    assert body.model == "openai/gpt-5.2"
    assert body.max_completion_tokens == 512
    refute Map.has_key?(body, :max_tokens)
    assert body.provider == %{routing: %{type: "priority"}}
    assert body.model_routing_config == %{preference: "quality"}
    assert body.reasoning == %{depth: "full"}
    assert body.web_search_options == %{search_context_size: "medium"}
    assert body.verbosity == "high"
    assert body.reasoning_effort == "high"
  end

  test "decodes reasoning text and embedded tool calls through the provider semantic protocol" do
    chunks =
      ZenmuxChat.decode_sse_event(
        %{
          data:
            Jason.encode!(%{
              "choices" => [
                %{
                  "message" => %{
                    "reasoning" =>
                      "Thinking... <｜tool▁call▁begin｜>weather<｜tool▁sep｜>{\"location\":\"Paris\"}<｜tool▁call▁end｜>",
                    "content" => "",
                    "reasoning_details" => [%{"type" => "reasoning.text", "text" => "logic"}]
                  },
                  "finish_reason" => "tool_calls"
                }
              ]
            })
        },
        TestModels.zenmux(%{extra: %{api: "chat"}})
      )

    assert Enum.any?(chunks, fn
             {:thinking, reasoning} when is_binary(reasoning) -> true
             _other -> false
           end)

    assert "Thinking..." in chunks

    assert Enum.any?(chunks, fn
             {:tool_call_delta,
              %{function: %{"arguments" => "{\"location\":\"Paris\"}", "name" => "weather"}}} ->
               true

             _other ->
               false
           end)

    assert Enum.any?(chunks, fn
             {:provider_item,
              %{
                type: "reasoning_details",
                details: [%{"type" => "reasoning.text", "text" => "logic"}]
              }} ->
               true

             _other ->
               false
           end)

    assert {:meta, %{finish_reason: :tool_calls, terminal?: true}} in chunks
  end
end
