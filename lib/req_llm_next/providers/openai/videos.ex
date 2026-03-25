defmodule ReqLlmNext.OpenAI.Videos do
  @moduledoc """
  OpenAI video-generation utility helpers.
  """

  alias ReqLlmNext.OpenAI.Client

  @spec create(keyword()) :: {:ok, term()} | {:error, term()}
  def create(opts \\ []) do
    Client.json_request(:post, "/v1/videos", build_create_body(opts), opts)
  end

  @spec edit(keyword()) :: {:ok, term()} | {:error, term()}
  def edit(opts \\ []) do
    Client.json_request(:post, "/v1/videos/edits", build_edit_body(opts), opts)
  end

  @spec extend(keyword()) :: {:ok, term()} | {:error, term()}
  def extend(opts \\ []) do
    Client.json_request(:post, "/v1/videos/extensions", build_extension_body(opts), opts)
  end

  @spec remix(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def remix(video_id, opts \\ []) when is_binary(video_id) do
    Client.json_request(:post, "/v1/videos/#{video_id}/remix", build_remix_body(opts), opts)
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(video_id, opts \\ []) when is_binary(video_id) do
    Client.json_request(:get, "/v1/videos/#{video_id}", nil, opts)
  end

  @spec list(keyword()) :: {:ok, term()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, query_path("/v1/videos", opts), nil, opts)
  end

  @spec delete(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete(video_id, opts \\ []) when is_binary(video_id) do
    Client.json_request(:delete, "/v1/videos/#{video_id}", nil, opts)
  end

  @spec content(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def content(video_id, opts \\ []) when is_binary(video_id) do
    Client.download_request("/v1/videos/#{video_id}/content", opts)
  end

  @spec create_character(keyword()) :: {:ok, term()} | {:error, term()}
  def create_character(opts \\ []) do
    Client.json_request(:post, "/v1/videos/characters", build_character_body(opts), opts)
  end

  @spec get_character(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_character(character_id, opts \\ []) when is_binary(character_id) do
    Client.json_request(:get, "/v1/videos/characters/#{character_id}", nil, opts)
  end

  @doc false
  @spec build_create_body(keyword()) :: map()
  def build_create_body(opts) do
    opts
    |> Keyword.take([
      :model,
      :prompt,
      :reference_image,
      :reference_images,
      :size,
      :seconds,
      :fps,
      :seed,
      :n,
      :quality,
      :background,
      :metadata
    ])
    |> Enum.into(%{})
  end

  @doc false
  @spec build_edit_body(keyword()) :: map()
  def build_edit_body(opts) do
    opts
    |> Keyword.take([
      :model,
      :prompt,
      :video_id,
      :source_video_id,
      :reference_image,
      :reference_images,
      :mask,
      :seconds,
      :seed,
      :metadata
    ])
    |> Enum.into(%{})
  end

  @doc false
  @spec build_extension_body(keyword()) :: map()
  def build_extension_body(opts) do
    opts
    |> Keyword.take([:video_id, :seconds, :prompt, :seed, :metadata])
    |> Enum.into(%{})
  end

  @doc false
  @spec build_remix_body(keyword()) :: map()
  def build_remix_body(opts) do
    opts
    |> Keyword.take([:prompt, :seed, :metadata])
    |> Enum.into(%{})
  end

  @doc false
  @spec build_character_body(keyword()) :: map()
  def build_character_body(opts) do
    opts
    |> Keyword.take([:video_id, :file_id, :frame_index, :metadata])
    |> Enum.into(%{})
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
end
