defmodule ReqLlmNext.RuntimeMetadata do
  @moduledoc """
  Helpers for typed `LLMDB` runtime and execution metadata.
  """

  alias ReqLlmNext.Extensions

  @operations [:text, :object, :embed, :image, :transcription, :speech, :realtime]

  @local_family_ids %{
    "openai_chat_compatible" => :openai_chat_compatible,
    "openai_responses_compatible" => :openai_responses_compatible,
    "openai_embeddings" => :openai_chat_compatible,
    "openai_images" => :openai_images,
    "openai_transcription" => :openai_transcriptions,
    "openai_speech" => :openai_speech,
    "openai_realtime" => :openai_responses_compatible,
    "anthropic_messages" => :anthropic_messages,
    "google_generate_content" => :google_generate_content,
    "cohere_chat" => :cohere_chat,
    "elevenlabs_speech" => :elevenlabs_speech,
    "elevenlabs_transcription" => :elevenlabs_transcriptions
  }

  @spec operations() :: [atom()]
  def operations, do: @operations

  @spec registered_provider?(atom()) :: boolean()
  def registered_provider?(provider_id) when is_atom(provider_id) do
    match?({:ok, _provider}, Extensions.provider(Extensions.compiled_manifest(), provider_id))
  end

  @spec provider(LLMDB.Model.t()) :: {:ok, LLMDB.Provider.t()} | {:error, term()}
  def provider(%LLMDB.Model{provider: provider_id}) when is_atom(provider_id) do
    LLMDB.provider(provider_id)
  end

  @spec provider_runtime(LLMDB.Model.t()) :: {:ok, map()} | {:error, atom()}
  def provider_runtime(%LLMDB.Model{} = model) do
    with {:ok, provider} <- provider(model),
         runtime when is_map(runtime) <- provider.runtime do
      {:ok, runtime}
    else
      {:error, _reason} -> {:error, :missing_provider_runtime}
      _other -> {:error, :missing_provider_runtime}
    end
  end

  @spec execution_entry(LLMDB.Model.t(), atom()) :: {:ok, map()} | {:error, atom()}
  def execution_entry(%LLMDB.Model{} = model, operation) when operation in @operations do
    execution = model.execution || %{}
    entry = Map.get(execution, operation) || Map.get(execution, to_string(operation))

    cond do
      is_map(entry) and Map.get(entry, :supported) == true ->
        {:ok, entry}

      is_map(entry) ->
        {:error, :unsupported_operation}

      true ->
        {:error, :missing_execution_entry}
    end
  end

  @spec executable_execution?(LLMDB.Model.t()) :: boolean()
  def executable_execution?(%LLMDB.Model{} = model) do
    Enum.any?(@operations, fn operation ->
      match?({:ok, _entry}, execution_entry(model, operation))
    end)
  end

  @spec local_family_id(String.t() | map() | nil) :: atom() | nil
  def local_family_id(%{} = entry), do: local_family_id(Map.get(entry, :family))
  def local_family_id(family) when is_binary(family), do: Map.get(@local_family_ids, family)
  def local_family_id(_family), do: nil

  @spec known_family?(String.t() | nil) :: boolean()
  def known_family?(family) when is_binary(family), do: Map.has_key?(@local_family_ids, family)
  def known_family?(_family), do: false

  @spec primary_family(LLMDB.Model.t()) :: atom() | nil
  def primary_family(%LLMDB.Model{} = model) do
    Enum.find_value(@operations, fn operation ->
      case execution_entry(model, operation) do
        {:ok, entry} -> local_family_id(entry)
        {:error, _reason} -> nil
      end
    end)
  end

  @spec best_effort?(LLMDB.Model.t()) :: boolean()
  def best_effort?(%LLMDB.Model{} = model) do
    not registered_provider?(model.provider) and
      match?({:ok, _runtime}, provider_runtime(model)) and
      Enum.any?(@operations, fn operation ->
        case execution_entry(model, operation) do
          {:ok, entry} -> known_family?(Map.get(entry, :family))
          {:error, _reason} -> false
        end
      end)
  end

  @spec support_status(LLMDB.Model.t()) :: :first_class | :best_effort | {:unsupported, atom()}
  def support_status(%LLMDB.Model{} = model) do
    cond do
      registered_provider?(model.provider) ->
        :first_class

      model.catalog_only == true ->
        {:unsupported, :catalog_only}

      not executable_execution?(model) ->
        {:unsupported, :missing_execution_metadata}

      match?({:error, _reason}, provider_runtime(model)) ->
        {:unsupported, :missing_provider_runtime}

      best_effort?(model) ->
        :best_effort

      true ->
        {:unsupported, :unknown_execution_family}
    end
  end
end
