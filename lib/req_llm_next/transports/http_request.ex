defmodule ReqLlmNext.Transports.HTTPRequest do
  @moduledoc false

  alias ReqLlmNext.Error
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Telemetry

  @spec request(module(), module(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def request(provider_mod, wire_mod, model, input, opts) do
    case Fixtures.maybe_replay_request(model, input, opts, wire_mod) do
      {:ok, replay_response} ->
        {:ok, replay_response}

      :no_fixture ->
        Telemetry.span_provider_request(
          provider_request_metadata(provider_mod, model, opts, wire_mod),
          fn ->
            with {:ok, request} <- build_request(provider_mod, wire_mod, model, input, opts),
                 {:ok, response} <- Finch.request(request, ReqLlmNext.Finch),
                 :ok <- maybe_record_fixture(model, opts, request, response),
                 {:ok, decoded} <- decode_response(wire_mod, response, model, input, opts) do
              {:ok, decoded}
            else
              {:ok, %Finch.Response{status: status, body: response_body}} ->
                {:error,
                 Error.API.Request.exception(
                   reason: "HTTP request failed",
                   status: status,
                   response_body: response_body
                 )}

              {:error, %Error.API.Request{} = error} ->
                {:error, error}

              {:error, %Error.API.JsonParse{} = error} ->
                {:error, error}

              {:error, %Error.API.Response{} = error} ->
                {:error, error}

              {:error, reason} ->
                {:error,
                 Error.API.Request.exception(reason: "HTTP request failed: #{inspect(reason)}")}
            end
          end
        )
    end
  end

  defp build_request(provider_mod, wire_mod, model, input, opts) do
    if module_exports?(wire_mod, :build_request, 4) do
      wire_mod.build_request(provider_mod, model, input, opts)
    else
      with {:ok, url} <- Provider.request_url(provider_mod, model, wire_mod.path(), opts),
           {:ok, headers} <-
             Provider.request_headers(provider_mod, model, opts, wire_headers(wire_mod, opts)) do
        body =
          wire_mod.encode_body(model, input, opts)
          |> Jason.encode!()

        {:ok, Finch.build(:post, url, headers, body)}
      end
    end
  end

  defp decode_response(wire_mod, %Finch.Response{status: status} = response, model, input, opts)
       when status in 200..299 do
    if module_exports?(wire_mod, :decode_response, 4) do
      wire_mod.decode_response(response, model, input, opts)
    else
      default_decode_response(response)
    end
  end

  defp decode_response(
         _wire_mod,
         %Finch.Response{status: status, body: response_body},
         _model,
         _input,
         _opts
       ) do
    {:error,
     Error.API.Request.exception(
       reason: "HTTP request failed",
       status: status,
       response_body: response_body
     )}
  end

  defp default_decode_response(%Finch.Response{body: response_body}) do
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
  end

  defp maybe_record_fixture(model, opts, request, response) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.save_request_fixture(
          model,
          fixture_name,
          request,
          execution_metadata(opts),
          response
        )

      _ ->
        :ok
    end
  end

  defp execution_metadata(opts) do
    %{
      surface_id: Keyword.get(opts, :_execution_surface_id),
      semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
      wire_format: Keyword.get(opts, :_execution_wire_format),
      transport: Keyword.get(opts, :_execution_transport)
    }
  end

  defp wire_headers(wire_mod, opts) do
    if module_exports?(wire_mod, :headers, 1) do
      wire_mod.headers(opts)
    else
      [{"Content-Type", "application/json"}]
    end
  end

  defp module_exports?(module, function_name, arity) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, function_name, arity)
  end

  defp provider_request_metadata(provider_mod, model, opts, wire_mod) do
    Telemetry.provider_request_metadata(model.provider, model, opts, %{
      provider_module: inspect(provider_mod),
      wire_module: inspect(wire_mod)
    })
  end
end
