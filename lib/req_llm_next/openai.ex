defmodule ReqLlmNext.OpenAI do
  @moduledoc """
  OpenAI-specific helpers for provider-native tools and utility endpoints.
  """

  alias ReqLlmNext.OpenAI.{
    Background,
    Batches,
    Conversations,
    Files,
    Moderations,
    Realtime,
    Responses,
    Tools,
    VectorStores,
    Videos,
    Webhooks
  }

  @spec web_search_tool(keyword()) :: map()
  def web_search_tool(opts \\ []), do: Tools.web_search(opts)

  @spec file_search_tool(keyword()) :: map()
  def file_search_tool(opts \\ []), do: Tools.file_search(opts)

  @spec code_interpreter_tool(keyword()) :: map()
  def code_interpreter_tool(opts \\ []), do: Tools.code_interpreter(opts)

  @spec computer_use_tool(keyword()) :: map()
  def computer_use_tool(opts \\ []), do: Tools.computer_use(opts)

  @spec mcp_tool(keyword()) :: map()
  def mcp_tool(opts \\ []), do: Tools.mcp(opts)

  @spec hosted_shell_tool(keyword()) :: map()
  def hosted_shell_tool(opts \\ []), do: Tools.hosted_shell(opts)

  @spec apply_patch_tool(keyword()) :: map()
  def apply_patch_tool(opts \\ []), do: Tools.apply_patch(opts)

  @spec local_shell_tool(keyword()) :: map()
  def local_shell_tool(opts \\ []), do: Tools.local_shell(opts)

  @spec tool_search_tool(keyword()) :: map()
  def tool_search_tool(opts \\ []), do: Tools.tool_search(opts)

  @spec skill_tool(keyword()) :: map()
  def skill_tool(opts \\ []), do: Tools.skill(opts)

  @spec image_generation_tool(keyword()) :: map()
  def image_generation_tool(opts \\ []), do: Tools.image_generation(opts)

  @spec web_search_sources_include() :: String.t()
  def web_search_sources_include, do: Tools.web_search_sources_include()

  @spec file_search_results_include() :: String.t()
  def file_search_results_include, do: Tools.file_search_results_include()

  @spec upload_file(String.t() | binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def upload_file(path_or_data, opts \\ []), do: Files.upload(path_or_data, opts)

  @spec get_file(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_file(file_id, opts \\ []), do: Files.get(file_id, opts)

  @spec list_files(keyword()) :: {:ok, term()} | {:error, term()}
  def list_files(opts \\ []), do: Files.list(opts)

  @spec download_file(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download_file(file_id, opts \\ []), do: Files.download(file_id, opts)

  @spec delete_file(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_file(file_id, opts \\ []), do: Files.delete(file_id, opts)

  @spec create_vector_store(keyword()) :: {:ok, term()} | {:error, term()}
  def create_vector_store(opts \\ []), do: VectorStores.create(opts)

  @spec get_vector_store(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_vector_store(vector_store_id, opts \\ []), do: VectorStores.get(vector_store_id, opts)

  @spec list_vector_stores(keyword()) :: {:ok, term()} | {:error, term()}
  def list_vector_stores(opts \\ []), do: VectorStores.list(opts)

  @spec update_vector_store(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def update_vector_store(vector_store_id, opts \\ []),
    do: VectorStores.update(vector_store_id, opts)

  @spec delete_vector_store(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_vector_store(vector_store_id, opts \\ []),
    do: VectorStores.delete(vector_store_id, opts)

  @spec attach_file_to_vector_store(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def attach_file_to_vector_store(vector_store_id, file_id, opts \\ []),
    do: VectorStores.attach_file(vector_store_id, file_id, opts)

  @spec list_vector_store_files(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def list_vector_store_files(vector_store_id, opts \\ []),
    do: VectorStores.list_files(vector_store_id, opts)

  @spec get_vector_store_file(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def get_vector_store_file(vector_store_id, file_id, opts \\ []),
    do: VectorStores.get_file(vector_store_id, file_id, opts)

  @spec remove_vector_store_file(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def remove_vector_store_file(vector_store_id, file_id, opts \\ []),
    do: VectorStores.remove_file(vector_store_id, file_id, opts)

  @spec create_vector_store_file_batch(String.t(), [String.t()], keyword()) ::
          {:ok, term()} | {:error, term()}
  def create_vector_store_file_batch(vector_store_id, file_ids, opts \\ []),
    do: VectorStores.create_file_batch(vector_store_id, file_ids, opts)

  @spec get_vector_store_file_batch(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def get_vector_store_file_batch(vector_store_id, batch_id, opts \\ []),
    do: VectorStores.get_file_batch(vector_store_id, batch_id, opts)

  @spec cancel_vector_store_file_batch(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def cancel_vector_store_file_batch(vector_store_id, batch_id, opts \\ []),
    do: VectorStores.cancel_file_batch(vector_store_id, batch_id, opts)

  @spec list_vector_store_file_batch_files(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def list_vector_store_file_batch_files(vector_store_id, batch_id, opts \\ []),
    do: VectorStores.list_file_batch_files(vector_store_id, batch_id, opts)

  @spec create_batch(String.t() | [map()], keyword()) :: {:ok, term()} | {:error, term()}
  def create_batch(input, opts \\ []), do: Batches.create(input, opts)

  @spec get_batch(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_batch(batch_id, opts \\ []), do: Batches.get(batch_id, opts)

  @spec list_batches(keyword()) :: {:ok, term()} | {:error, term()}
  def list_batches(opts \\ []), do: Batches.list(opts)

  @spec cancel_batch(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel_batch(batch_id, opts \\ []), do: Batches.cancel(batch_id, opts)

  @spec get_batch_results(String.t() | map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_batch_results(batch_or_id, opts \\ []), do: Batches.results(batch_or_id, opts)

  @spec get_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_response(response_id, opts \\ []), do: Responses.get(response_id, opts)

  @spec cancel_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel_response(response_id, opts \\ []), do: Responses.cancel(response_id, opts)

  @spec get_response_input_items(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_response_input_items(response_id, opts \\ []),
    do: Responses.input_items(response_id, opts)

  @spec delete_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_response(response_id, opts \\ []), do: Responses.delete(response_id, opts)

  @spec compact_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def compact_response(response_id, opts \\ []), do: Responses.compact(response_id, opts)

  @spec count_response_input_tokens(
          ReqLlmNext.model_spec(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) :: {:ok, term()} | {:error, term()}
  def count_response_input_tokens(model_source, prompt, opts \\ []),
    do: Responses.count_input_tokens(model_source, prompt, opts)

  @spec submit_background_response(
          ReqLlmNext.model_spec(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) ::
          {:ok, term()} | {:error, term()}
  def submit_background_response(model_source, prompt, opts \\ []),
    do: Background.submit(model_source, prompt, opts)

  @spec get_background_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_background_response(response_id, opts \\ []), do: Background.get(response_id, opts)

  @spec cancel_background_response(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def cancel_background_response(response_id, opts \\ []),
    do: Background.cancel(response_id, opts)

  @spec moderate(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def moderate(input, opts \\ []), do: Moderations.create(input, opts)

  @spec create_conversation(keyword()) :: {:ok, term()} | {:error, term()}
  def create_conversation(opts \\ []), do: Conversations.create(opts)

  @spec get_conversation(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_conversation(conversation_id, opts \\ []), do: Conversations.get(conversation_id, opts)

  @spec update_conversation(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def update_conversation(conversation_id, opts \\ []),
    do: Conversations.update(conversation_id, opts)

  @spec delete_conversation(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_conversation(conversation_id, opts \\ []),
    do: Conversations.delete(conversation_id, opts)

  @spec create_conversation_item(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def create_conversation_item(conversation_id, item, opts \\ []),
    do: Conversations.create_item(conversation_id, item, opts)

  @spec get_conversation_item(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def get_conversation_item(conversation_id, item_id, opts \\ []),
    do: Conversations.get_item(conversation_id, item_id, opts)

  @spec list_conversation_items(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def list_conversation_items(conversation_id, opts \\ []),
    do: Conversations.list_items(conversation_id, opts)

  @spec delete_conversation_item(String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def delete_conversation_item(conversation_id, item_id, opts \\ []),
    do: Conversations.delete_item(conversation_id, item_id, opts)

  @spec create_video(keyword()) :: {:ok, term()} | {:error, term()}
  def create_video(opts \\ []), do: Videos.create(opts)

  @spec edit_video(keyword()) :: {:ok, term()} | {:error, term()}
  def edit_video(opts \\ []), do: Videos.edit(opts)

  @spec extend_video(keyword()) :: {:ok, term()} | {:error, term()}
  def extend_video(opts \\ []), do: Videos.extend(opts)

  @spec remix_video(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def remix_video(video_id, opts \\ []), do: Videos.remix(video_id, opts)

  @spec get_video(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_video(video_id, opts \\ []), do: Videos.get(video_id, opts)

  @spec list_videos(keyword()) :: {:ok, term()} | {:error, term()}
  def list_videos(opts \\ []), do: Videos.list(opts)

  @spec delete_video(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def delete_video(video_id, opts \\ []), do: Videos.delete(video_id, opts)

  @spec download_video_content(String.t(), keyword()) ::
          {:ok,
           %{data: binary(), content_type: String.t() | nil, headers: [{String.t(), String.t()}]}}
          | {:error, term()}
  def download_video_content(video_id, opts \\ []), do: Videos.content(video_id, opts)

  @spec create_video_character(keyword()) :: {:ok, term()} | {:error, term()}
  def create_video_character(opts \\ []), do: Videos.create_character(opts)

  @spec get_video_character(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get_video_character(character_id, opts \\ []), do: Videos.get_character(character_id, opts)

  @spec parse_webhook_event(binary()) :: {:ok, map()} | {:error, term()}
  def parse_webhook_event(body), do: Webhooks.parse(body)

  @spec webhook_event_type(map()) :: String.t() | nil
  def webhook_event_type(event), do: Webhooks.event_type(event)

  @spec stream_realtime(ReqLlmNext.model_spec(), Enumerable.t() | [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_realtime(model_source, events, opts \\ []),
    do: Realtime.stream(model_source, events, opts)

  @spec realtime_websocket_url(ReqLlmNext.model_spec(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def realtime_websocket_url(model_source, opts \\ []),
    do: Realtime.websocket_url(model_source, opts)

  @spec realtime_session_update(keyword()) :: map()
  def realtime_session_update(opts \\ []), do: Realtime.session_update(opts)

  @spec realtime_conversation_item_create(map()) :: map()
  def realtime_conversation_item_create(item), do: Realtime.conversation_item_create(item)

  @spec realtime_input_audio_buffer_append(binary()) :: map()
  def realtime_input_audio_buffer_append(audio), do: Realtime.input_audio_buffer_append(audio)

  @spec realtime_input_audio_buffer_commit() :: map()
  def realtime_input_audio_buffer_commit, do: Realtime.input_audio_buffer_commit()

  @spec realtime_response_create(keyword()) :: map()
  def realtime_response_create(opts \\ []), do: Realtime.response_create(opts)

  @spec realtime_response_cancel() :: map()
  def realtime_response_cancel, do: Realtime.response_cancel()
end
