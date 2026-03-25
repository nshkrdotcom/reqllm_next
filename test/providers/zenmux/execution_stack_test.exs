defmodule ReqLlmNext.Providers.Zenmux.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Zenmux language models through the provider-local Responses family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.zenmux(),
        :text,
        "Explain the result",
        provider_options: [verbosity: "high"]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :zenmux_responses_compatible
    assert plan.surface.semantic_protocol == :openai_responses
    assert plan.surface.wire_format == :openai_responses_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Zenmux
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIResponses
    assert resolution.wire_mod == ReqLlmNext.Wire.ZenmuxResponses
  end

  test "plans explicit chat-only Zenmux models through the chat family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.zenmux(%{extra: %{api: "chat"}}),
        :text,
        "Explain the result",
        provider_options: [web_search_options: %{search_context_size: "medium"}]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :zenmux_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Zenmux
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.ZenmuxChat
    assert resolution.wire_mod == ReqLlmNext.Wire.ZenmuxChat
  end
end
