defmodule ReqLlmNext.OpenAI.VectorStores do
  @moduledoc """
  OpenAI vector-store and file-batch utility helpers.
  """

  alias ReqLlmNext.OpenAI.Client

  @spec create(keyword()) :: {:ok, term()} | {:error, term()}
  def create(opts \\ []) do
    Client.json_request(:post, "/v1/vector_stores", build_create_body(opts), opts)
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(vector_store_id, opts \\ []) when is_binary(vector_store_id) do
    Client.json_request(:get, "/v1/vector_stores/#{vector_store_id}", nil, opts)
  end

  @spec list(keyword()) :: {:ok, term()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, query_path("/v1/vector_stores", opts), nil, opts)
  end

  @spec update(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def update(vector_store_id, opts \\ []) when is_binary(vector_store_id) do
    Client.json_request(
      :post,
      "/v1/vector_stores/#{vector_store_id}",
      build_update_body(opts),
      opts
    )
  end

  @spec delete(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete(vector_store_id, opts \\ []) when is_binary(vector_store_id) do
    Client.json_request(:delete, "/v1/vector_stores/#{vector_store_id}", nil, opts)
  end

  @spec attach_file(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def attach_file(vector_store_id, file_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(file_id) do
    body =
      %{file_id: file_id}
      |> maybe_put(:attributes, Keyword.get(opts, :attributes))
      |> maybe_put(:chunking_strategy, Keyword.get(opts, :chunking_strategy))

    Client.json_request(:post, "/v1/vector_stores/#{vector_store_id}/files", body, opts)
  end

  @spec list_files(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def list_files(vector_store_id, opts \\ []) when is_binary(vector_store_id) do
    Client.json_request(
      :get,
      query_path("/v1/vector_stores/#{vector_store_id}/files", opts),
      nil,
      opts
    )
  end

  @spec get_file(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_file(vector_store_id, file_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(file_id) do
    Client.json_request(:get, "/v1/vector_stores/#{vector_store_id}/files/#{file_id}", nil, opts)
  end

  @spec remove_file(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def remove_file(vector_store_id, file_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(file_id) do
    Client.json_request(
      :delete,
      "/v1/vector_stores/#{vector_store_id}/files/#{file_id}",
      nil,
      opts
    )
  end

  @spec create_file_batch(String.t(), [String.t()], keyword()) :: {:ok, term()} | {:error, term()}
  def create_file_batch(vector_store_id, file_ids, opts \\ [])
      when is_binary(vector_store_id) and is_list(file_ids) do
    body =
      %{file_ids: file_ids}
      |> maybe_put(:attributes, Keyword.get(opts, :attributes))
      |> maybe_put(:chunking_strategy, Keyword.get(opts, :chunking_strategy))

    Client.json_request(:post, "/v1/vector_stores/#{vector_store_id}/file_batches", body, opts)
  end

  @spec get_file_batch(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_file_batch(vector_store_id, batch_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(batch_id) do
    Client.json_request(
      :get,
      "/v1/vector_stores/#{vector_store_id}/file_batches/#{batch_id}",
      nil,
      opts
    )
  end

  @spec cancel_file_batch(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel_file_batch(vector_store_id, batch_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(batch_id) do
    Client.json_request(
      :post,
      "/v1/vector_stores/#{vector_store_id}/file_batches/#{batch_id}/cancel",
      %{},
      opts
    )
  end

  @spec list_file_batch_files(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def list_file_batch_files(vector_store_id, batch_id, opts \\ [])
      when is_binary(vector_store_id) and is_binary(batch_id) do
    Client.json_request(
      :get,
      query_path("/v1/vector_stores/#{vector_store_id}/file_batches/#{batch_id}/files", opts),
      nil,
      opts
    )
  end

  @doc false
  @spec build_create_body(keyword()) :: map()
  def build_create_body(opts) do
    %{}
    |> maybe_put(:name, Keyword.get(opts, :name))
    |> maybe_put(:file_ids, Keyword.get(opts, :file_ids))
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
    |> maybe_put(:expires_after, Keyword.get(opts, :expires_after))
    |> maybe_put(:chunking_strategy, Keyword.get(opts, :chunking_strategy))
  end

  @doc false
  @spec build_update_body(keyword()) :: map()
  def build_update_body(opts) do
    %{}
    |> maybe_put(:name, Keyword.get(opts, :name))
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
    |> maybe_put(:expires_after, Keyword.get(opts, :expires_after))
  end

  @doc false
  @spec build_query_path(String.t(), keyword()) :: String.t()
  def build_query_path(base, opts) do
    query =
      opts
      |> Keyword.take([:after, :before, :limit, :order, :filter])
      |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp query_path(base, opts), do: build_query_path(base, opts)
end
