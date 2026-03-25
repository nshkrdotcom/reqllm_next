defmodule ReqLlmNext.Providers.DeepSeek.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans DeepSeek models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.deepseek_reasoning(),
        :text,
        "Explain the result",
        thinking: %{type: "enabled"}
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :deepseek_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.DeepSeek
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.DeepSeekChat
    assert resolution.wire_mod == ReqLlmNext.Wire.DeepSeekChat
  end
end
