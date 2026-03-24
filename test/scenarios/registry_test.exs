defmodule ReqLlmNext.Scenarios.RegistryTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios
  alias ReqLlmNext.TestModels

  describe "all/0" do
    test "returns scenario modules and includes defaults" do
      scenarios = Scenarios.all()

      assert is_list(scenarios)
      assert length(scenarios) > 0
      assert Enum.all?(scenarios, &is_atom/1)
      assert ReqLlmNext.Scenarios.Basic in scenarios
      assert ReqLlmNext.Scenarios.Streaming in scenarios
      assert ReqLlmNext.Scenarios.Embedding in scenarios
      assert ReqLlmNext.Scenarios.Reasoning in scenarios
    end

    test "respects application config override" do
      original = Application.get_env(:req_llm_next, Scenarios)

      try do
        Application.put_env(:req_llm_next, Scenarios, [ReqLlmNext.Scenarios.Basic])
        assert Scenarios.all() == [ReqLlmNext.Scenarios.Basic]
      after
        if original do
          Application.put_env(:req_llm_next, Scenarios, original)
        else
          Application.delete_env(:req_llm_next, Scenarios)
        end
      end
    end
  end

  describe "ids/0 and get/1" do
    test "returns scenario ids and resolves registered scenarios" do
      ids = Scenarios.ids()

      assert is_list(ids)
      assert Enum.all?(ids, &is_atom/1)
      assert :basic in ids
      assert :streaming in ids
      assert :embedding in ids
      assert :reasoning in ids
      assert :prompt_caching in ids
      assert :multi_turn in ids
      assert :object_streaming in ids
      assert :tool_parallel in ids

      assert Scenarios.get(:basic) == ReqLlmNext.Scenarios.Basic
      assert Scenarios.get(:streaming) == ReqLlmNext.Scenarios.Streaming
      assert Scenarios.get(:embedding) == ReqLlmNext.Scenarios.Embedding
      assert Scenarios.get(:nonexistent_scenario) == nil
    end
  end

  describe "for_model/1" do
    test "filters scenarios for representative models" do
      chat_scenarios = Scenarios.for_model(TestModels.openai())
      embedding_scenarios = Scenarios.for_model(embedding_model())
      reasoning_scenarios = Scenarios.for_model(TestModels.openai_reasoning())

      assert ReqLlmNext.Scenarios.Basic in chat_scenarios
      assert ReqLlmNext.Scenarios.Streaming in chat_scenarios
      assert ReqLlmNext.Scenarios.ToolParallel in chat_scenarios
      assert ReqLlmNext.Scenarios.ObjectStreaming in chat_scenarios
      refute ReqLlmNext.Scenarios.Embedding in chat_scenarios

      assert ReqLlmNext.Scenarios.Embedding in embedding_scenarios
      refute ReqLlmNext.Scenarios.Basic in embedding_scenarios

      assert ReqLlmNext.Scenarios.Reasoning in reasoning_scenarios
      assert ReqLlmNext.Scenarios.Basic in reasoning_scenarios
    end

    test "respects capability-dependent exclusions" do
      no_parallel_tools =
        TestModels.openai(%{capabilities: %{tools: %{enabled: true, parallel: false}}})

      no_object_streaming =
        TestModels.anthropic_thinking(%{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            json: %{native: true, schema: false, strict: false},
            streaming: %{text: false, tool_calls: true}
          }
        })

      object_streaming_model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: true, strict: true},
            streaming: %{text: true, tool_calls: false}
          }
        })

      refute ReqLlmNext.Scenarios.ToolParallel in Scenarios.for_model(no_parallel_tools)
      refute ReqLlmNext.Scenarios.ObjectStreaming in Scenarios.for_model(no_object_streaming)
      assert ReqLlmNext.Scenarios.ObjectStreaming in Scenarios.for_model(object_streaming_model)
    end
  end

  describe "run_for_model/3" do
    test "annotates scenario results with metadata" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      results = Scenarios.run_for_model("openai:gpt-4o-mini", model, [])

      assert is_list(results)
      assert length(results) > 0

      Enum.each(results, fn result ->
        assert Map.has_key?(result, :status)
        assert Map.has_key?(result, :scenario_id)
        assert Map.has_key?(result, :scenario_name)
        assert Map.has_key?(result, :model_spec)
        assert result.model_spec == "openai:gpt-4o-mini"
        assert result.status in [:ok, :error, :skipped]
      end)
    end
  end

  defp embedding_model do
    TestModels.openai_embedding(%{
      capabilities: %{
        chat: false,
        embeddings: true,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      }
    })
  end
end

defmodule ReqLlmNext.ScenarioResultTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenario

  describe "fixture_name/1 and fixture_name/2" do
    test "formats fixture names predictably" do
      assert Scenario.fixture_name(:basic) == "basic"
      assert Scenario.fixture_name(:tool_round_trip) == "tool_round_trip"
      assert Scenario.fixture_name(:tool_round_trip, "1") == "tool_round_trip_1"
      assert Scenario.fixture_name(:multi_turn, "request") == "multi_turn_request"
      assert Scenario.fixture_name(:tool_round_trip, :first) == "tool_round_trip_first"
      assert Scenario.fixture_name(:multi_turn, :response) == "multi_turn_response"
      assert Scenario.fixture_name(:basic, nil) == "basic"
    end
  end

  describe "fixture_for_run/2 and fixture_for_run/3" do
    test "keeps the default fixture name when no overrides are present" do
      assert Scenario.fixture_for_run(:basic, []) == "basic"
      assert Scenario.fixture_for_run(:tool_round_trip, [], "1") == "tool_round_trip_1"
    end

    test "supports fixture suffixes and explicit fixture overrides" do
      assert Scenario.fixture_for_run(:basic, fixture_suffix: "websocket") == "basic_websocket"
      assert Scenario.fixture_for_run(:basic, fixture: "custom_basic") == "custom_basic"

      assert Scenario.fixture_for_run(:multi_turn, [fixture_suffix: :websocket], "1") ==
               "multi_turn_1_websocket"
    end
  end

  describe "result helpers" do
    test "build ok, error, and skipped results" do
      steps = [%{name: "step1", status: :ok}]

      assert Scenario.ok() == %{status: :ok, steps: [], error: nil}
      assert Scenario.ok(steps) == %{status: :ok, steps: steps, error: nil}
      assert Scenario.error(:some_error) == %{status: :error, steps: [], error: :some_error}

      assert Scenario.error(:api_error, steps) == %{
               status: :error,
               steps: steps,
               error: :api_error
             }

      assert Scenario.skipped() == %{status: :skipped, steps: [], error: :not_applicable}

      assert Scenario.skipped(:model_not_supported) == %{
               status: :skipped,
               steps: [],
               error: :model_not_supported
             }
    end

    test "build steps with optional request, response, and error fields" do
      assert Scenario.step("generate_text", :ok) == %{
               name: "generate_text",
               status: :ok,
               request: nil,
               response: nil,
               error: nil
             }

      assert Scenario.step("generate_text", :ok, response: %{text: "Hello"}) == %{
               name: "generate_text",
               status: :ok,
               request: nil,
               response: %{text: "Hello"},
               error: nil
             }

      assert Scenario.step("generate_text", :error, error: :timeout) == %{
               name: "generate_text",
               status: :error,
               request: nil,
               response: nil,
               error: :timeout
             }
    end
  end
end
