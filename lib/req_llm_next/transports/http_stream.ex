defmodule ReqLlmNext.Transports.HTTPStream do
  @moduledoc false

  alias ExecutionPlane.SSE
  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.Telemetry
  alias ReqLlmNext.Wire.Streaming

  @default_stream_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec stream(
          module(),
          module(),
          module(),
          LLMDB.Model.t(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(provider_mod, protocol_mod, wire_mod, model, prompt, opts) do
    Telemetry.span_provider_request(
      provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod),
      fn ->
        with {:ok, finch_request} <-
               Streaming.build_request(provider_mod, wire_mod, model, prompt, opts) do
          recorder = maybe_start_recorder(model, prompt, finch_request, opts)
          receive_timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)
          stream_state = StreamState.new(recorder, model, wire_mod, protocol_mod)

          stream =
            finch_request
            |> SSE.stream(ReqLlmNext.Finch, receive_timeout: receive_timeout)
            |> Stream.transform(fn -> stream_state end, &handle_stream_item/2, &cleanup/1)

          {:ok, stream}
        end
      end
    )
  end

  defp maybe_start_recorder(model, prompt, finch_request, opts) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.start_recorder(
          model,
          fixture_name,
          prompt,
          finch_request,
          execution_metadata(opts)
        )

      _ ->
        nil
    end
  end

  defp handle_stream_item(message, stream_state) do
    case StreamState.handle_message(message, stream_state) do
      {:cont, chunks, new_stream_state} -> {chunks, new_stream_state}
      {:halt, new_stream_state} -> {:halt, new_stream_state}
    end
  end

  defp cleanup(stream_state) do
    Fixtures.save_fixture(stream_state.recorder)
    :ok
  end

  defp execution_metadata(opts) do
    %{
      surface_id: Keyword.get(opts, :_execution_surface_id),
      semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
      wire_format: Keyword.get(opts, :_execution_wire_format),
      transport: Keyword.get(opts, :_execution_transport)
    }
  end

  defp provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod) do
    Telemetry.provider_request_metadata(model.provider, model, opts, %{
      provider_module: inspect(provider_mod),
      wire_module: inspect(wire_mod),
      protocol_module: inspect(protocol_mod)
    })
  end
end
