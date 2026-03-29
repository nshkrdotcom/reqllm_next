defmodule ReqLlmNext.SurfacePreparation.GoogleEmbeddings do
  @moduledoc """
  Google embedding request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, _input, opts), do: {:ok, opts}

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(parameter: "Google embeddings do not support tools")}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(parameter: "Google embeddings do not support streaming")}
    else
      :ok
    end
  end
end
