defmodule ReqLlmNext.ModelSlices.AnthropicHaiku45Test do
  use ExUnit.Case, async: true

  @model_spec "anthropic:claude-haiku-4-5"
  @expected_scenarios [
    :basic,
    :usage,
    :token_limit,
    :multi_turn,
    :tool_multi,
    :tool_round_trip,
    :tool_none,
    :reasoning,
    :image_input
  ]

  test "starter scenario set stays explicit for claude-haiku-4-5" do
    {:ok, model} = LLMDB.model(@model_spec)

    assert Enum.map(ReqLlmNext.Scenarios.for_model(model), & &1.id()) == @expected_scenarios
  end

  test "claude-haiku-4-5 passes its supported starter scenarios with fixtures" do
    {:ok, model} = LLMDB.model(@model_spec)
    results = ReqLlmNext.Scenarios.run_for_model(@model_spec, model)

    assert Enum.map(results, & &1.scenario_id) == @expected_scenarios
    assert Enum.all?(results, &(&1.status == :ok))
  end
end
