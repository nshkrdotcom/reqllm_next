defmodule ReqLlmNext.OpenAI.Realtime.Transport do
  @moduledoc false

  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.OpenAI.Realtime.Wire

  @default_stream_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec stream(module(), module(), module(), LLMDB.Model.t(), [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(provider_mod, protocol_mod, wire_mod, model, client_events, opts) do
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

    with {:ok, conn, ref, websocket, recorder} <-
           open_connection(ws_url, auth_headers, payloads, recorder, timeout) do
      stream =
        Stream.resource(
          fn ->
            %{
              conn: conn,
              ref: ref,
              websocket: websocket,
              stream_state: StreamState.new(recorder, model, wire_mod, protocol_mod),
              receive_timeout: timeout,
              done?: false
            }
          end,
          &next_chunk/1,
          &cleanup/1
        )

      {:ok, stream}
    end
  end

  defp open_connection(ws_url, auth_headers, payloads, recorder, timeout) do
    uri = URI.parse(ws_url)
    path = uri.path <> if(uri.query, do: "?" <> uri.query, else: "")
    port = uri.port || 443

    with {:ok, conn} <-
           Mint.HTTP.connect(:https, uri.host, port, mode: :passive, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(:wss, conn, path, auth_headers),
         {:ok, conn, status, headers} <- await_upgrade(conn, ref, timeout),
         {:ok, conn, websocket} <- Mint.WebSocket.new(conn, ref, status, headers, mode: :passive),
         {:ok, conn, websocket} <- send_payloads(conn, ref, websocket, payloads) do
      recorder =
        recorder
        |> Fixtures.record_status(status)
        |> Fixtures.record_headers(headers)

      {:ok, conn, ref, websocket, recorder}
    end
  end

  defp await_upgrade(conn, ref, timeout, acc \\ %{status: nil, headers: nil, done?: false}) do
    with {:ok, conn, responses} <- Mint.WebSocket.recv(conn, 0, timeout) do
      acc =
        Enum.reduce(responses, acc, fn
          {:status, ^ref, status}, state -> %{state | status: status}
          {:headers, ^ref, headers}, state -> %{state | headers: headers}
          {:done, ^ref}, state -> %{state | done?: true}
          _other, state -> state
        end)

      if acc.status && acc.headers && acc.done? do
        {:ok, conn, acc.status, acc.headers}
      else
        await_upgrade(conn, ref, timeout, acc)
      end
    end
  end

  defp send_payloads(conn, ref, websocket, payloads) do
    Enum.reduce_while(payloads, {:ok, conn, websocket}, fn payload,
                                                           {:ok, current_conn, current_ws} ->
      with {:ok, next_ws, data} <- Mint.WebSocket.encode(current_ws, {:text, payload}),
           {:ok, next_conn} <- Mint.WebSocket.stream_request_body(current_conn, ref, data) do
        {:cont, {:ok, next_conn, next_ws}}
      else
        {:error, _transport_state, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp next_chunk(%{done?: true} = state) do
    Fixtures.save_fixture(state.stream_state.recorder)
    {:halt, state}
  end

  defp next_chunk(%{conn: conn, ref: ref, websocket: websocket, receive_timeout: timeout} = state) do
    {:ok, conn, responses} = Mint.WebSocket.recv(conn, 0, timeout)
    handle_responses(%{state | conn: conn}, websocket, ref, responses)
  end

  defp handle_responses(state, websocket, ref, responses) do
    case Enum.reduce_while(responses, {:ok, state, websocket, []}, fn response,
                                                                      {:ok, current_state,
                                                                       current_ws, acc} ->
           case handle_response(response, current_state, current_ws, ref) do
             {:ok, next_state, next_ws, chunks} ->
               {:cont, {:ok, next_state, next_ws, acc ++ chunks}}

             {:halt, next_state, next_ws, chunks} ->
               {:halt, {:halt, next_state, next_ws, acc ++ chunks}}
           end
         end) do
      {:ok, next_state, next_ws, []} ->
        next_chunk(%{next_state | websocket: next_ws})

      {:ok, next_state, next_ws, chunks} ->
        {chunks, %{next_state | websocket: next_ws}}

      {:halt, next_state, next_ws, chunks} ->
        {chunks, %{next_state | websocket: next_ws, done?: true}}
    end
  end

  defp handle_response({:data, ref, data}, state, websocket, ref) do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        handle_frames(frames, state, websocket, ref, [])

      {:error, websocket, reason} ->
        chunks = [
          {:error,
           %{message: "WebSocket decode failed: #{inspect(reason)}", type: "transport_error"}}
        ]

        {:halt, state, websocket, chunks}
    end
  end

  defp handle_response(_response, state, websocket, _ref), do: {:ok, state, websocket, []}

  defp handle_frames([], state, websocket, _ref, chunks), do: {:ok, state, websocket, chunks}

  defp handle_frames([frame | rest], state, websocket, ref, chunks) do
    case frame do
      {:text, payload} ->
        case StreamState.handle_message({:frame, payload}, state.stream_state) do
          {:cont, frame_chunks, new_stream_state} ->
            next_state = %{state | stream_state: new_stream_state}

            if terminal_chunks?(frame_chunks) do
              {:halt, next_state, websocket, chunks ++ frame_chunks}
            else
              handle_frames(rest, next_state, websocket, ref, chunks ++ frame_chunks)
            end
        end

      {:ping, payload} ->
        with {:ok, websocket, pong} <- Mint.WebSocket.encode(websocket, {:pong, payload}),
             {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, ref, pong) do
          handle_frames(rest, %{state | conn: conn}, websocket, ref, chunks)
        else
          {:error, _transport_state, _reason} ->
            error_chunk =
              {:error, %{message: "Failed to reply to WebSocket ping", type: "transport_error"}}

            {:halt, state, websocket, chunks ++ [error_chunk]}
        end

      {:close, _code, _reason} ->
        {:halt, state, websocket, chunks}

      _other ->
        handle_frames(rest, state, websocket, ref, chunks)
    end
  end

  defp cleanup(%{conn: conn, stream_state: stream_state}) do
    Fixtures.save_fixture(stream_state.recorder)
    Mint.HTTP.close(conn)
    :ok
  end

  defp terminal_chunks?(chunks) do
    Enum.any?(chunks, fn
      {:meta, %{terminal?: true}} -> true
      _ -> false
    end)
  end
end
