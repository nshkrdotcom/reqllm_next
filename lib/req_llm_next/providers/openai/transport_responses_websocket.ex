defmodule ReqLlmNext.Transports.OpenAIResponsesWebSocket do
  @moduledoc false

  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures

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
    timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)

    with {:ok, request_info, payload, auth_headers, ws_path} <-
           build_request_info(provider_mod, wire_mod, model, prompt, opts),
         recorder <- maybe_start_recorder(model, prompt, request_info, opts),
         {:ok, conn, ref, websocket, recorder} <-
           open_connection(provider_mod, auth_headers, ws_path, payload, recorder, timeout) do
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

  defp build_request_info(provider_mod, wire_mod, model, prompt, opts) do
    payload = wire_mod.encode_websocket_event(model, prompt, opts)
    api_key = provider_mod.get_api_key(opts)
    auth_headers = provider_mod.auth_headers(api_key)
    base_url = provider_mod.base_url()
    ws_path = wire_mod.path()
    ws_url = base_url |> String.replace_prefix("https://", "wss://") |> Kernel.<>(ws_path)

    request_info = %{
      "method" => "WEBSOCKET",
      "url" => ws_url,
      "transport" => "websocket",
      "headers" => auth_headers,
      "body" => payload
    }

    {:ok, request_info, payload, auth_headers, ws_path}
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

  defp open_connection(provider_mod, auth_headers, ws_path, payload, recorder, timeout) do
    uri = URI.parse(provider_mod.base_url())
    port = uri.port || default_port(uri.scheme)

    with {:ok, conn} <-
           Mint.HTTP.connect(String.to_atom(uri.scheme), uri.host, port,
             mode: :passive,
             protocols: [:http1]
           ),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(:wss, conn, ws_path, auth_headers),
         {:ok, conn, status, headers} <- await_upgrade(conn, ref, timeout),
         {:ok, conn, websocket} <- Mint.WebSocket.new(conn, ref, status, headers, mode: :passive),
         {:ok, websocket, data} <- encode_text_frame(websocket, Jason.encode!(payload)),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(conn, ref, data) do
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
          {:status, ^ref, status}, state ->
            %{state | status: status}

          {:headers, ^ref, headers}, state ->
            %{state | headers: headers}

          {:done, ^ref}, state ->
            %{state | done?: true}

          _other, state ->
            state
        end)

      if acc.status && acc.headers && acc.done? do
        {:ok, conn, acc.status, acc.headers}
      else
        await_upgrade(conn, ref, timeout, acc)
      end
    end
  end

  defp next_chunk(%{done?: true} = state) do
    Fixtures.save_fixture(state.stream_state.recorder)
    {:halt, state}
  end

  defp next_chunk(%{conn: conn, ref: ref, websocket: websocket, receive_timeout: timeout} = state) do
    case Mint.WebSocket.recv(conn, 0, timeout) do
      {:ok, conn, responses} ->
        handle_responses(%{state | conn: conn}, websocket, ref, responses)

      {:error, _recv_state, reason, _responses} ->
        error_chunk =
          {:error,
           %{message: "WebSocket receive failed: #{inspect(reason)}", type: "transport_error"}}

        {[error_chunk], %{state | done?: true}}
    end
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
        with {:ok, websocket, pong} <- encode_pong_frame(websocket, payload),
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

  defp default_port("https"), do: 443
  defp default_port("http"), do: 80

  @spec encode_text_frame(Mint.WebSocket.t(), String.t()) ::
          {:ok, Mint.WebSocket.t(), bitstring()} | {:error, Mint.WebSocket.t(), term()}
  defp encode_text_frame(websocket, payload) when is_binary(payload) do
    Mint.WebSocket.encode(websocket, {:text, payload})
  end

  @spec encode_pong_frame(Mint.WebSocket.t(), binary()) ::
          {:ok, Mint.WebSocket.t(), bitstring()} | {:error, Mint.WebSocket.t(), term()}
  defp encode_pong_frame(websocket, payload) when is_binary(payload) do
    Mint.WebSocket.encode(websocket, {:pong, payload})
  end

  defp execution_metadata(opts) do
    %{
      surface_id: Keyword.get(opts, :_execution_surface_id),
      semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
      wire_format: Keyword.get(opts, :_execution_wire_format),
      transport: Keyword.get(opts, :_execution_transport)
    }
  end
end
