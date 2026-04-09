defmodule ReqLlmNext.OpenAI.Realtime.Transport do
  @moduledoc false

  alias ExecutionPlane.WebSocket
  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.OpenAI.Realtime.Wire
  alias ReqLlmNext.Telemetry

  @default_stream_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec stream(module(), module(), module(), LLMDB.Model.t(), [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(provider_mod, protocol_mod, wire_mod, model, client_events, opts) do
    Telemetry.span_provider_request(
      provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod),
      fn ->
        timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)
        ws_url = Wire.websocket_url(provider_mod.base_url(), model, opts)
        auth_headers = provider_mod.auth_headers(provider_mod.get_api_key(opts))
        payloads = Enum.map(client_events, &Jason.encode!(wire_mod.encode_client_event(&1)))

        recorder =
          case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
            {:record, fixture_name} when is_binary(fixture_name) ->
              Fixtures.start_recorder(
                model,
                fixture_name,
                client_events,
                %{
                  "method" => "WEBSOCKET",
                  "url" => ws_url,
                  "transport" => "websocket",
                  "headers" => auth_headers,
                  "body" => client_events
                },
                %{
                  surface_id: :openai_realtime,
                  semantic_protocol: :openai_realtime,
                  wire_format: :openai_realtime_json,
                  transport: :websocket
                }
              )

            _ ->
              nil
          end

        with {:ok, %{status: status, headers: headers, stream: websocket_stream}} <-
               WebSocket.stream(ws_url, auth_headers, payloads, receive_timeout: timeout) do
          recorder =
            recorder
            |> Fixtures.record_status(status)
            |> Fixtures.record_headers(headers)

          stream_state = StreamState.new(recorder, model, wire_mod, protocol_mod)

          stream =
            websocket_stream
            |> Stream.transform(fn -> stream_state end, &handle_stream_item/2, &cleanup/1)

          {:ok, stream}
        end
      end
    )
  end

  defp handle_stream_item({:frame, {:text, payload}}, stream_state) do
    handle_stream_result(StreamState.handle_message({:frame, payload}, stream_state))
  end

  defp handle_stream_item({:frame, {:binary, payload}}, stream_state) do
    handle_stream_result(
      StreamState.handle_message(
        {:transport_error, {:unexpected_binary_frame, byte_size(payload)}},
        stream_state
      )
    )
  end

  defp handle_stream_item(message, stream_state) do
    handle_stream_result(StreamState.handle_message(message, stream_state))
  end

  defp handle_stream_result({:cont, chunks, new_stream_state}) do
    {chunks, new_stream_state}
  end

  defp handle_stream_result({:halt, new_stream_state}) do
    {:halt, new_stream_state}
  end

  defp cleanup(stream_state) do
    Fixtures.save_fixture(stream_state.recorder)
    :ok
  end

  defp provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod) do
    Telemetry.provider_request_metadata(model.provider, model, opts, %{
      provider_module: inspect(provider_mod),
      wire_module: inspect(wire_mod),
      protocol_module: inspect(protocol_mod),
      realtime?: true
    })
  end
end
