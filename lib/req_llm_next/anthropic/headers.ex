defmodule ReqLlmNext.Anthropic.Headers do
  @moduledoc """
  Anthropic request-header builder shared by Messages and provider utility endpoints.
  """

  @anthropic_version "2023-06-01"
  @beta_thinking "interleaved-thinking-2025-05-14"
  @beta_prompt_caching "prompt-caching-2024-07-31"
  @beta_context_1m "context-1m-2025-08-07"
  @beta_files_api "files-api-2025-04-14"
  @beta_code_execution "code-execution-2025-08-25"
  @beta_mcp_client "mcp-client-2025-04-04"
  @beta_computer_use "computer-use-2025-01-24"
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
      if Keyword.get(opts, :anthropic_prompt_cache, false) == true,
        do: [@beta_prompt_caching | flags],
        else: flags

    flags =
      if Keyword.get(opts, :anthropic_context_1m, false) == true,
        do: [@beta_context_1m | flags],
        else: flags

    flags =
      if Keyword.get(opts, :anthropic_files_api, false) == true,
        do: [@beta_files_api | flags],
        else: flags

    flags = if has_code_execution_tools?(opts), do: [@beta_code_execution | flags], else: flags
    flags = if has_mcp_connectors?(opts), do: [@beta_mcp_client | flags], else: flags
    flags = if has_computer_use_tools?(opts), do: [@beta_computer_use | flags], else: flags

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

  defp has_code_execution_tools?(opts) do
    Enum.any?(Keyword.get(opts, :tools, []), &tool_type?(&1, "code_execution"))
  end

  defp has_mcp_connectors?(opts) do
    mcp_servers = Keyword.get(opts, :mcp_servers, [])
    mcp_servers != [] or Enum.any?(Keyword.get(opts, :tools, []), &tool_type?(&1, "mcp"))
  end

  defp has_computer_use_tools?(opts) do
    Enum.any?(Keyword.get(opts, :tools, []), fn tool ->
      tool_type?(tool, "computer") or tool_type?(tool, "text_editor") or tool_type?(tool, "bash")
    end)
  end

  defp tool_type?(%{type: type}, prefix) when is_binary(type),
    do: String.starts_with?(type, prefix)

  defp tool_type?(_, _prefix), do: false

  defp custom_beta_flags(opts) do
    case Keyword.get(opts, :anthropic_beta_headers, []) do
      flags when is_binary(flags) -> [flags]
      flags when is_list(flags) -> Enum.filter(flags, &is_binary/1)
      _ -> []
    end
  end
end
