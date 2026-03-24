defmodule ReqLlmNext.ObjectPromptTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Context, ObjectPrompt}

  @schema %{
    schema: [
      name: [type: :string, required: true],
      age: [type: :integer, required: true]
    ]
  }

  test "injects prompt-and-parse instructions into string prompts" do
    prompt = ObjectPrompt.for_prompt_and_parse("Generate a person", @schema)

    assert is_binary(prompt)
    assert prompt =~ "Return only valid JSON"
    assert prompt =~ "Generate a person"
    assert prompt =~ "\"type\":\"object\""
  end

  test "prepends a system instruction for context prompts" do
    context =
      Context.new([
        Context.user("Generate a person")
      ])

    result = ObjectPrompt.for_prompt_and_parse(context, @schema)

    assert %Context{} = result
    assert hd(result.messages).role == :system
    assert hd(hd(result.messages).content).text =~ "Return only valid JSON"
    assert List.last(result.messages).role == :user
  end
end
