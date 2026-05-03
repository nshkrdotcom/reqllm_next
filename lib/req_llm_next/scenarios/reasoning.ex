defmodule ReqLlmNext.Scenarios.Reasoning do
  @moduledoc """
  Reasoning capability scenario.

  Tests that models with reasoning capabilities can solve multi-step
  logic/math problems correctly.
  """

  use ReqLlmNext.Scenario,
    id: :reasoning,
    name: "Reasoning",
    description: "Multi-step reasoning and problem solving"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.reasoning_enabled?(model)

  @impl true
  def run(model_spec, _model, opts) do
    prompt = """
    Solve this step by step. At the end, output a line starting with
    FINAL_ANSWER: followed by the result only.

    A store sells apples at $3 each and oranges at $2 each.
    John buys 4 apples and 3 oranges.
    Mary buys 2 apples and 5 oranges.
    What is the total amount they spend together?
    """

    fixture_opts = run_opts(opts, fixture: fixture_for_run(id(), opts), max_tokens: 1000)

    case ReqLlmNext.generate_text(model_spec, prompt, fixture_opts) do
      {:ok, response} ->
        text = ReqLlmNext.Response.text(response) || ""
        thinking = ReqLlmNext.Response.thinking(response) || ""
        combined = text <> thinking

        cond do
          String.length(combined) == 0 ->
            error(:empty_response, [
              step("reasoning", :error, response: response, error: :empty_response)
            ])

          true ->
            validate_answer(response, text)
        end

      {:error, reason} ->
        error(reason, [step("reasoning", :error, error: reason)])
    end
  end

  defp validate_answer(response, text) do
    case extract_final_answer(text) do
      {:ok, answer} when answer == 34 ->
        ok([step("reasoning", :ok, response: response)])

      {:ok, answer} ->
        error({:incorrect_answer, answer, :expected, 34}, [
          step("reasoning", :error,
            response: response,
            error: {:incorrect_answer, answer, :expected, 34}
          )
        ])

      :no_final_answer ->
        if String.contains?(text, "34") do
          ok([step("reasoning", :ok, response: response)])
        else
          error(:no_final_answer_and_no_34, [
            step("reasoning", :error, response: response, error: :no_final_answer_and_no_34)
          ])
        end
    end
  end

  defp extract_final_answer(text) do
    with {:ok, tail} <- final_answer_tail(text),
         {:ok, digits} <- leading_number(tail) do
      {:ok, String.to_integer(digits)}
    else
      _ -> :no_final_answer
    end
  end

  defp final_answer_tail(text) do
    lower = String.downcase(text)
    marker = "final_answer:"

    case :binary.match(lower, marker) do
      {index, size} ->
        {:ok, binary_part(text, index + size, byte_size(text) - index - size)}

      :nomatch ->
        :error
    end
  end

  defp leading_number(text) do
    text
    |> String.trim_leading()
    |> trim_leading_dollar()
    |> String.trim_leading()
    |> take_digits()
  end

  defp trim_leading_dollar("$" <> rest), do: rest
  defp trim_leading_dollar(text), do: text

  defp take_digits(text) do
    digits =
      text
      |> :binary.bin_to_list()
      |> Enum.take_while(&(&1 in ?0..?9))
      |> IO.iodata_to_binary()

    if digits == "", do: :error, else: {:ok, digits}
  end
end
