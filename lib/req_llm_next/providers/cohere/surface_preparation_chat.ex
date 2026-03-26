defmodule ReqLlmNext.SurfacePreparation.CohereChat do
  @moduledoc """
  Cohere chat surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, _prompt, opts), do: {:ok, opts}

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_no_tools(opts),
         :ok <- validate_object_document_conflict(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error, Error.Invalid.Parameter.exception(parameter: "Cohere chat does not support tools")}
    end
  end

  defp validate_object_document_conflict(opts) do
    provider_options = normalize_provider_options(Keyword.get(opts, :provider_options, []))

    if Keyword.get(opts, :operation) == :object and
         (provider_options[:documents] != nil or provider_options[:citation_options] != nil) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter:
           "Cohere response_format json_schema is not supported together with provider_options documents or citation_options"
       )}
    else
      :ok
    end
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []
end
