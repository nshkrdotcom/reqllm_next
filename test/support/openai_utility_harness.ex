defmodule ReqLlmNext.TestSupport.OpenAIUtilityHarness do
  @moduledoc false

  @type request :: %{
          request_line: String.t(),
          headers: %{optional(String.t()) => String.t()},
          body: binary()
        }

  @type server :: %{base_url: String.t(), pid: pid()}

  @spec start_server(pid(), [iodata() | (request() -> iodata())]) :: {:ok, server()}
  def start_server(owner, handlers) when is_pid(owner) and is_list(handlers) and handlers != [] do
    {:ok, listener} =
      :gen_tcp.listen(0, [
        :binary,
        active: false,
        packet: :raw,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, port} = :inet.port(listener)

    pid =
      spawn_link(fn ->
        Enum.with_index(handlers, 1)
        |> Enum.each(fn {handler, index} ->
          {:ok, socket} = :gen_tcp.accept(listener)
          request = read_request(socket)
          send(owner, {:utility_request, index, request})
          :ok = :gen_tcp.send(socket, render_response(handler, request))
          :gen_tcp.close(socket)
        end)

        :gen_tcp.close(listener)
      end)

    {:ok, %{base_url: "http://127.0.0.1:#{port}", pid: pid}}
  end

  @spec stop_server(server()) :: :ok
  def stop_server(%{pid: pid}) when is_pid(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
    end

    :ok
  end

  @spec json_response(pos_integer(), map()) :: iodata()
  def json_response(status, body) when is_integer(status) and is_map(body) do
    encoded = Jason.encode!(body)

    [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " OK\r\n",
      "content-type: application/json\r\n",
      "content-length: ",
      Integer.to_string(byte_size(encoded)),
      "\r\n",
      "connection: close\r\n\r\n",
      encoded
    ]
  end

  @spec binary_response(pos_integer(), String.t(), binary()) :: iodata()
  def binary_response(status, content_type, body)
      when is_integer(status) and is_binary(content_type) and is_binary(body) do
    [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " OK\r\n",
      "content-type: ",
      content_type,
      "\r\n",
      "content-length: ",
      Integer.to_string(byte_size(body)),
      "\r\n",
      "connection: close\r\n\r\n",
      body
    ]
  end

  defp render_response(handler, request) when is_function(handler, 1), do: handler.(request)
  defp render_response(response, _request), do: response

  defp read_request(socket) do
    {:ok, payload} = recv_until_headers(socket, "")
    [header_block, body_prefix] = String.split(payload, "\r\n\r\n", parts: 2)
    [request_line | header_lines] = String.split(header_block, "\r\n", trim: true)

    headers =
      Enum.reduce(header_lines, %{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [key, value] -> Map.put(acc, String.downcase(key), String.trim(value))
          _ -> acc
        end
      end)

    content_length =
      headers
      |> Map.get("content-length", "0")
      |> String.to_integer()

    %{
      request_line: request_line,
      headers: headers,
      body: recv_body(socket, body_prefix, content_length)
    }
  end

  defp recv_until_headers(socket, acc) do
    if String.contains?(acc, "\r\n\r\n") do
      {:ok, acc}
    else
      with {:ok, data} <- :gen_tcp.recv(socket, 0, 1_000) do
        recv_until_headers(socket, acc <> data)
      end
    end
  end

  defp recv_body(_socket, body, expected_length) when byte_size(body) >= expected_length do
    binary_part(body, 0, expected_length)
  end

  defp recv_body(socket, body, expected_length) do
    with {:ok, remainder} <- :gen_tcp.recv(socket, expected_length - byte_size(body), 1_000) do
      recv_body(socket, body <> remainder, expected_length)
    end
  end
end
