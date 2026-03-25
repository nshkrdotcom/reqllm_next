defmodule ReqLlmNext.ModelHelpers do
  @moduledoc """
  Helper functions for querying LLMDB.Model capabilities.

  Defines helper functions for common capability checks, centralizing knowledge
  of the model capability structure.

  These helpers ensure consistency when checking model capabilities across the codebase
  and provide a single source of truth for capability access patterns.

  ## Usage

      alias ReqLlmNext.ModelHelpers

      # Check if model supports chat
      ModelHelpers.chat?(model)

      # Check if model supports tool calling
      ModelHelpers.tools_enabled?(model)

      # Check if model supports streaming
      ModelHelpers.streaming_text?(model)
  """

  alias ReqLlmNext.ModelProfile.ProviderFacts

  @capability_checks [
    {:reasoning_enabled?, [:reasoning, :enabled]},
    {:json_native?, [:json, :native]},
    {:json_schema?, [:json, :schema]},
    {:json_strict?, [:json, :strict]},
    {:tools_enabled?, [:tools, :enabled]},
    {:tools_strict?, [:tools, :strict]},
    {:tools_parallel?, [:tools, :parallel]},
    {:tools_streaming?, [:tools, :streaming]},
    {:chat?, [:chat]},
    {:embeddings?, [:embeddings]}
  ]

  for {function_name, path} <- @capability_checks do
    path_str = Enum.map_join(path, ".", &to_string/1)

    @doc """
    Check if model has `#{path_str}` capability.

    Returns `true` if `model.capabilities.#{path_str}` is `true`.
    """
    def unquote(function_name)(%LLMDB.Model{} = model) do
      capability_enabled?(Map.get(model, :capabilities), unquote(path))
    end

    def unquote(function_name)(_), do: false
  end

  @doc """
  Check if model supports streaming text responses.

  Chat models are treated as text-streaming capable unless metadata explicitly
  disables text streaming.
  """
  @spec streaming_text?(LLMDB.Model.t()) :: boolean()
  def streaming_text?(%LLMDB.Model{} = model) do
    case get_in(model.capabilities, [:streaming, :text]) do
      false -> false
      true -> true
      nil -> chat?(model)
    end
  end

  def streaming_text?(_), do: false

  @doc """
  Check if model supports streaming tool call payloads.
  """
  @spec streaming_tool_calls?(LLMDB.Model.t()) :: boolean()
  def streaming_tool_calls?(%LLMDB.Model{} = model) do
    case get_in(model.capabilities, [:streaming, :tool_calls]) do
      false -> false
      true -> true
      nil -> tools_enabled?(model)
    end
  end

  def streaming_tool_calls?(_), do: false

  @doc """
  Check if model supports object generation through the top-level API.

  Chat-capable models support `generate_object/4`, either through native JSON
  schema features or through prompt-and-parse fallback.
  """
  @spec supports_object_generation?(LLMDB.Model.t()) :: boolean()
  def supports_object_generation?(%LLMDB.Model{} = model) do
    chat?(model)
  end

  def supports_object_generation?(_), do: false

  @doc """
  Check if model supports streaming object generation.

  Requires object generation support plus streaming text output.
  """
  @spec supports_streaming_object_generation?(LLMDB.Model.t()) :: boolean()
  def supports_streaming_object_generation?(%LLMDB.Model{} = model) do
    supports_object_generation?(model) and streaming_text?(model)
  end

  def supports_streaming_object_generation?(_), do: false

  @doc """
  Check if model supports image generation.
  """
  @spec supports_image_generation?(LLMDB.Model.t()) :: boolean()
  def supports_image_generation?(%LLMDB.Model{} = model) do
    capability_enabled?(Map.get(model, :capabilities), [:images]) or
      Map.get(model.modalities || %{}, :output, []) == [:image] or
      ProviderFacts.extract(model).image_generation_supported?
  end

  def supports_image_generation?(_), do: false

  @doc """
  Check if model supports transcription.
  """
  @spec supports_transcription?(LLMDB.Model.t()) :: boolean()
  def supports_transcription?(%LLMDB.Model{} = model) do
    capability_enabled?(Map.get(model, :capabilities), [:transcription]) or
      ProviderFacts.extract(model).transcription_supported?
  end

  def supports_transcription?(_), do: false

  @doc """
  Check if model supports speech generation.
  """
  @spec supports_speech_generation?(LLMDB.Model.t()) :: boolean()
  def supports_speech_generation?(%LLMDB.Model{} = model) do
    capability_enabled?(Map.get(model, :capabilities), [:speech]) or
      ProviderFacts.extract(model).speech_supported?
  end

  def supports_speech_generation?(_), do: false

  @doc """
  Check if model supports image input modality.
  """
  @spec supports_image_input?(LLMDB.Model.t()) :: boolean()
  def supports_image_input?(%LLMDB.Model{} = model) do
    chat?(model) and :image in (model.modalities[:input] || [])
  end

  def supports_image_input?(_), do: false

  @doc """
  Check if model supports audio input modality.
  """
  @spec supports_audio_input?(LLMDB.Model.t()) :: boolean()
  def supports_audio_input?(%LLMDB.Model{} = model) do
    chat?(model) and :audio in (model.modalities[:input] || [])
  end

  def supports_audio_input?(_), do: false

  @doc """
  Check if model supports PDF input modality.
  """
  @spec supports_pdf_input?(LLMDB.Model.t()) :: boolean()
  def supports_pdf_input?(%LLMDB.Model{} = model) do
    chat?(model) and :pdf in (model.modalities[:input] || [])
  end

  def supports_pdf_input?(_), do: false

  @doc """
  List all available capability helper functions.
  """
  @spec list_helpers() :: [atom()]
  def list_helpers do
    @capability_checks
    |> Enum.map(fn {name, _path} -> name end)
    |> Kernel.++([
      :streaming_text?,
      :streaming_tool_calls?,
      :supports_image_generation?,
      :supports_transcription?,
      :supports_speech_generation?
    ])
    |> Enum.sort()
  end

  defp capability_enabled?(nil, _path), do: false
  defp capability_enabled?(value, []) when is_map(value), do: map_size(value) > 0
  defp capability_enabled?(value, []), do: value == true

  defp capability_enabled?(value, [segment | rest]) when is_map(value) do
    capability_enabled?(Map.get(value, segment), rest)
  end

  defp capability_enabled?(true, [:enabled]), do: true
  defp capability_enabled?(_value, _path), do: false
end
