defmodule ReqLlmNext.Providers.OpenRouter.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans OpenRouter chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.openrouter(%{id: "openai/gpt-4o-mini"}),
        :text,
        "Explain the result",
        provider_options: [openrouter_route: "fallback"]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :openrouter_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.OpenRouter
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.OpenRouterChat
  end
end
