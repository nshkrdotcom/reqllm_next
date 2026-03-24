defmodule ReqLlmNext.SessionRuntimes.OpenAIResponses do
  @moduledoc false

  @behaviour ReqLlmNext.SessionRuntime

  alias ReqLlmNext.{Error, ExecutionPlan, Response}

  @impl ReqLlmNext.SessionRuntime
  def prepare(%ExecutionPlan{session_strategy: strategy}, user_opts, runtime_opts) do
    case {Map.get(strategy, :mode, :none), continuation_id(user_opts, runtime_opts)} do
      {:none, _id} ->
        {:ok, runtime_opts}

      {:preferred, nil} ->
        {:ok, runtime_opts}

      {:preferred, id} ->
        {:ok, Keyword.put(runtime_opts, :previous_response_id, id)}

      {mode, nil} when mode in [:required, :continue] ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter:
             "continue_from or previous_response_id is required for OpenAI Responses session continuation"
         )}

      {_mode, id} ->
        {:ok, Keyword.put(runtime_opts, :previous_response_id, id)}
    end
  end

  defp continuation_id(user_opts, runtime_opts) do
    runtime_opts
    |> Keyword.get(:previous_response_id)
    |> normalize_continuation_id()
    |> case do
      nil ->
        user_opts
        |> Keyword.get(:continue_from)
        |> continuation_from_source()

      id ->
        id
    end
  end

  defp continuation_from_source(%Response{provider_meta: provider_meta})
       when is_map(provider_meta) do
    provider_meta
    |> Map.get(:response_id, Map.get(provider_meta, "response_id"))
    |> normalize_continuation_id()
  end

  defp continuation_from_source(%{provider_meta: provider_meta}) when is_map(provider_meta) do
    provider_meta
    |> Map.get(:response_id, Map.get(provider_meta, "response_id"))
    |> normalize_continuation_id()
  end

  defp continuation_from_source(%{response_id: response_id}) do
    normalize_continuation_id(response_id)
  end

  defp continuation_from_source(%{"response_id" => response_id}) do
    normalize_continuation_id(response_id)
  end

  defp continuation_from_source(response_id) when is_binary(response_id) do
    normalize_continuation_id(response_id)
  end

  defp continuation_from_source(_source), do: nil

  defp normalize_continuation_id(response_id) when is_binary(response_id) do
    if String.trim(response_id) == "", do: nil, else: response_id
  end

  defp normalize_continuation_id(_response_id), do: nil
end
