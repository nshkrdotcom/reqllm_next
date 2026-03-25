defmodule ReqLlmNext.OpenAI.ConversationsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Conversations

  test "builds conversation bodies with metadata and items" do
    assert Conversations.build_create_body(
             metadata: %{session: "demo"},
             items: [
               %{type: "message", role: "user", content: [%{type: "input_text", text: "hi"}]}
             ]
           ) ==
             %{
               metadata: %{session: "demo"},
               items: [
                 %{type: "message", role: "user", content: [%{type: "input_text", text: "hi"}]}
               ]
             }
  end

  test "builds conversation item query paths" do
    assert Conversations.build_query_path("/v1/conversations/conv_123/items",
             after: "item_1",
             limit: 20
           ) ==
             "/v1/conversations/conv_123/items?after=item_1&limit=20"
  end
end
