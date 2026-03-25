defmodule ReqLlmNext.SurfacePreparation.CerebrasChat do
  @moduledoc """
  Cerebras chat surface-owned request validation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @unsupported_parameters [:frequency_penalty, :presence_penalty]

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()}
  def prepare(%ExecutionSurface{}, _prompt, opts), do: {:ok, opts}

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_unsupported_parameters(opts),
         :ok <- validate_tool_choice(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_unsupported_parameters(opts) do
    case Enum.find(@unsupported_parameters, &Keyword.has_key?(opts, &1)) do
      nil ->
        :ok

      parameter ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "#{parameter} is not supported on Cerebras chat surfaces"
         )}
    end
  end

  defp validate_tool_choice(opts) do
    case Keyword.get(opts, :tool_choice) do
      nil ->
        :ok

      "auto" ->
        :ok

      "none" ->
        :ok

      %{type: "function"} ->
        invalid_tool_choice()

      %{"type" => "function"} ->
        invalid_tool_choice()

      %{type: "tool"} ->
        invalid_tool_choice()

      %{"type" => "tool"} ->
        invalid_tool_choice()

      _other ->
        :ok
    end
  end

  defp invalid_tool_choice do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter: "tool_choice only supports \"auto\" or \"none\" on Cerebras chat surfaces"
     )}
  end
end
