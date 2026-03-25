defmodule ReqLlmNext.OpenAI.ClientTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.OpenAI.Client

  setup do
    test_pid = self()
    handler_id = "req-llm-next-openai-client-test-#{System.unique_integer([:positive])}"

    events = [
      [:req_llm_next, :provider, :request, :start],
      [:req_llm_next, :provider, :request, :stop]
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

  test "json_request emits provider telemetry and decodes JSON responses" do
    {:ok, base_url} =
      start_http_server(fn _request ->
        json_response(200, %{"id" => "batch_123", "status" => "queued"})
      end)

    assert {:ok, %{"id" => "batch_123", "status" => "queued"}} =
             Client.json_request(
               :post,
               "/v1/batches",
               %{hello: "world"},
               base_url: base_url,
               api_key: "test-key"
             )

    assert_receive {:utility_request, request}
    assert request.request_line == "POST /v1/batches HTTP/1.1"
    assert request.headers["authorization"] == "Bearer test-key"
    assert request.headers["content-type"] == "application/json"
    assert Jason.decode!(request.body) == %{"hello" => "world"}

    assert_receive {:telemetry_event, [:req_llm_next, :provider, :request, :start], %{},
                    start_metadata}

    assert start_metadata.provider == :openai
    assert start_metadata.utility_path == "/v1/batches"
    assert start_metadata.http_method == :post

    assert_receive {:telemetry_event, [:req_llm_next, :provider, :request, :stop], measurements,
                    stop_metadata}

    assert is_integer(measurements.duration)
    assert stop_metadata.provider == :openai
    assert stop_metadata.provider_request_status == :ok
    assert stop_metadata.utility_path == "/v1/batches"
  end

  test "download_request preserves binary payloads and content type" do
    {:ok, base_url} =
      start_http_server(fn _request ->
        binary_response(200, "audio/mpeg", <<1, 2, 3, 4>>)
      end)

    assert {:ok, response} =
             Client.download_request(
               "/v1/files/file_123/content",
               base_url: base_url,
               api_key: "test-key"
             )

    assert response.data == <<1, 2, 3, 4>>
    assert response.content_type == "audio/mpeg"
  end

  test "parse_jsonl returns a structured parse error for invalid lines" do
    assert {:error, error} =
             Client.parse_jsonl("""
             {"custom_id":"req-1"}
             not-json
             """)

    assert Exception.message(error) =~ "Failed to parse OpenAI JSONL response"
  end

  defp start_http_server(response_fun) when is_function(response_fun, 1) do
    parent = self()

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
        {:ok, socket} = :gen_tcp.accept(listener)
        request = read_request(socket)
        send(parent, {:utility_request, request})
        :ok = :gen_tcp.send(socket, response_fun.(request))
        :gen_tcp.close(socket)
        :gen_tcp.close(listener)
      end)

    on_exit(fn ->
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end)

    {:ok, "http://127.0.0.1:#{port}"}
  end

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
    case String.contains?(acc, "\r\n\r\n") do
      true ->
        {:ok, acc}

      false ->
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

  defp json_response(status, body) do
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

  defp binary_response(status, content_type, body) do
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
end
