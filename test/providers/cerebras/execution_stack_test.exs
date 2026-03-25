defmodule ReqLlmNext.Providers.Cerebras.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Cerebras chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.cerebras(%{id: "llama3.1-8b"}),
        :text,
        "Explain the result"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :cerebras_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Cerebras
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.CerebrasChat
  end
end
