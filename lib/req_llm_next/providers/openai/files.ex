defmodule ReqLlmNext.OpenAI.Files do
  @moduledoc """
  OpenAI Files API helpers.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.OpenAI.Client

  @spec upload(String.t() | binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def upload(path_or_data, opts \\ [])

  def upload(path, opts) when is_binary(path) do
    cond do
      File.regular?(path) ->
        path
        |> File.read!()
        |> upload_binary(Keyword.put_new(opts, :filename, Path.basename(path)))

      Keyword.has_key?(opts, :filename) ->
        upload_binary(path, opts)

      true ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "upload expects a file path or binary with :filename"
         )}
    end
  end

  @spec upload_binary(binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def upload_binary(data, opts) when is_binary(data) and is_list(opts) do
    filename = Keyword.get(opts, :filename, "upload.bin")
    purpose = Keyword.get(opts, :purpose, "assistants")
    content_type = Keyword.get(opts, :content_type, content_type_for(filename))

    parts = [
      {:field, "purpose", to_string(purpose)},
      {:file, "file", filename, content_type, data}
    ]

    Client.multipart_request("/v1/files", parts, opts)
  end

  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(file_id, opts \\ []) when is_binary(file_id) do
    Client.json_request(:get, "/v1/files/#{file_id}", nil, opts)
  end

  @spec list(keyword()) :: {:ok, term()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, list_path(opts), nil, opts)
  end

  @spec delete(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete(file_id, opts \\ []) when is_binary(file_id) do
    Client.json_request(:delete, "/v1/files/#{file_id}", nil, opts)
  end

  @spec download(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download(file_id, opts \\ []) when is_binary(file_id) do
    Client.download_request("/v1/files/#{file_id}/content", opts)
  end

  @spec content_type_for(String.t()) :: String.t()
  def content_type_for(filename) when is_binary(filename) do
    case Path.extname(filename) do
      ".jsonl" -> "application/jsonl"
      ".json" -> "application/json"
      ".csv" -> "text/csv"
      ".tsv" -> "text/tab-separated-values"
      ".txt" -> "text/plain"
      ".md" -> "text/markdown"
      ".pdf" -> "application/pdf"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".webp" -> "image/webp"
      ".mp3" -> "audio/mpeg"
      ".wav" -> "audio/wav"
      ".m4a" -> "audio/mp4"
      _ -> "application/octet-stream"
    end
  end

  defp list_path(opts) do
    query =
      opts
      |> Keyword.take([:after, :limit, :order, :purpose])
      |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    if query == %{}, do: "/v1/files", else: "/v1/files?" <> URI.encode_query(query)
  end
end
