defmodule ReqLlmNext.Anthropic.Client do
  @moduledoc """
  Shared low-level HTTP client for Anthropic-specific utility endpoints.
  """

  alias ReqLlmNext.Anthropic.Headers
  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionPlaneHTTP
  alias ReqLlmNext.Providers.Anthropic, as: AnthropicProvider
  alias ReqLlmNext.Telemetry

  @type multipart_part ::
          {:field, String.t(), String.t()}
          | {:file, String.t(), String.t(), String.t(), binary()}

  @spec json_request(atom(), String.t(), map() | nil, keyword()) ::
          {:ok, map()} | {:error, term()}
  def json_request(method, path, body \\ nil, opts \\ []) when method in [:get, :post, :delete] do
    headers = [{"content-type", "application/json"}]
    request(method, path, headers, encode_body(body), opts)
  end

  @spec multipart_request(String.t(), [multipart_part()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def multipart_request(path, parts, opts \\ []) when is_list(parts) do
    {boundary, body} = build_multipart_body(parts)

    request(
      :post,
      path,
      [{"content-type", "multipart/form-data; boundary=#{boundary}"}],
      IO.iodata_to_binary(body),
      opts
    )
  end

  @spec download_request(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download_request(path, opts \\ []) when is_binary(path) do
    with {:ok, %Finch.Response{} = response} <- raw_request(:get, path, [], nil, opts) do
      decode_binary_response(response)
    end
  end

  @spec jsonl_request(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def jsonl_request(path, opts \\ []) when is_binary(path) do
    with {:ok, %Finch.Response{} = response} <-
           raw_request(:get, path, [{"accept", "application/x-ndjson"}], nil, opts) do
      decode_jsonl_response(response)
    end
  end

  @spec raw_request(atom(), String.t(), [{String.t(), String.t()}], binary() | nil, keyword()) ::
          {:ok, Finch.Response.t()} | {:error, term()}
  def raw_request(method, path, headers, body, opts \\ []) do
    Telemetry.span_provider_request(
      provider_request_metadata(method, path, opts),
      fn ->
        api_key = AnthropicProvider.get_api_key(opts)
        url = request_url(path, opts)
        common_headers = common_headers(api_key, opts)
        request = Finch.build(method, url, common_headers ++ headers, body)

        case ExecutionPlaneHTTP.request(
               request,
               receive_timeout: Keyword.get(opts, :receive_timeout, 30_000)
             ) do
          {:ok, %Finch.Response{} = response} ->
            {:ok, response}

          {:error, failure, raw_payload} ->
            {:error,
             Error.API.Request.exception(
               reason: ExecutionPlaneHTTP.transport_reason(failure, raw_payload)
             )}
        end
      end
    )
  end

  @spec build_multipart_body([multipart_part()]) :: {String.t(), iodata()}
  def build_multipart_body(parts) when is_list(parts) do
    boundary = "reqllmnext_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)

    body =
      Enum.flat_map(parts, fn
        {:field, name, value} ->
          [
            "--",
            boundary,
            "\r\n",
            "Content-Disposition: form-data; name=\"",
            name,
            "\"\r\n\r\n",
            value,
            "\r\n"
          ]

        {:file, name, filename, content_type, data} ->
          [
            "--",
            boundary,
            "\r\n",
            "Content-Disposition: form-data; name=\"",
            name,
            "\"; filename=\"",
            filename,
            "\"\r\n",
            "Content-Type: ",
            content_type,
            "\r\n\r\n",
            data,
            "\r\n"
          ]
      end) ++ ["--", boundary, "--\r\n"]

    {boundary, body}
  end

  @doc false
  @spec parse_jsonl(binary()) :: {:ok, [map()]} | {:error, term()}
  def parse_jsonl(body) when is_binary(body) do
    body
    |> String.split("\n", trim: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, decoded} when is_map(decoded) ->
          {:cont, {:ok, [decoded | acc]}}

        {:ok, _decoded} ->
          {:cont, {:ok, acc}}

        {:error, reason} ->
          {:halt,
           {:error,
            Error.API.JsonParse.exception(
              message: "Failed to parse Anthropic JSONL response: #{Exception.message(reason)}",
              raw_json: line
            )}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp request(method, path, headers, body, opts) do
    with {:ok, %Finch.Response{} = response} <- raw_request(method, path, headers, body, opts) do
      decode_json_response(response)
    end
  end

  defp request_url("http://" <> _rest = path, _opts), do: path
  defp request_url("https://" <> _rest = path, _opts), do: path

  defp request_url(path, opts) do
    Keyword.get(opts, :base_url, AnthropicProvider.base_url()) <> path
  end

  defp common_headers(api_key, opts) do
    AnthropicProvider.auth_headers(api_key) ++ Headers.common_headers(opts)
  end

  defp encode_body(nil), do: nil
  defp encode_body(body) when is_map(body), do: Jason.encode!(body)

  defp decode_json_response(%Finch.Response{status: status, body: body})
       when status in 200..299 and body in [nil, ""] do
    {:ok, %{}}
  end

  defp decode_json_response(%Finch.Response{status: status, body: body})
       when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) ->
        {:ok, decoded}

      {:ok, _decoded} ->
        {:ok, %{}}

      {:error, reason} ->
        {:error,
         Error.API.JsonParse.exception(
           message: "Failed to parse Anthropic response: #{Exception.message(reason)}",
           raw_json: body
         )}
    end
  end

  defp decode_json_response(%Finch.Response{status: status, body: body}) do
    {:error,
     Error.API.Request.exception(
       reason: "Anthropic request failed",
       status: status,
       response_body: body
     )}
  end

  defp decode_binary_response(%Finch.Response{status: status, body: body, headers: headers})
       when status in 200..299 and is_binary(body) do
    {:ok, %{data: body, content_type: header_value(headers, "content-type"), headers: headers}}
  end

  defp decode_binary_response(%Finch.Response{status: status, body: body}) do
    {:error,
     Error.API.Request.exception(
       reason: "Anthropic request failed",
       status: status,
       response_body: body
     )}
  end

  defp decode_jsonl_response(%Finch.Response{status: status, body: body})
       when status in 200..299 and is_binary(body) do
    parse_jsonl(body)
  end

  defp decode_jsonl_response(%Finch.Response{status: status, body: body}) do
    {:error,
     Error.API.Request.exception(
       reason: "Anthropic request failed",
       status: status,
       response_body: body
     )}
  end

  defp header_value(headers, name) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == String.downcase(name), do: value, else: nil
    end)
  end

  defp provider_request_metadata(method, path, opts) do
    Telemetry.provider_request_metadata(:anthropic, nil, opts, %{
      http_method: method,
      utility_path: path
    })
  end
end
