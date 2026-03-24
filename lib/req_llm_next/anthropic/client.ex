defmodule ReqLlmNext.Anthropic.Client do
  @moduledoc """
  Shared low-level HTTP client for Anthropic-specific utility endpoints.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.Providers.Anthropic, as: AnthropicProvider
  alias ReqLlmNext.Wire.Anthropic, as: AnthropicWire

  @type multipart_part ::
          {:field, String.t(), String.t()}
          | {:file, String.t(), String.t(), String.t(), binary()}

  @spec json_request(atom(), String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, term()}
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

  @spec raw_request(atom(), String.t(), [{String.t(), String.t()}], binary() | nil, keyword()) ::
          {:ok, Finch.Response.t()} | {:error, term()}
  def raw_request(method, path, headers, body, opts \\ []) do
    api_key = AnthropicProvider.get_api_key(opts)
    url = Keyword.get(opts, :base_url, AnthropicProvider.base_url()) <> path
    common_headers = common_headers(api_key, opts)
    request = Finch.build(method, url, common_headers ++ headers, body)

    case Finch.request(request, ReqLlmNext.Finch, receive_timeout: Keyword.get(opts, :receive_timeout, 30_000)) do
      {:ok, %Finch.Response{} = response} -> {:ok, response}
      {:error, reason} -> {:error, Error.API.Request.exception(reason: "HTTP request failed: #{inspect(reason)}")}
    end
  end

  @spec build_multipart_body([multipart_part()]) :: {String.t(), iodata()}
  def build_multipart_body(parts) when is_list(parts) do
    boundary = "reqllmnext_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)

    body =
      Enum.flat_map(parts, fn
        {:field, name, value} ->
          [
            "--", boundary, "\r\n",
            "Content-Disposition: form-data; name=\"", name, "\"\r\n\r\n",
            value,
            "\r\n"
          ]

        {:file, name, filename, content_type, data} ->
          [
            "--", boundary, "\r\n",
            "Content-Disposition: form-data; name=\"", name, "\"; filename=\"", filename, "\"\r\n",
            "Content-Type: ", content_type, "\r\n\r\n",
            data,
            "\r\n"
          ]
      end) ++ ["--", boundary, "--\r\n"]

    {boundary, body}
  end

  defp request(method, path, headers, body, opts) do
    with {:ok, %Finch.Response{} = response} <- raw_request(method, path, headers, body, opts) do
      decode_json_response(response)
    end
  end

  defp common_headers(api_key, opts) do
    wire_headers =
      AnthropicWire.headers(opts)
      |> Enum.reject(fn {key, _value} -> String.downcase(key) == "content-type" end)

    AnthropicProvider.auth_headers(api_key) ++ wire_headers
  end

  defp encode_body(nil), do: nil
  defp encode_body(body) when is_map(body), do: Jason.encode!(body)

  defp decode_json_response(%Finch.Response{status: status, body: body})
       when status in 200..299 and body in [nil, ""] do
    {:ok, %{}}
  end

  defp decode_json_response(%Finch.Response{status: status, body: body}) when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _decoded} -> {:ok, %{}}

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
end
