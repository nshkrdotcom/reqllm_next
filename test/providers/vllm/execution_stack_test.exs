defmodule ReqLlmNext.Providers.VLLM.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans vLLM models through the shared OpenAI-compatible family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.vllm(),
        :text,
        "Explain the result",
        base_url: "http://example.test:8001/v1"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :openai_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.VLLM
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.OpenAIChat
  end
end
