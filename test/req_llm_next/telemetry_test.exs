defmodule ReqLlmNext.TelemetryTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.{
    Context,
    ExecutionModules,
    GovernedAuthority,
    OperationPlanner,
    Response,
    Telemetry
  }

  alias ReqLlmNext.TestModels

  setup do
    test_pid = self()
    handler_id = "req-llm-next-telemetry-test-#{System.unique_integer([:positive])}"

    events = [
      [:req_llm_next, :request, :start],
      [:req_llm_next, :request, :stop],
      [:req_llm_next, :plan, :resolved],
      [:req_llm_next, :execution, :stack],
      [:req_llm_next, :stream, :start],
      [:req_llm_next, :stream, :chunk],
      [:req_llm_next, :stream, :stop]
    ]

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_event/4,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  def handle_event(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end

  test "request spans sanitize payload metadata and emit usage measurements" do
    context = Context.normalize!("hello")
    model = TestModels.openai()

    result =
      Telemetry.span_request(
        %{operation: :text, prompt: "secret prompt", reasoning: "hidden"},
        fn ->
          {:ok,
           Response.new!(%{
             id: "resp_123",
             model: model,
             context: context,
             message: nil,
             usage: %{input_tokens: 10, output_tokens: 3, total_tokens: 13, reasoning_tokens: 2},
             finish_reason: :stop
           })}
        end
      )

    assert {:ok, %Response{finish_reason: :stop}} = result

    assert_receive {:telemetry_event, [:req_llm_next, :request, :start], %{}, start_metadata}
    refute Map.has_key?(start_metadata, :prompt)
    refute Map.has_key?(start_metadata, :reasoning)
    assert start_metadata.operation == :text

    assert_receive {:telemetry_event, [:req_llm_next, :request, :stop], measurements,
                    stop_metadata}

    assert measurements.input_tokens == 10
    assert measurements.output_tokens == 3
    assert measurements.total_tokens == 13
    assert measurements.reasoning_tokens == 2
    assert is_integer(measurements.duration)
    assert stop_metadata.finish_reason == :stop
    assert stop_metadata.request_status == :ok
  end

  test "planner and execution resolution emit canonical metadata" do
    model = TestModels.openai_reasoning()

    {:ok, plan} = OperationPlanner.plan(model, :text, "hello", _model_spec: "openai:o1-test")
    resolution = ExecutionModules.resolve(plan)

    assert resolution.provider_mod == ReqLlmNext.Providers.OpenAI

    assert_receive {:telemetry_event, [:req_llm_next, :plan, :resolved], plan_measurements,
                    plan_metadata}

    assert is_integer(plan_measurements.fallback_surface_count)
    assert plan_measurements.fallback_surface_count >= 0
    assert plan_metadata.provider == :openai
    assert plan_metadata.model_id == "o1-test"
    assert plan_metadata.semantic_protocol == :openai_responses

    assert_receive {:telemetry_event, [:req_llm_next, :execution, :stack], %{}, stack_metadata}
    assert stack_metadata.provider == :openai

    assert stack_metadata.transport_module in [
             "ReqLlmNext.Transports.HTTPRequest",
             "ReqLlmNext.Transports.HTTPStream",
             "ReqLlmNext.Transports.OpenAIResponsesWebSocket"
           ]

    assert stack_metadata.wire_module == "ReqLlmNext.Wire.OpenAIResponses"
  end

  test "planner telemetry carries governed token refs without materialized secrets" do
    model = TestModels.openai()

    assert {:ok, _plan} =
             OperationPlanner.plan(
               model,
               :text,
               "hello",
               governed_authority: authority()
             )

    assert_receive {:telemetry_event, [:req_llm_next, :plan, :resolved], _measurements, metadata}

    assert metadata.authority_refs.provider_key_ref == "provider-key://openai/default"
    assert metadata.authority_refs.credential_ref == "credential://reqllm/openai/default"
    assert metadata.authority_refs.stream_ref == "stream://openai/default"
    refute inspect(metadata) =~ "governed-credential"
    refute inspect(metadata) =~ "https://governed.example"
  end

  test "instrumented streams emit lifecycle events and finish metadata" do
    stream =
      ["Hello", {:thinking, "world"}, {:meta, %{finish_reason: :stop, terminal?: true}}]
      |> Telemetry.instrument_stream(%{operation: :text, prompt: "hidden"})

    assert Enum.to_list(stream) == [
             "Hello",
             {:thinking, "world"},
             {:meta, %{finish_reason: :stop, terminal?: true}}
           ]

    assert_receive {:telemetry_event, [:req_llm_next, :stream, :start], %{}, start_metadata}
    refute Map.has_key?(start_metadata, :prompt)
    assert start_metadata.operation == :text

    assert_receive {:telemetry_event, [:req_llm_next, :stream, :chunk], chunk_measurements_1,
                    chunk_metadata_1}

    assert chunk_measurements_1.chunk_count == 1
    assert chunk_metadata_1.event_type == :text

    assert_receive {:telemetry_event, [:req_llm_next, :stream, :chunk], chunk_measurements_2,
                    chunk_metadata_2}

    assert chunk_measurements_2.chunk_count == 2
    assert chunk_metadata_2.event_type == :thinking

    assert_receive {:telemetry_event, [:req_llm_next, :stream, :chunk], chunk_measurements_3,
                    chunk_metadata_3}

    assert chunk_measurements_3.chunk_count == 3
    assert chunk_metadata_3.finish_reason == :stop

    assert_receive {:telemetry_event, [:req_llm_next, :stream, :stop], stop_measurements,
                    stop_metadata}

    assert stop_measurements.chunk_count == 3
    assert stop_metadata.finish_reason == :stop
  end

  defp authority do
    GovernedAuthority.new!(
      base_url: "https://governed.example",
      credential_ref: "credential://reqllm/openai/default",
      credential_lease_ref: "lease://reqllm/openai/default",
      provider_key_ref: "provider-key://openai/default",
      base_url_ref: "base-url://openai/default",
      target_ref: "target://reqllm/openai/default",
      operation_policy_ref: "operation-policy://reqllm/openai/read",
      cleanup_policy_ref: "cleanup-policy://reqllm/openai/default",
      redaction_ref: "redaction://reqllm/default",
      provider_ref: "provider://openai",
      provider_account_ref: "provider-account://openai/default",
      endpoint_account_ref: "endpoint-account://openai/default",
      model_account_ref: "model-account://openai/default",
      organization_ref: "organization://openai/default",
      project_ref: "project://openai/default",
      realtime_session_ref: "realtime-session://openai/default",
      realtime_session_token_ref: "realtime-token://openai/default",
      reconnect_token_ref: "reconnect-token://openai/default",
      stream_ref: "stream://openai/default",
      revocation_epoch: 7,
      headers: [{"authorization", "governed-credential"}],
      query: %{},
      template_values: %{}
    )
  end
end
