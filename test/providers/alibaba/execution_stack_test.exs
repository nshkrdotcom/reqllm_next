defmodule ReqLlmNext.Providers.Alibaba.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Alibaba chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.alibaba(%{id: "qwen-plus"}),
        :text,
        "Explain the result",
        provider_options: [enable_search: true]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :alibaba_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Alibaba
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.AlibabaChat
  end
end
