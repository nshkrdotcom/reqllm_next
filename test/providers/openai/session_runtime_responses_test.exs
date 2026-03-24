defmodule ReqLlmNext.SessionRuntimes.OpenAIResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionPlan, Response}
  alias ReqLlmNext.SessionRuntimes.OpenAIResponses

  defp plan(session_mode) do
    ExecutionPlan.new!(%{
      model: %{},
      mode: %{},
      surface: %{},
      provider: :openai,
      session_runtime: :openai_responses,
      semantic_protocol: :openai_responses,
      wire_format: :openai_responses_sse_json,
      transport: :http_sse,
      parameter_values: %{},
      session_strategy: %{mode: session_mode}
    })
  end

  test "passes through opts when session mode is none" do
    assert {:ok, [temperature: 0.1]} =
             OpenAIResponses.prepare(plan(:none), [], temperature: 0.1)
  end

  test "derives previous_response_id from continue_from response for preferred sessions" do
    response =
      %Response{
        id: "resp_local",
        model: %LLMDB.Model{id: "gpt-4o-mini", provider: :openai},
        context: ReqLlmNext.Context.new(),
        message: nil,
        usage: nil,
        finish_reason: nil,
        provider_meta: %{response_id: "resp_123"}
      }

    assert {:ok, runtime_opts} =
             OpenAIResponses.prepare(
               plan(:preferred),
               [continue_from: response],
               max_tokens: 10
             )

    assert runtime_opts[:previous_response_id] == "resp_123"
  end

  test "requires a continuation source when session mode is continue" do
    assert {:error, %ReqLlmNext.Error.Invalid.Parameter{} = error} =
             OpenAIResponses.prepare(plan(:continue), [], [])

    assert Exception.message(error) =~ "continue_from or previous_response_id is required"
  end

  test "preserves explicit previous_response_id when already present" do
    assert {:ok, runtime_opts} =
             OpenAIResponses.prepare(
               plan(:required),
               [continue_from: "resp_ignored"],
               previous_response_id: "resp_explicit"
             )

    assert runtime_opts[:previous_response_id] == "resp_explicit"
  end
end
