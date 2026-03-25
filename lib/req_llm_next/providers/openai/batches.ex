defmodule ReqLlmNext.OpenAI.Batches do
  @moduledoc """
  OpenAI Batch API helpers.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.OpenAI.{Client, Files}

  @spec create(String.t() | [map()], keyword()) :: {:ok, term()} | {:error, term()}
  def create(input, opts \\ [])

  def create(input_file_id, opts) when is_binary(input_file_id) do
    body =
      %{input_file_id: input_file_id, endpoint: Keyword.fetch!(opts, :endpoint)}
      |> Map.put(:completion_window, Keyword.get(opts, :completion_window, "24h"))
      |> maybe_put(:metadata, Keyword.get(opts, :metadata))

    Client.json_request(:post, "/v1/batches", body, opts)
  rescue
    KeyError ->
      {:error, Error.Invalid.Parameter.exception(parameter: "batch creation requires :endpoint")}
  end

  def create(requests, opts) when is_list(requests) do
    filename = Keyword.get(opts, :filename, "batch.jsonl")

    with {:ok, uploaded} <-
           Files.upload_binary(build_input_jsonl(requests), filename: filename, purpose: "batch"),
         input_file_id when is_binary(input_file_id) <- uploaded["id"] || uploaded[:id] do
      create(input_file_id, opts)
    else
      nil ->
        {:error,
         Error.API.Response.exception(
           reason: "OpenAI batch upload response did not include a file id"
         )}

      {:ok, uploaded} when is_map(uploaded) ->
        {:error,
         Error.API.Response.exception(
           reason: "OpenAI batch upload response did not include a file id",
           response_body: uploaded
         )}

      {:error, _} = error ->
        error
    end
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(batch_id, opts \\ []) when is_binary(batch_id) do
    Client.json_request(:get, "/v1/batches/#{batch_id}", nil, opts)
  end

  @spec list(keyword()) :: {:ok, term()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, query_path("/v1/batches", opts), nil, opts)
  end

  @spec cancel(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel(batch_id, opts \\ []) when is_binary(batch_id) do
    Client.json_request(:post, "/v1/batches/#{batch_id}/cancel", %{}, opts)
  end

  @spec results(String.t() | map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def results(batch_or_id, opts \\ [])

  def results(%{} = batch, opts) do
    batch
    |> output_file_id()
    |> case do
      nil ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "batch response did not include output_file_id"
         )}

      output_file_id ->
        results(output_file_id, Keyword.put(opts, :_treat_as_file_id, true))
    end
  end

  def results(batch_id, opts) when is_binary(batch_id) do
    if Keyword.get(opts, :_treat_as_file_id, false) or String.starts_with?(batch_id, "file_") do
      with {:ok, %{data: data}} <- Files.download(batch_id, opts) do
        Client.parse_jsonl(data)
      end
    else
      with {:ok, batch} <- get(batch_id, opts) do
        results(batch, opts)
      end
    end
  end

  @spec build_input_jsonl([map()]) :: binary()
  def build_input_jsonl(requests) when is_list(requests) do
    requests
    |> Enum.map_join("\n", &Jason.encode!/1)
    |> Kernel.<>("\n")
  end

  defp output_file_id(batch) when is_map(batch) do
    batch["output_file_id"] || batch[:output_file_id]
  end

  defp query_path(base, opts) do
    query =
      opts
      |> Keyword.take([:after, :limit])
      |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
