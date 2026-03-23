defmodule ReqLlmNext.ModelSlices.OpenAIGPT4oMiniTest do
  use ExUnit.Case, async: true

  @model_spec "openai:gpt-4o-mini"
  @expected_scenarios [
    :basic,
    :streaming,
    :usage,
    :token_limit,
    :multi_turn,
    :tool_multi,
    :tool_round_trip,
    :tool_none,
    :image_input
  ]

  @person_schema [
    name: [type: :string, required: true],
    age: [type: :integer, required: true],
    bio: [type: :string]
  ]

  test "starter scenario set stays explicit for gpt-4o-mini" do
    {:ok, model} = LLMDB.model(@model_spec)

    assert Enum.map(ReqLlmNext.Scenarios.for_model(model), & &1.id()) == @expected_scenarios
  end

  test "gpt-4o-mini passes its supported starter scenarios with fixtures" do
    {:ok, model} = LLMDB.model(@model_spec)
    results = ReqLlmNext.Scenarios.run_for_model(@model_spec, model)

    assert Enum.map(results, & &1.scenario_id) == @expected_scenarios
    assert Enum.all?(results, &(&1.status == :ok))
  end

  test "gpt-4o-mini supports structured object generation through the responses surface" do
    assert {:ok, response} =
             ReqLlmNext.generate_object(
               @model_spec,
               "Generate a person",
               @person_schema,
               fixture: "person_object"
             )

    assert is_map(response.object)
    assert is_binary(response.object["name"] || response.object[:name])
    assert is_integer(response.object["age"] || response.object[:age])
  end
end
