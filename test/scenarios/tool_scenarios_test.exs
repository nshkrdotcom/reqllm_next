defmodule ReqLlmNext.Scenarios.ToolScenariosTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.ToolCall
  import ReqLlmNext.ScenarioTestHelpers

  describe "ToolNone" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ToolNone, :tool_none, "Tool Avoidance")
      assert Scenarios.ToolNone.applies?(TestModels.openai())

      refute Scenarios.ToolNone.applies?(
               TestModels.openai(%{capabilities: %{chat: true, tools: %{enabled: false}}})
             )

      refute Scenarios.ToolNone.applies?(TestModels.openai_embedding())
      refute Scenarios.ToolNone.applies?(nil)
    end

    test "validates responses with no tool usage" do
      assert validate_no_tool_response("", []) == %{status: :error, error: :empty_response}

      assert validate_no_tool_response("Some response", [%{name: "some_tool"}]) == %{
               status: :error,
               error: :unexpected_tool_calls
             }

      assert validate_no_tool_response("Here's a joke about cats!", []) == :ok
    end

    test "runs successfully with fixture replay" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      assert_ok_result(Scenarios.ToolNone.run("openai:gpt-4o-mini", model, []), "stream_text")
    end
  end

  describe "ToolMulti" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ToolMulti, :tool_multi, "Multi-tool Selection")
      assert Scenarios.ToolMulti.applies?(TestModels.openai())
      assert Scenarios.ToolMulti.applies?(TestModels.anthropic())
      refute Scenarios.ToolMulti.applies?(TestModels.openai_embedding())
    end

    test "validates tool selection and arguments" do
      assert validate_tool_selection([], "get_weather", "location", :missing_location_arg) == %{
               status: :error,
               error: :no_tool_calls
             }

      wrong_tool = [ToolCall.new("1", "tell_joke", "{}")]

      assert validate_tool_selection(wrong_tool, "get_weather", "location", :missing_location_arg) ==
               %{status: :error, error: :wrong_tool_called}

      missing_arg = [ToolCall.new("1", "get_weather", "{}")]

      assert validate_tool_selection(
               missing_arg,
               "get_weather",
               "location",
               :missing_location_arg
             ) == %{
               status: :error,
               error: :missing_location_arg
             }

      valid_tool = [ToolCall.new("1", "get_weather", ~s({"location": "Paris"}))]

      assert validate_tool_selection(valid_tool, "get_weather", "location", :missing_location_arg) ==
               :ok
    end

    test "runs successfully with fixture replay" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      assert_ok_result(Scenarios.ToolMulti.run("openai:gpt-4o-mini", model, []), "stream_text")
    end
  end

  describe "ToolParallel" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ToolParallel, :tool_parallel, "Parallel Tool Calls")
      assert Scenarios.ToolParallel.applies?(TestModels.openai())
      assert Scenarios.ToolParallel.applies?(TestModels.anthropic())

      refute Scenarios.ToolParallel.applies?(
               TestModels.openai(%{
                 capabilities: %{
                   chat: true,
                   tools: %{enabled: true, parallel: false}
                 }
               })
             )

      refute Scenarios.ToolParallel.applies?(TestModels.openai_reasoning())
    end

    test "validates multiple parallel tool calls" do
      assert validate_parallel_calls([ToolCall.new("1", "get_weather", "{}")]) == %{
               status: :error,
               error: {:expected_multiple_tool_calls, 1}
             }

      assert validate_parallel_calls(nil) == %{
               status: :error,
               error: {:expected_multiple_tool_calls, 0}
             }

      wrong_tools = [
        ToolCall.new("1", "other_tool", "{}"),
        ToolCall.new("2", "another_tool", "{}")
      ]

      assert validate_parallel_calls(wrong_tools) == %{
               status: :error,
               error: {:wrong_tools_called, ["another_tool", "other_tool"]}
             }

      valid_tools = [
        ToolCall.new("1", "get_weather", "{}"),
        ToolCall.new("2", "get_time", "{}")
      ]

      assert validate_parallel_calls(valid_tools) == :ok
    end
  end

  describe "ToolRoundTrip" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ToolRoundTrip, :tool_round_trip, "Tool Round Trip")
      assert Scenarios.ToolRoundTrip.applies?(TestModels.openai())
      refute Scenarios.ToolRoundTrip.applies?(TestModels.openai_reasoning())
      refute Scenarios.ToolRoundTrip.applies?(TestModels.openai_embedding())
      refute Scenarios.ToolRoundTrip.applies?(nil)
    end

    test "validates final tool round-trip responses" do
      assert validate_tool_round_trip("", []) == %{status: :error, error: :empty_final_response}

      assert validate_tool_round_trip("The answer is seven", []) == %{
               status: :error,
               error: :result_not_in_response
             }

      assert validate_tool_round_trip("sum=5", [ToolCall.new("1", "add", "{}")]) == %{
               status: :error,
               error: :unexpected_tool_calls
             }

      assert validate_tool_round_trip("The sum is 5", []) == :ok
    end

    test "runs successfully with fixture replay" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.ToolRoundTrip.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) >= 1
    end
  end
end
