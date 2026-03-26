defmodule ReqLlmNext.SurfacePreparation.ElevenLabsTranscriptions do
  @moduledoc """
  ElevenLabs transcription request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.Transcription.AudioInput

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, audio, opts) do
    with {:ok, resolved_audio} <- AudioInput.resolve(audio) do
      {:ok, Keyword.put(opts, :_resolved_audio_input, resolved_audio)}
    end
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_audio_input(opts),
         :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_audio_input(opts) do
    case Keyword.get(opts, :_resolved_audio_input) do
      %{data: data, media_type: media_type, filename: filename}
      when is_binary(data) and is_binary(media_type) and is_binary(filename) ->
        :ok

      _ ->
        case AudioInput.resolve(Keyword.get(opts, :_request_input)) do
          {:ok, _audio} -> :ok
          {:error, _} = error -> error
        end
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(parameter: "transcription does not support tools")}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(parameter: "transcription does not support streaming")}
    else
      :ok
    end
  end
end
