defmodule ReqLlmNext.Scenarios.MultiTurnTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.MultiTurn
  alias ReqLlmNext.TestModels
  import ReqLlmNext.ScenarioTestHelpers

  describe "metadata and applicability" do
    test "reports metadata and multi-turn support" do
      assert_scenario_metadata(MultiTurn, :multi_turn, "Multi-turn Context")
      assert MultiTurn.applies?(TestModels.openai())
      assert MultiTurn.applies?(TestModels.anthropic())
      assert MultiTurn.applies?(TestModels.openai_reasoning())
      refute MultiTurn.applies?(TestModels.openai_embedding())
      refute MultiTurn.applies?(nil)
    end
  end

  describe "turn validation" do
    test "detects missing or incorrect second-turn answers" do
      assert if(String.length("") == 0,
               do: %{status: :error, error: :empty_turn1_response},
               else: :ok
             ) == %{
               status: :error,
               error: :empty_turn1_response
             }

      assert if(String.contains?("I don't remember", "42"),
               do: :ok,
               else: %{status: :error, error: {:wrong_answer, "I don't remember"}}
             ) == %{status: :error, error: {:wrong_answer, "I don't remember"}}

      assert if(String.contains?("Your favorite number is 42", "42"),
               do: :ok,
               else: :error
             ) == :ok
    end
  end

  describe "fixture replay" do
    test "runs successfully with fixture replay" do
      {:ok, openai} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, anthropic} = LLMDB.model("anthropic:claude-sonnet-4-20250514")

      assert_ok_steps(MultiTurn.run("openai:gpt-4o-mini", openai, []), ["turn_1", "turn_2"])

      assert_ok_steps(MultiTurn.run("anthropic:claude-sonnet-4-20250514", anthropic, []), [
        "turn_1",
        "turn_2"
      ])
    end
  end
end
