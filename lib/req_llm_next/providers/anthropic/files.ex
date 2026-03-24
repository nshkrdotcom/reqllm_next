defmodule ReqLlmNext.Anthropic.Files do
  @moduledoc """
  Anthropic Files API helpers.
  """

  alias ReqLlmNext.Anthropic.Client
  alias ReqLlmNext.Error

  @spec upload(String.t() | binary(), keyword()) :: {:ok, map()} | {:error, term()}
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

  @spec upload_binary(binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def upload_binary(data, opts) when is_binary(data) and is_list(opts) do
    filename = Keyword.get(opts, :filename, "upload.bin")
    content_type = Keyword.get(opts, :content_type, content_type_for(filename))

    parts = [
      {:file, "file", filename, content_type, data}
    ]

    Client.multipart_request("/v1/files", parts, Keyword.put(opts, :anthropic_files_api, true))
  end

  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(file_id, opts \\ []) when is_binary(file_id) do
    Client.json_request(
      :get,
      "/v1/files/#{file_id}",
      nil,
      Keyword.put(opts, :anthropic_files_api, true)
    )
  end

  @spec download(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download(file_id, opts \\ []) when is_binary(file_id) do
    Client.download_request(
      "/v1/files/#{file_id}/content",
      Keyword.put(opts, :anthropic_files_api, true)
    )
  end

  @spec list(keyword()) :: {:ok, map()} | {:error, term()}
  def list(opts \\ []) do
    Client.json_request(:get, "/v1/files", nil, Keyword.put(opts, :anthropic_files_api, true))
  end

  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(file_id, opts \\ []) when is_binary(file_id) do
    Client.json_request(
      :delete,
      "/v1/files/#{file_id}",
      nil,
      Keyword.put(opts, :anthropic_files_api, true)
    )
  end

  @spec content_type_for(String.t()) :: String.t()
  def content_type_for(filename) when is_binary(filename) do
    case Path.extname(filename) do
      ".pdf" -> "application/pdf"
      ".txt" -> "text/plain"
      ".md" -> "text/markdown"
      ".json" -> "application/json"
      ".csv" -> "text/csv"
      ".xml" -> "application/xml"
      ".xls" -> "application/vnd.ms-excel"
      ".xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      _ -> "application/octet-stream"
    end
  end
end
