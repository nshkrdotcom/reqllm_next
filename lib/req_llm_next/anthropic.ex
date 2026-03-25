defmodule ReqLlmNext.Anthropic do
  @moduledoc """
  Anthropic-specific helpers for provider-native endpoints and message features.
  """

  alias ReqLlmNext.Anthropic.{Files, MessageBatches, TokenCount, Tools}
  alias ReqLlmNext.Context.ContentPart

  @spec document_text(String.t(), map()) :: ContentPart.t()
  def document_text(text, metadata \\ %{}), do: ContentPart.document_text(text, metadata)

  @spec document_binary(binary(), String.t(), map()) :: ContentPart.t()
  def document_binary(data, media_type \\ "application/pdf", metadata \\ %{}),
    do: ContentPart.document_binary(data, media_type, metadata)

  @spec document_file_id(String.t(), map()) :: ContentPart.t()
  def document_file_id(file_id, metadata \\ %{}),
    do: ContentPart.document_file_id(file_id, metadata)

  @spec container_upload(String.t(), keyword()) :: ContentPart.t()
  def container_upload(file_id, opts \\ []) when is_binary(file_id) do
    metadata =
      opts
      |> Enum.into(%{})
      |> Map.put(:anthropic_type, :container_upload)
      |> Map.put(:source_type, :file_id)

    ContentPart.file(
      file_id,
      Keyword.get(opts, :filename, "upload.bin"),
      Keyword.get(opts, :content_type, "application/octet-stream")
    )
    |> Map.put(:metadata, metadata)
  end

  @spec web_search_tool(keyword()) :: map()
  def web_search_tool(opts \\ []), do: Tools.web_search(opts)

  @spec web_fetch_tool(keyword()) :: map()
  def web_fetch_tool(opts \\ []), do: Tools.web_fetch(opts)

  @spec code_execution_tool(keyword()) :: map()
  def code_execution_tool(opts \\ []), do: Tools.code_execution(opts)

  @spec computer_use_tool(keyword()) :: map()
  def computer_use_tool(opts \\ []), do: Tools.computer_use(opts)

  @spec bash_tool(keyword()) :: map()
  def bash_tool(opts \\ []), do: Tools.bash(opts)

  @spec text_editor_tool(keyword()) :: map()
  def text_editor_tool(opts \\ []), do: Tools.text_editor(opts)

  @spec mcp_server(String.t(), keyword()) :: map()
  def mcp_server(url, opts \\ []), do: Tools.mcp_server(url, opts)

  @spec token_count(ReqLlmNext.model_spec(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def token_count(model_source, prompt, opts \\ []),
    do: TokenCount.count(model_source, prompt, opts)

  @spec upload_file(String.t() | binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def upload_file(path_or_data, opts \\ []), do: Files.upload(path_or_data, opts)

  @spec get_file(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_file(file_id, opts \\ []), do: Files.get(file_id, opts)

  @spec download_file(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download_file(file_id, opts \\ []), do: Files.download(file_id, opts)

  @spec list_files(keyword()) :: {:ok, map()} | {:error, term()}
  def list_files(opts \\ []), do: Files.list(opts)

  @spec delete_file(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_file(file_id, opts \\ []), do: Files.delete(file_id, opts)

  @spec build_batch_request(
          String.t(),
          ReqLlmNext.model_spec(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def build_batch_request(custom_id, model_source, prompt, opts \\ []) do
    MessageBatches.build_request(custom_id, model_source, prompt, opts)
  end

  @spec create_batch([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def create_batch(requests, opts \\ []), do: MessageBatches.create(requests, opts)

  @spec get_batch(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_batch(batch_id, opts \\ []), do: MessageBatches.get(batch_id, opts)

  @spec list_batches(keyword()) :: {:ok, map()} | {:error, term()}
  def list_batches(opts \\ []), do: MessageBatches.list(opts)

  @spec get_batch_results(String.t() | map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_batch_results(batch_or_id, opts \\ []), do: MessageBatches.results(batch_or_id, opts)

  @spec cancel_batch(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel_batch(batch_id, opts \\ []), do: MessageBatches.cancel(batch_id, opts)

  @spec delete_batch(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_batch(batch_id, opts \\ []), do: MessageBatches.delete(batch_id, opts)
end
