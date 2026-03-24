defmodule ReqLlmNext.ObjectPrompt do
  @moduledoc """
  Builds prompt-and-parse object instructions for surfaces without native schema support.
  """

  alias ReqLlmNext.Context

  @spec for_prompt_and_parse(
          String.t() | Context.t(),
          %{required(:schema) => term(), optional(:compiled) => term()}
        ) ::
          String.t() | Context.t()
  def for_prompt_and_parse(prompt, %{schema: schema}) do
    instruction = instruction(schema)

    case prompt do
      %Context{} = context ->
        Context.prepend(context, Context.system(instruction))

      prompt when is_binary(prompt) ->
        instruction <> "\n\nUser request:\n" <> prompt
    end
  end

  defp instruction(schema) do
    schema
    |> ReqLlmNext.Schema.to_json()
    |> Jason.encode!()
    |> then(fn json_schema ->
      """
      Return only valid JSON that matches this JSON Schema exactly.
      Do not include markdown fences or explanatory text.
      JSON Schema:
      #{json_schema}
      """
      |> String.trim()
    end)
  end
end
