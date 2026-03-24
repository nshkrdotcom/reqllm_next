defmodule ReqLlmNext.Scenarios.TextScenariosTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios
  alias ReqLlmNext.TestModels
  import ReqLlmNext.ScenarioTestHelpers

  describe "Basic" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.Basic, :basic, "Basic Text")
      assert Scenarios.Basic.applies?(TestModels.openai())
      assert Scenarios.Basic.applies?(TestModels.anthropic())
      refute Scenarios.Basic.applies?(TestModels.openai_embedding())
      refute Scenarios.Basic.applies?(nil)
      refute Scenarios.Basic.applies?(%{})
    end

    test "validates basic text responses" do
      assert validate_text_response(123) == %{status: :error, error: :invalid_text_type}
      assert validate_text_response("") == %{status: :error, error: :empty_response}
      assert validate_text_response("Hello world!") == :ok
    end

    test "runs successfully with fixtures" do
      {:ok, openai} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, anthropic} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      {:ok, gpt4o} = LLMDB.model("openai:gpt-4o")

      assert_ok_result(Scenarios.Basic.run("openai:gpt-4o-mini", openai, []), "generate_text")

      assert_ok_result(
        Scenarios.Basic.run("anthropic:claude-sonnet-4-20250514", anthropic, []),
        "generate_text"
      )

      assert_ok_result(Scenarios.Basic.run("openai:gpt-4o", gpt4o, []), "generate_text")
    end
  end

  describe "Streaming" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.Streaming, :streaming, "Streaming")
      assert Scenarios.Streaming.applies?(TestModels.openai())
      assert Scenarios.Streaming.applies?(TestModels.anthropic())

      refute Scenarios.Streaming.applies?(
               TestModels.openai(%{capabilities: %{chat: true, streaming: %{text: false}}})
             )

      refute Scenarios.Streaming.applies?(TestModels.openai_embedding())
      refute Scenarios.Streaming.applies?(nil)
    end

    test "validates streamed text responses" do
      assert validate_text_response(nil) == %{status: :error, error: :invalid_text_type}
      assert validate_text_response("") == %{status: :error, error: :empty_response}
      assert validate_text_response("Hello from streaming!") == :ok
    end

    test "runs successfully with fixtures" do
      {:ok, openai} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, anthropic} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      {:ok, gpt4o} = LLMDB.model("openai:gpt-4o")

      assert_ok_result(Scenarios.Streaming.run("openai:gpt-4o-mini", openai, []), "stream_text")

      assert_ok_result(
        Scenarios.Streaming.run("anthropic:claude-sonnet-4-20250514", anthropic, []),
        "stream_text"
      )

      assert_ok_result(Scenarios.Streaming.run("openai:gpt-4o", gpt4o, []), "stream_text")
    end
  end

  describe "TokenLimit" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.TokenLimit, :token_limit, "Token Limit")
      assert Scenarios.TokenLimit.applies?(TestModels.openai())
      refute Scenarios.TokenLimit.applies?(TestModels.openai_embedding())
      refute Scenarios.TokenLimit.applies?(nil)
    end

    test "validates text token limits" do
      assert validate_word_limited_text([]) == %{status: :error, error: :invalid_text_type}

      assert validate_word_limited_text(String.duplicate("word ", 150) |> String.trim()) == %{
               status: :error,
               error: {:token_limit_exceeded, 150}
             }

      assert validate_word_limited_text("Short response with few words.") == :ok
    end

    test "runs successfully with fixtures" do
      {:ok, openai} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, anthropic} = LLMDB.model("anthropic:claude-sonnet-4-20250514")

      assert_ok_result(
        Scenarios.TokenLimit.run("openai:gpt-4o-mini", openai, []),
        "generate_text"
      )

      assert_ok_result(
        Scenarios.TokenLimit.run("anthropic:claude-sonnet-4-20250514", anthropic, []),
        "generate_text"
      )
    end
  end

  describe "Usage" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.Usage, :usage, "Usage Metrics")
      assert Scenarios.Usage.applies?(TestModels.openai())
      assert Scenarios.Usage.applies?(TestModels.anthropic())
      refute Scenarios.Usage.applies?(TestModels.openai_embedding())
      refute Scenarios.Usage.applies?(nil)
    end

    test "validates usage scenario text responses" do
      assert validate_text_response(%{}) == %{status: :error, error: :invalid_text_type}
      assert validate_text_response("") == %{status: :error, error: :empty_response}
      assert validate_text_response("Hi there!") == :ok
    end

    test "runs successfully with fixtures" do
      {:ok, openai} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, anthropic} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      {:ok, gpt4o} = LLMDB.model("openai:gpt-4o")

      assert_ok_result(Scenarios.Usage.run("openai:gpt-4o-mini", openai, []), "stream_text")

      assert_ok_result(
        Scenarios.Usage.run("anthropic:claude-sonnet-4-20250514", anthropic, []),
        "stream_text"
      )

      assert_ok_result(Scenarios.Usage.run("openai:gpt-4o", gpt4o, []), "stream_text")
    end
  end
end
