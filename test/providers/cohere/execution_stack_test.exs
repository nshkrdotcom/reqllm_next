defmodule ReqLlmNext.Providers.Cohere.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, Schema, TestModels}

  test "plans Cohere text generation through the native chat family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.cohere(),
        :text,
        "Explain retrieval augmented generation"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :cohere_chat
    assert plan.surface.semantic_protocol == :cohere_chat
    assert plan.surface.wire_format == :cohere_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Cohere
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.CohereChat
    assert resolution.wire_mod == ReqLlmNext.Wire.CohereChat
  end

  test "plans Cohere object generation through native response_format json schema" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.cohere(),
        :object,
        "Return a person object",
        compiled_schema: Schema.compile!(name: [type: :string])
      )

    assert plan.model.family == :cohere_chat
    assert plan.surface.semantic_protocol == :cohere_chat
    assert plan.surface.features.structured_output == :native_json_schema
  end
end
