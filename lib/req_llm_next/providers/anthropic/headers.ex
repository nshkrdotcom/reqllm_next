defmodule ReqLlmNext.Anthropic.Headers do
  @moduledoc """
  Anthropic request-header builder shared by Messages and provider utility endpoints.
  """

  @anthropic_version "2023-06-01"
  @beta_thinking "interleaved-thinking-2025-05-14"
  @beta_context_1m "context-1m-2025-08-07"
  @beta_context_management "context-management-2025-06-27"
  @beta_compaction "compact-2026-01-12"
  @beta_files_api "files-api-2025-04-14"
  @beta_token_efficient_tools "token-efficient-tools-2025-02-19"

  @spec headers(keyword()) :: [{String.t(), String.t()}]
  def headers(opts \\ []) do
    base_headers = [
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]

    beta_flags = beta_flags(opts)

    if beta_flags != "" do
      [{"anthropic-beta", beta_flags} | base_headers]
    else
      base_headers
    end
  end

  @spec common_headers(keyword()) :: [{String.t(), String.t()}]
  def common_headers(opts \\ []) do
    headers(opts)
    |> Enum.reject(fn {key, _value} -> String.downcase(key) == "content-type" end)
  end

  defp beta_flags(opts) do
    flags = []
    flags = if has_thinking?(opts), do: [@beta_thinking | flags], else: flags

    flags =
      if Keyword.get(opts, :anthropic_context_1m, false) == true,
        do: [@beta_context_1m | flags],
        else: flags

    flags =
      if has_context_management?(opts),
        do: [@beta_context_management | flags],
        else: flags

    flags =
      if has_compaction?(opts),
        do: [@beta_compaction | flags],
        else: flags

    flags =
      if Keyword.get(opts, :anthropic_files_api, false) == true,
        do: [@beta_files_api | flags],
        else: flags

    flags =
      if Keyword.get(opts, :anthropic_token_efficient_tools, false) == true,
        do: [@beta_token_efficient_tools | flags],
        else: flags

    flags = custom_beta_flags(opts) ++ flags

    flags
    |> Enum.reverse()
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp has_thinking?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp has_context_management?(opts) do
    case Keyword.get(opts, :context_management) do
      %{compact: true} -> true
      %{compact: compact} when is_map(compact) and map_size(compact) > 0 -> true
      %{edits: edits} when is_list(edits) and edits != [] -> true
      _ -> false
    end
  end

  defp has_compaction?(opts) do
    case Keyword.get(opts, :context_management) do
      %{compact: true} ->
        true

      %{compact: compact} when is_map(compact) and map_size(compact) > 0 ->
        true

      %{edits: edits} when is_list(edits) ->
        Enum.any?(edits, &compaction_edit?/1)

      _ ->
        false
    end
  end

  defp compaction_edit?(%{type: "compact_20260112"}), do: true
  defp compaction_edit?(%{"type" => "compact_20260112"}), do: true
  defp compaction_edit?(_edit), do: false

  defp custom_beta_flags(opts) do
    case Keyword.get(opts, :anthropic_beta_headers, []) do
      flags when is_binary(flags) -> [flags]
      flags when is_list(flags) -> Enum.filter(flags, &is_binary/1)
      _ -> []
    end
  end
end
