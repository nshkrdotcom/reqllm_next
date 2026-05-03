defmodule ReqLlmNext.Transports.OpenAIResponsesWebSocket do
  @moduledoc false

  alias ExecutionPlane.WebSocket
  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Telemetry

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
        timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)

        with {:ok, request_info, payload, auth_headers, ws_path} <-
               build_request_info(provider_mod, wire_mod, model, prompt, opts),
             recorder <- maybe_start_recorder(model, prompt, request_info, opts),
             {:ok, %{status: status, headers: headers, stream: websocket_stream}} <-
               open_connection(provider_mod, auth_headers, ws_path, payload, timeout) do
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

  defp build_request_info(provider_mod, wire_mod, model, prompt, opts) do
    payload = wire_mod.encode_websocket_event(model, prompt, opts)
    ws_path = wire_mod.path()

    with {:ok, request_url} <- Provider.request_url(provider_mod, model, ws_path, opts),
         {:ok, auth_headers} <- Provider.request_headers(provider_mod, model, opts) do
      ws_url = to_websocket_url(request_url)

      request_info = %{
        "method" => "WEBSOCKET",
        "url" => ws_url,
        "transport" => "websocket",
        "headers" => auth_headers,
        "body" => payload
      }

      {:ok, request_info, payload, auth_headers, ws_url}
    end
  end

  defp maybe_start_recorder(model, prompt, request_info, opts) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.start_recorder(
          model,
          fixture_name,
          prompt,
          request_info,
          execution_metadata(opts)
        )

      _ ->
        nil
    end
  end

  defp open_connection(_provider_mod, auth_headers, ws_url, payload, timeout) do
    WebSocket.stream(ws_url, auth_headers, [Jason.encode!(payload)], receive_timeout: timeout)
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

  defp to_websocket_url("https://" <> rest), do: "wss://" <> rest
  defp to_websocket_url("http://" <> rest), do: "ws://" <> rest
  defp to_websocket_url(url), do: url

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
