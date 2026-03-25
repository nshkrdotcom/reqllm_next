defmodule ReqLlmNext.SurfacePreparation.OpenAISpeech do
  @moduledoc """
  OpenAI speech-generation request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, text, opts) do
    with {:ok, prepared_text} <- normalize_text(text) do
      {:ok, Keyword.put(opts, :_prepared_text, prepared_text)}
    end
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <-
           validate_text(Keyword.get(opts, :_prepared_text, Keyword.get(opts, :_request_input))),
         :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_text(text) when is_binary(text) do
    if text == "" do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "speech generation requires non-empty input text"
       )}
    else
      :ok
    end
  end

  defp validate_text(_text) do
    {:error, Error.Invalid.Parameter.exception(parameter: "speech generation expects text input")}
  end

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> case do
      "" ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "speech generation requires non-empty input text"
         )}

      normalized ->
        {:ok, normalized}
    end
  end

  defp normalize_text(_text) do
    {:error, Error.Invalid.Parameter.exception(parameter: "speech generation expects text input")}
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(parameter: "speech generation does not support tools")}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "speech generation does not support streaming"
       )}
    else
      :ok
    end
  end
end
