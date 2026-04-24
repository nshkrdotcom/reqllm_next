defmodule ReqLlmNext.ExecutionPlaneHTTP do
  @moduledoc false

  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.HTTP, as: ExecutionPlaneHTTP

  @spec request(Finch.Request.t(), keyword()) ::
          {:ok, Finch.Response.t()} | {:error, Failure.t(), map()}
  def request(%Finch.Request{} = request, opts \\ []) do
    case ExecutionPlaneHTTP.unary(
           %{
             url: finch_url(request),
             method: request.method,
             headers:
               Map.new(request.headers, fn {key, value} -> {to_string(key), to_string(value)} end),
             body: request.body,
             timeout_ms: timeout_ms(opts)
           },
           lineage: execution_lineage(request)
         ) do
      {:ok, result} ->
        {:ok,
         %Finch.Response{
           status: result.outcome.raw_payload.status_code,
           headers: Map.to_list(result.outcome.raw_payload.headers),
           body: result.outcome.raw_payload.body
         }}

      {:error, result} ->
        {:error, result.outcome.failure, result.outcome.raw_payload}
    end
  end

  @spec transport_reason(Failure.t(), map()) :: String.t()
  def transport_reason(%Failure{} = failure, raw_payload) do
    detail =
      raw_payload
      |> Map.get(:error, Map.get(raw_payload, "error"))
      |> case do
        nil -> failure.reason || Atom.to_string(failure.failure_class)
        value -> to_string(value)
      end

    "HTTP transport failed (#{failure.failure_class}): #{detail}"
  end

  defp finch_url(%Finch.Request{} = request) do
    scheme = request.scheme |> to_string()
    host = to_string(request.host)
    port = if is_integer(request.port), do: ":#{request.port}", else: ""
    "#{scheme}://#{host}#{port}#{Finch.Request.request_path(request)}"
  end

  defp timeout_ms(opts) do
    Keyword.get(opts, :timeout_ms) || Keyword.get(opts, :timeout) ||
      Keyword.get(opts, :receive_timeout)
  end

  defp execution_lineage(%Finch.Request{} = request) do
    %{
      idempotency_key: idempotency_key(request.headers) || generated_idempotency_key(request)
    }
  end

  defp idempotency_key(headers) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.contains?(String.downcase(to_string(key)), "idempotency-key") do
        to_string(value)
      end
    end)
  end

  defp generated_idempotency_key(%Finch.Request{} = request) do
    token = System.unique_integer([:positive, :monotonic])
    "req-llm-next-http-#{request.method}-#{:erlang.phash2(finch_url(request))}-#{token}"
  end
end
