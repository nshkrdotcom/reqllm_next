defmodule ReqLlmNext.OpenAI.Client do
  @moduledoc """
  Shared low-level HTTP client for OpenAI-specific utility endpoints.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionPlaneHTTP
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers.OpenAI, as: OpenAIProvider
  alias ReqLlmNext.Telemetry

  @type multipart_part ::
          {:field, String.t(), String.t()}
          | {:file, String.t(), String.t(), String.t(), binary()}

  @spec json_request(atom(), String.t(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def json_request(method, path, body \\ nil, opts \\ []) when method in [:get, :post, :delete] do
    headers = [{"content-type", "application/json"}]
    request(method, path, headers, encode_body(body), opts)
  end

  @spec multipart_request(String.t(), [multipart_part()], keyword()) ::
          {:ok, term()} | {:error, term()}
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

  @spec raw_request(atom(), String.t(), [{String.t(), String.t()}], binary() | nil, keyword()) ::
          {:ok, Finch.Response.t()} | {:error, term()}
  def raw_request(method, path, headers, body, opts \\ [])
      when method in [:get, :post, :delete] do
    Telemetry.span_provider_request(
      provider_request_metadata(method, path, opts),
      fn ->
        with {:ok, url} <- Provider.utility_url(OpenAIProvider, path, opts),
             {:ok, request_headers} <- Provider.utility_headers(OpenAIProvider, opts, headers),
             request <- Finch.build(method, url, request_headers, body),
             {:ok, %Finch.Response{} = response} <-
               ExecutionPlaneHTTP.request(
                 request,
                 receive_timeout: Keyword.get(opts, :receive_timeout, 30_000)
               ) do
          {:ok, response}
        else
          {:error, failure, raw_payload} ->
            {:error,
             Error.API.Request.exception(
               reason: ExecutionPlaneHTTP.transport_reason(failure, raw_payload)
             )}

          {:error, _reason} = error ->
            error
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
              message: "Failed to parse OpenAI JSONL response: #{Exception.message(reason)}",
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

  defp encode_body(nil), do: nil
  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body), do: Jason.encode!(body)

  defp decode_json_response(%Finch.Response{status: status, body: body})
       when status in 200..299 and body in [nil, ""] do
    {:ok, %{}}
  end

  defp decode_json_response(%Finch.Response{status: status, body: body})
       when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, reason} ->
        {:error,
         Error.API.JsonParse.exception(
           message: "Failed to parse OpenAI response: #{Exception.message(reason)}",
           raw_json: body
         )}
    end
  end

  defp decode_json_response(%Finch.Response{status: status, body: body}) do
    {:error,
     Error.API.Request.exception(
       reason: "OpenAI request failed",
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
       reason: "OpenAI request failed",
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
    Telemetry.provider_request_metadata(:openai, nil, opts, %{
      http_method: method,
      utility_path: path
    })
  end
end
