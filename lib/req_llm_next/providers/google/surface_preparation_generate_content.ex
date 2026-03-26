defmodule ReqLlmNext.SurfacePreparation.GoogleGenerateContent do
  @moduledoc """
  Google generateContent surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, _prompt, opts), do: {:ok, opts}

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_api_version_feature_compatibility(opts),
         :ok <- validate_thinking_controls(opts),
         :ok <- validate_object_tool_conflict(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_api_version_feature_compatibility(opts) do
    provider_options = provider_options(opts)
    api_version = provider_options[:google_api_version] || "v1beta"

    cond do
      api_version == "v1" and tools_present?(opts) ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter:
             "function calling (tools) requires google_api_version: \"v1beta\" on Google surfaces"
         )}

      api_version == "v1" and grounding_present?(provider_options) ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter:
             "google_grounding and google_url_context require google_api_version: \"v1beta\" on Google surfaces"
         )}

      true ->
        :ok
    end
  end

  defp validate_thinking_controls(opts) do
    provider_options = provider_options(opts)

    if provider_options[:google_thinking_budget] != nil and
         provider_options[:google_thinking_level] != nil do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter:
           "google_thinking_budget and google_thinking_level cannot be combined in the same request"
       )}
    else
      :ok
    end
  end

  defp validate_object_tool_conflict(opts) do
    if Keyword.get(opts, :operation) == :object and tools_present?(opts) do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter:
           "tools are not supported with :object operation on Google generateContent surfaces"
       )}
    else
      :ok
    end
  end

  defp provider_options(opts) do
    case Keyword.get(opts, :provider_options, []) do
      map when is_map(map) -> Map.to_list(map)
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp tools_present?(opts) do
    case Keyword.get(opts, :tools) do
      tools when is_list(tools) and tools != [] -> true
      _ -> false
    end
  end

  defp grounding_present?(provider_options) do
    provider_options[:google_grounding] != nil or provider_options[:google_url_context] != nil
  end
end
