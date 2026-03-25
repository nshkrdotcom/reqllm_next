defmodule ReqLlmNext.Providers.Venice.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Venice chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.venice(%{id: "venice-uncensored"}),
        :text,
        "Explain the result",
        provider_options: [enable_web_search: "auto"]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :venice_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Venice
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.VeniceChat
  end
end
