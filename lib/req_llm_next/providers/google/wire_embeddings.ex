defmodule ReqLlmNext.Wire.GoogleEmbeddings do
  @moduledoc """
  Google embedding wire for embedContent and batchEmbedContents.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.GovernedAuthority
  alias ReqLlmNext.Provider

  @provider_option_keys [:google_api_version, :dimensions, :task_type]

  @spec build_request(module(), LLMDB.Model.t(), String.t() | [String.t()], keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, input, opts) do
    request_path = request_path(model, input)

    request_opts =
      if Keyword.get(opts, :_use_runtime_metadata, false) or GovernedAuthority.governed?(opts) do
        Keyword.put(opts, :path, request_path)
      else
        Keyword.put(
          opts,
          :base_url,
          effective_base_url(provider_mod.base_url(), provider_options(opts))
        )
        |> Keyword.put(:path, request_path)
      end

    with {:ok, url} <- Provider.request_url(provider_mod, model, request_path, request_opts),
         {:ok, headers} <-
           Provider.request_headers(
             provider_mod,
             model,
             request_opts,
             [{"Content-Type", "application/json"}]
           ) do
      body = encode_body(model, input, opts) |> Jason.encode!()
      {:ok, Finch.build(:post, url, headers, body)}
    end
  end

  @spec encode_body(LLMDB.Model.t(), String.t() | [String.t()], keyword()) :: map()
  def encode_body(%LLMDB.Model{id: model_id}, input, opts) do
    dimensions = Keyword.get(opts, :dimensions) || provider_options(opts)[:dimensions]
    task_type = Keyword.get(opts, :task_type) || provider_options(opts)[:task_type]

    build_item = fn text ->
      %{
        model: "models/#{model_id}",
        content: %{parts: [%{text: text}]}
      }
      |> maybe_put(:outputDimensionality, dimensions)
      |> maybe_put(:taskType, task_type)
    end

    case input do
      texts when is_list(texts) -> %{requests: Enum.map(texts, build_item)}
      text when is_binary(text) -> build_item.(text)
    end
  end

  @spec extract_embeddings(map(), String.t() | [String.t()]) ::
          {:ok, [float()] | [[float()]]} | {:error, term()}
  def extract_embeddings(%{"embedding" => %{"values" => values}}, input) when is_binary(input) do
    {:ok, values}
  end

  def extract_embeddings(%{"embeddings" => embeddings}, input)
      when is_list(embeddings) and is_list(input) do
    values =
      embeddings
      |> Enum.map(fn
        %{"values" => item_values} when is_list(item_values) -> item_values
        %{"embedding" => %{"values" => item_values}} when is_list(item_values) -> item_values
        other -> Map.get(other, "values", [])
      end)

    {:ok, values}
  end

  def extract_embeddings(%{"data" => [%{"embedding" => embedding}]}, input)
      when is_binary(input) do
    {:ok, embedding}
  end

  def extract_embeddings(%{"data" => data}, input) when is_list(data) and is_list(input) do
    {:ok, Enum.map(Enum.sort_by(data, & &1["index"]), & &1["embedding"])}
  end

  def extract_embeddings(response, _input) do
    {:error,
     Error.API.Response.exception(
       reason: "Invalid Google embedding response format",
       response_body: response
     )}
  end

  defp request_path(%LLMDB.Model{id: id}, input) when is_list(input),
    do: "/models/#{id}:batchEmbedContents"

  defp request_path(%LLMDB.Model{id: id}, _input), do: "/models/#{id}:embedContent"

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.merge(Keyword.take(opts, @provider_option_keys))
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp effective_base_url(base_url, provider_options) do
    case provider_options[:google_api_version] do
      "v1" -> base_url <> "/v1"
      _ -> base_url <> "/v1beta"
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
