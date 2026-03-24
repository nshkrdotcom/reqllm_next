defmodule ReqLlmNext.Anthropic.MessageBatches do
  @moduledoc """
  Anthropic Message Batches API helpers.
  """

  alias ReqLlmNext.Anthropic.Client
  alias ReqLlmNext.ModelResolver
  alias ReqLlmNext.Wire.Anthropic, as: AnthropicWire

  @spec build_request(String.t(), ReqLlmNext.model_spec(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def build_request(custom_id, model_source, prompt, opts \\ []) when is_binary(custom_id) do
    with {:ok, model} <- ModelResolver.resolve(model_source) do
      params =
        model
        |> AnthropicWire.encode_body(prompt, opts)
        |> Map.delete(:stream)

      {:ok, %{custom_id: custom_id, params: params}}
    end
  end

  @spec create([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def create(requests, opts \\ []) when is_list(requests) do
    Client.json_request(:post, "/v1/messages/batches", %{requests: requests}, opts)
  end

  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(batch_id, opts \\ []) when is_binary(batch_id) do
    Client.json_request(:get, "/v1/messages/batches/#{batch_id}", nil, opts)
  end

  @spec list(keyword()) :: {:ok, map()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, "/v1/messages/batches", nil, opts)
  end

  @spec cancel(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel(batch_id, opts \\ []) when is_binary(batch_id) do
    Client.json_request(:post, "/v1/messages/batches/#{batch_id}/cancel", %{}, opts)
  end
end
