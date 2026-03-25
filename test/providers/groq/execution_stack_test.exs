defmodule ReqLlmNext.Providers.Groq.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans Groq chat models through the provider-local family overrides" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.groq(),
        :text,
        "Explain the result",
        provider_options: [service_tier: "flex"]
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :groq_chat_compatible
    assert plan.surface.semantic_protocol == :openai_chat
    assert plan.surface.wire_format == :openai_chat_sse_json
    assert resolution.provider_mod == ReqLlmNext.Providers.Groq
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIChat
    assert resolution.wire_mod == ReqLlmNext.Wire.GroqChat
  end

  test "plans Groq transcription models onto the shared media family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.groq_transcription(),
        :transcription,
        {:binary, "audio", "audio/mpeg"}
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :groq_transcriptions
    assert plan.surface.semantic_protocol == :openai_transcription
    assert plan.surface.wire_format == :openai_transcription_multipart
    assert resolution.provider_mod == ReqLlmNext.Providers.Groq
    assert resolution.wire_mod == ReqLlmNext.Wire.OpenAITranscriptions
  end
end
