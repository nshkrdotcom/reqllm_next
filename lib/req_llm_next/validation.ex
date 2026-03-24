defmodule ReqLlmNext.Validation do
  @moduledoc """
  Validates operations against model capabilities using LLMDB metadata.

  No model-name heuristics - all checks derive from metadata.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.ExecutionMode
  alias ReqLlmNext.Error
  alias ReqLlmNext.ModelProfile

  @type operation :: :text | :object | :embed

  @spec validate!(ModelProfile.t(), ExecutionMode.t()) :: :ok | no_return()
  def validate!(%ModelProfile{} = profile, %ExecutionMode{} = mode) do
    with :ok <- validate_operation(profile, mode.operation),
         :ok <- validate_modalities(profile, mode),
         :ok <- validate_capabilities(profile, mode) do
      :ok
    else
      {:error, error} -> raise error
    end
  end

  @spec validate!(LLMDB.Model.t(), operation(), Context.t() | nil, keyword()) :: :ok | no_return()
  def validate!(%LLMDB.Model{} = model, operation, context, opts) do
    {:ok, profile} = ModelProfile.from_model(model)

    {:ok, mode} =
      ExecutionMode.from_request(
        operation,
        context || "",
        normalize_legacy_opts(opts)
      )

    validate!(profile, mode)
  end

  @spec validate_stream!(LLMDB.Model.t(), String.t() | Context.t(), keyword()) :: :ok
  def validate_stream!(model, prompt, opts) do
    {:ok, profile} = ModelProfile.from_model(model)
    {:ok, mode} = ExecutionMode.from_request(:text, prompt, normalize_legacy_opts(opts))
    validate!(profile, mode)
  end

  @spec validate_operation(ModelProfile.t(), operation()) :: :ok | {:error, term()}
  defp validate_operation(profile, operation) do
    kind = profile_kind(profile)

    case {kind, operation} do
      {:embedding, :text} ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Embedding model #{profile.model_id} cannot generate text"
         )}

      {:embedding, :object} ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Embedding model #{profile.model_id} cannot generate objects"
         )}

      {k, :embed} when k != :embedding ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{profile.model_id} does not support embeddings"
         )}

      _ ->
        :ok
    end
  end

  @spec validate_modalities(ModelProfile.t(), ExecutionMode.t()) :: :ok | {:error, term()}
  defp validate_modalities(profile, mode) do
    input_modalities = MapSet.new(ModelProfile.input_modalities(profile))
    requested_modalities = MapSet.new(mode.input_modalities)
    has_images = MapSet.member?(requested_modalities, :image)
    has_documents = MapSet.member?(requested_modalities, :document)

    cond do
      has_images and not MapSet.member?(input_modalities, :image) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{profile.model_id} does not support image inputs",
           missing: [:vision]
         )}

      has_documents and not ModelProfile.feature_supported?(profile, :document_input) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{profile.model_id} does not support document inputs",
           missing: [:documents]
         )}

      true ->
        :ok
    end
  end

  @spec validate_capabilities(ModelProfile.t(), ExecutionMode.t()) :: :ok | {:error, term()}
  defp validate_capabilities(profile, mode) do
    cond do
      mode.tools? and not ModelProfile.feature_supported?(profile, :tools) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{profile.model_id} does not support tool calling",
           missing: [:tools]
         )}

      mode.stream? and not ModelProfile.supports_streaming?(profile, mode.operation) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{profile.model_id} does not support streaming",
           missing: [:streaming]
         )}

      true ->
        :ok
    end
  end

  defp normalize_legacy_opts(opts) do
    if Keyword.get(opts, :stream, false) do
      Keyword.put(opts, :_stream?, true)
    else
      opts
    end
  end

  defp profile_kind(%ModelProfile{} = profile) do
    if ModelProfile.supports_operation?(profile, :embed) and
         not ModelProfile.supports_operation?(profile, :text) do
      :embedding
    else
      :chat
    end
  end
end
