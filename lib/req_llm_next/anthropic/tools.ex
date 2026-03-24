defmodule ReqLlmNext.Anthropic.Tools do
  @moduledoc """
  Anthropic-specific helper constructors for provider-native tools and MCP connectors.
  """

  @spec web_search(keyword()) :: map()
  def web_search(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "web_search_20250305"),
      name: Keyword.get(opts, :name, "web_search")
    }
    |> maybe_put(:max_uses, Keyword.get(opts, :max_uses))
    |> maybe_put(:allowed_domains, Keyword.get(opts, :allowed_domains))
    |> maybe_put(:blocked_domains, Keyword.get(opts, :blocked_domains))
    |> maybe_put(:user_location, Keyword.get(opts, :user_location))
  end

  @spec code_execution(keyword()) :: map()
  def code_execution(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "code_execution_20250825"),
      name: Keyword.get(opts, :name, "code_execution")
    }
    |> maybe_put(:container, Keyword.get(opts, :container))
  end

  @spec computer_use(keyword()) :: map()
  def computer_use(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "computer_20250124"),
      name: Keyword.get(opts, :name, "computer"),
      display_width_px: Keyword.get(opts, :display_width_px, 1024),
      display_height_px: Keyword.get(opts, :display_height_px, 768),
      display_number: Keyword.get(opts, :display_number, 1)
    }
  end

  @spec bash(keyword()) :: map()
  def bash(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "bash_20250124"),
      name: Keyword.get(opts, :name, "bash")
    }
  end

  @spec text_editor(keyword()) :: map()
  def text_editor(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "text_editor_20250124"),
      name: Keyword.get(opts, :name, "text_editor")
    }
  end

  @spec mcp_server(String.t(), keyword()) :: map()
  def mcp_server(url, opts \\ []) when is_binary(url) do
    %{
      type: Keyword.get(opts, :type, "url"),
      url: url
    }
    |> maybe_put(:name, Keyword.get(opts, :name))
    |> maybe_put(:authorization_token, Keyword.get(opts, :authorization_token))
    |> maybe_put(:tool_configuration, Keyword.get(opts, :tool_configuration))
    |> maybe_put(:server_label, Keyword.get(opts, :server_label))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
