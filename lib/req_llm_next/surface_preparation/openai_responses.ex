defmodule ReqLlmNext.SurfacePreparation.OpenAIResponses do
  @moduledoc """
  OpenAI Responses surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{wire_format: :openai_responses_ws_json}, _prompt, opts) do
    if Keyword.has_key?(opts, :temperature) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "temperature is not supported for OpenAI Responses WebSocket mode"
       )}
    else
      {:ok, opts}
    end
  end

  def prepare(%ExecutionSurface{}, _prompt, opts), do: {:ok, opts}
end
