defmodule ReqLlmNext.BestEffortRuntimeTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.{
    ExecutionModules,
    ModelProfile,
    OperationPlanner,
    Provider,
    RuntimeMetadata
  }

  alias ReqLlmNext.Providers.Generic

  test "builds model profiles from typed execution metadata for best-effort providers" do
    model = best_effort_model!(:mistral)
    {:ok, profile} = ModelProfile.from_model(model)

    assert profile.family == :openai_chat_compatible

    assert [%{id: :openai_chat_text_http_sse, family: :openai_chat_compatible}] =
             ModelProfile.surfaces_for(profile, :text)
  end

  test "plans and resolves a generic best-effort execution stack" do
    model = best_effort_model!(:mistral)

    assert {:ok, plan} = OperationPlanner.plan(model, :text, "Hello", _stream?: true)

    assert plan.provider == :mistral
    assert plan.surface.id == :openai_chat_text_http_sse
    assert plan.surface.family == :openai_chat_compatible
    assert plan.semantic_protocol == :openai_chat
    assert plan.wire_format == :openai_chat_sse_json
    assert plan.transport == :http_sse

    assert %{
             provider_mod: Generic,
             session_runtime_mod: ReqLlmNext.SessionRuntimes.None,
             protocol_mod: ReqLlmNext.SemanticProtocols.OpenAIChat,
             wire_mod: ReqLlmNext.Wire.OpenAIChat,
             transport_mod: ReqLlmNext.Transports.HTTPStream
           } = ExecutionModules.resolve(plan)
  end

  test "builds generic provider request URLs and auth headers from runtime metadata" do
    model = best_effort_model!(:mistral)
    {:ok, runtime} = RuntimeMetadata.provider_runtime(model)
    {:ok, execution_entry} = RuntimeMetadata.execution_entry(model, :text)

    ReqLlmNext.Env.put("MISTRAL_API_KEY", "test-mistral-key")

    on_exit(fn ->
      ReqLlmNext.Env.delete("MISTRAL_API_KEY")
    end)

    opts = [
      _use_runtime_metadata: true,
      _provider_runtime: runtime,
      _model_execution_entry: execution_entry
    ]

    assert {:ok, url} = Provider.request_url(Generic, model, "/unused", opts)
    assert url == "https://api.mistral.ai/v1/chat/completions"

    assert {:ok, headers} =
             Provider.request_headers(Generic, model, opts, [{"Content-Type", "application/json"}])

    assert {"Authorization", "Bearer test-mistral-key"} in headers
    assert {"Content-Type", "application/json"} in headers
  end

  defp best_effort_model!(provider) do
    provider
    |> LLMDB.models()
    |> Enum.find(&(ReqLlmNext.support_status(&1) == :best_effort))
    |> case do
      %LLMDB.Model{} = model -> model
      nil -> flunk("expected a best-effort model for #{inspect(provider)}")
    end
  end
end
