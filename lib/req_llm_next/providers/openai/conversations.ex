defmodule ReqLlmNext.OpenAI.Conversations do
  @moduledoc """
  OpenAI conversation-state utility helpers.
  """

  alias ReqLlmNext.OpenAI.Client

  @spec create(keyword()) :: {:ok, term()} | {:error, term()}
  def create(opts \\ []) do
    Client.json_request(:post, "/v1/conversations", build_create_body(opts), opts)
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(conversation_id, opts \\ []) when is_binary(conversation_id) do
    Client.json_request(:get, "/v1/conversations/#{conversation_id}", nil, opts)
  end

  @spec update(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def update(conversation_id, opts \\ []) when is_binary(conversation_id) do
    Client.json_request(
      :post,
      "/v1/conversations/#{conversation_id}",
      build_update_body(opts),
      opts
    )
  end

  @spec delete(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete(conversation_id, opts \\ []) when is_binary(conversation_id) do
    Client.json_request(:delete, "/v1/conversations/#{conversation_id}", nil, opts)
  end

  @spec create_item(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def create_item(conversation_id, item, opts \\ [])
      when is_binary(conversation_id) and is_map(item) do
    Client.json_request(
      :post,
      "/v1/conversations/#{conversation_id}/items",
      build_item_body(item, opts),
      opts
    )
  end

  @spec get_item(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_item(conversation_id, item_id, opts \\ [])
      when is_binary(conversation_id) and is_binary(item_id) do
    Client.json_request(:get, "/v1/conversations/#{conversation_id}/items/#{item_id}", nil, opts)
  end

  @spec list_items(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def list_items(conversation_id, opts \\ []) when is_binary(conversation_id) do
    Client.json_request(
      :get,
      query_path("/v1/conversations/#{conversation_id}/items", opts),
      nil,
      opts
    )
  end

  @spec delete_item(String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_item(conversation_id, item_id, opts \\ [])
      when is_binary(conversation_id) and is_binary(item_id) do
    Client.json_request(
      :delete,
      "/v1/conversations/#{conversation_id}/items/#{item_id}",
      nil,
      opts
    )
  end

  @doc false
  @spec build_create_body(keyword()) :: map()
  def build_create_body(opts) do
    %{}
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
    |> maybe_put(:items, Keyword.get(opts, :items))
  end

  @doc false
  @spec build_update_body(keyword()) :: map()
  def build_update_body(opts) do
    %{}
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
  end

  @doc false
  @spec build_item_body(map(), keyword()) :: map()
  def build_item_body(item, opts) do
    item
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
  end

  @doc false
  @spec build_query_path(String.t(), keyword()) :: String.t()
  def build_query_path(base, opts) do
    query =
      opts
      |> Keyword.take([:after, :before, :limit, :order])
      |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  defp query_path(base, opts), do: build_query_path(base, opts)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
