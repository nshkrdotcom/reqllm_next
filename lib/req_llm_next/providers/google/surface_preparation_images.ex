defmodule ReqLlmNext.SurfacePreparation.GoogleImages do
  @moduledoc """
  Google image-generation request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    {:ok,
     opts
     |> Keyword.put(:_prepared_prompt, prompt)
     |> ensure_response_modalities()}
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp ensure_response_modalities(opts) do
    provider_options =
      case Keyword.get(opts, :provider_options, []) do
        map when is_map(map) -> Map.to_list(map)
        list when is_list(list) -> list
        _ -> []
      end

    if Keyword.has_key?(provider_options, :response_modalities) do
      Keyword.put(opts, :provider_options, provider_options)
    else
      Keyword.put(
        opts,
        :provider_options,
        Keyword.put(provider_options, :response_modalities, ["IMAGE"])
      )
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "Google image generation does not support tools"
       )}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "Google image generation does not support streaming"
       )}
    else
      :ok
    end
  end
end
