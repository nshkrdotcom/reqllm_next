defmodule ReqLlmNext.Transports.HTTPRequest do
  @moduledoc false

  alias ReqLlmNext.Error

  @spec request(module(), module(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def request(provider_mod, wire_mod, model, input, opts) do
    api_key = provider_mod.get_api_key(opts)
    base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
    url = base_url <> wire_mod.path()

    headers =
      provider_mod.auth_headers(api_key) ++
        wire_headers(wire_mod, opts)

    body =
      wire_mod.encode_body(model, input, opts)
      |> Jason.encode!()

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, ReqLlmNext.Finch) do
      {:ok, %Finch.Response{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, decoded} ->
            {:ok, decoded}

          {:error, jason_error} ->
            {:error,
             Error.API.JsonParse.exception(
               message: "Failed to parse HTTP response: #{Exception.message(jason_error)}",
               raw_json: response_body
             )}
        end

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:error,
         Error.API.Request.exception(
           reason: "HTTP request failed",
           status: status,
           response_body: response_body
         )}

      {:error, reason} ->
        {:error, Error.API.Request.exception(reason: "HTTP request failed: #{inspect(reason)}")}
    end
  end

  defp wire_headers(wire_mod, opts) do
    if function_exported?(wire_mod, :headers, 1) do
      wire_mod.headers(opts)
    else
      [{"Content-Type", "application/json"}]
    end
  end
end
