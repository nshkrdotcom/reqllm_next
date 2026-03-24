defmodule ReqLlmNext.Scenarios.ReasoningTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Reasoning
  alias ReqLlmNext.TestModels
  import ReqLlmNext.ScenarioTestHelpers

  describe "metadata and applicability" do
    test "reports metadata and reasoning support" do
      assert_scenario_metadata(Reasoning, :reasoning, "Reasoning")
      assert Reasoning.applies?(TestModels.openai_reasoning())
      assert Reasoning.applies?(TestModels.anthropic_thinking())
      refute Reasoning.applies?(TestModels.openai())
      refute Reasoning.applies?(TestModels.openai_embedding())
      refute Reasoning.applies?(TestModels.anthropic())
    end
  end

  describe "final answer extraction" do
    test "extracts FINAL_ANSWER lines case-insensitively" do
      assert extract_final_answer("Some reasoning...\nFINAL_ANSWER: 34\nMore text") == {:ok, 34}
      assert extract_final_answer("The total is FINAL_ANSWER: $42") == {:ok, 42}
      assert extract_final_answer("final_answer: 100") == {:ok, 100}
      assert extract_final_answer("Some text without the answer format") == :no_final_answer
    end
  end

  describe "answer validation" do
    test "accepts the expected answer" do
      assert validate_reasoning_answer("FINAL_ANSWER: 34") == :ok
      assert validate_reasoning_answer("The answer is 34 dollars.") == :ok
    end

    test "returns descriptive errors for incorrect or missing answers" do
      assert validate_reasoning_answer("FINAL_ANSWER: 35") ==
               {:error, {:incorrect_answer, 35, :expected, 34}}

      assert validate_reasoning_answer("The answer is thirty-four.") ==
               {:error, :no_final_answer_and_no_expected_value}
    end
  end
end
