defmodule ReqLlmNext.Providers.ZAI.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Z.AI chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.zai(%{id: "glm-4.6"}),
        :text,
        "Explain the result",
        provider_options: [thinking: %{type: "disabled"}]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :zai_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.ZAI
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.ZAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.ZAIChat
  end
end
