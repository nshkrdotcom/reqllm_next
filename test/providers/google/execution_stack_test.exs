defmodule ReqLlmNext.Providers.Google.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Gemini models through the native generateContent family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.google(%{id: "gemini-2.5-flash"}),
        :text,
        "Explain the result",
        provider_options: [google_thinking_budget: 512]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :google_generate_content
    assert plan.surface.semantic_protocol == :google_generate_content
    assert plan.surface.wire_format == :google_generate_content_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Google
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.GoogleGenerateContent
    assert resolution.wire_mod == ReqLlmNext.Wire.GoogleGenerateContent
  end

  test "plans Gemini object generation through the same native family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.google(%{id: "gemini-2.5-flash"}),
        :object,
        "Return a person object",
        compiled_schema: ReqLlmNext.Schema.compile!(name: [type: :string])
      )

    assert plan.model.family == :google_generate_content
    assert plan.surface.semantic_protocol == :google_generate_content
    assert plan.surface.features.structured_output == :native_json_schema
  end
end
