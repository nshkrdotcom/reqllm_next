defmodule ReqLlmNext.OpenAI.ModerationsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.OpenAI.Moderations

  test "builds moderation bodies for string input" do
    body = Moderations.build_body("Hello", [])

    assert body.model == "omni-moderation-latest"
    assert body.input == "Hello"
  end

  test "builds moderation bodies for context input" do
    context = Context.user("Review this text")
    body = Moderations.build_body(context, model: "omni-moderation-latest")

    assert body.model == "omni-moderation-latest"
    assert is_list(body.input)
    assert hd(body.input)["role"] == "user"
  end
end
