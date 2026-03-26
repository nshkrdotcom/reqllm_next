defmodule ReqLlmNext.Providers.ElevenLabs.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, TestModels}

  test "plans ElevenLabs speech models through the speech family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.elevenlabs_speech(),
        :speech,
        "Hello from ReqLlmNext",
        voice: "voice-123"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :elevenlabs_speech
    assert plan.surface.semantic_protocol == :elevenlabs_speech
    assert plan.surface.wire_format == :elevenlabs_speech_json
    assert resolution.provider_mod == ReqLlmNext.Providers.ElevenLabs
    assert resolution.wire_mod == ReqLlmNext.Wire.ElevenLabsSpeech
  end

  test "plans ElevenLabs transcription models through the transcription family" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.elevenlabs_transcription(),
        :transcription,
        {:binary, "audio-bytes", "audio/mpeg"}
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :elevenlabs_transcriptions
    assert plan.surface.semantic_protocol == :elevenlabs_transcription
    assert plan.surface.wire_format == :elevenlabs_transcription_multipart
    assert resolution.provider_mod == ReqLlmNext.Providers.ElevenLabs
    assert resolution.wire_mod == ReqLlmNext.Wire.ElevenLabsTranscriptions
  end
end
