defmodule ReqLlmNext.Providers.XAI.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans xAI language models through the provider-local responses family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.xai(),
        :text,
        "Explain the result",
        provider_options: [xai_tools: [ReqLlmNext.XAI.Tools.web_search()]]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :xai_responses_compatible
    assert plan.surface.semantic_protocol == :openai_responses
    assert plan.surface.wire_format == :openai_responses_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.XAI
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.XAIResponses
    assert resolution.wire_mod == ReqLlmNext.Wire.XAIResponses
  end

  test "plans xAI image-generation models onto the shared media family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.xai_image(),
        :image,
        "Generate a mountain sunrise"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :xai_images
    assert plan.surface.semantic_protocol == :openai_images
    assert plan.surface.wire_format == :openai_images_json
    assert resolution.provider_mod == ReqLlmNext.Providers.XAI
    assert resolution.wire_mod == ReqLlmNext.Wire.OpenAIImages
  end
end
