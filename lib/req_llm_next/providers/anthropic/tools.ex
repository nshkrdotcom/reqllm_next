defmodule ReqLlmNext.Anthropic.Tools do
  @moduledoc """
  Anthropic-specific helper constructors for provider-native tools and MCP connectors.
  """

  @provider_marker :__req_llm_provider__
  @kind_marker :__req_llm_kind__

  @spec web_search(keyword()) :: map()
  def web_search(opts \\ []) do
    type =
      Keyword.get_lazy(opts, :type, fn ->
        if Keyword.get(opts, :dynamic_filtering, false) do
          "web_search_20260209"
        else
          "web_search_20250305"
        end
      end)

    %{
      type: type,
      name: Keyword.get(opts, :name, "web_search")
    }
    |> maybe_put(:max_uses, Keyword.get(opts, :max_uses))
    |> maybe_put(:allowed_domains, Keyword.get(opts, :allowed_domains))
    |> maybe_put(:blocked_domains, Keyword.get(opts, :blocked_domains))
    |> maybe_put(:user_location, Keyword.get(opts, :user_location))
    |> mark(:tool)
  end

  @spec code_execution(keyword()) :: map()
  def code_execution(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "code_execution_20250825"),
      name: Keyword.get(opts, :name, "code_execution")
    }
    |> maybe_put(:container, Keyword.get(opts, :container))
    |> mark(:tool)
  end

  @spec computer_use(keyword()) :: map()
  def computer_use(opts \\ []) do
    type =
      Keyword.get_lazy(opts, :type, fn ->
        if Keyword.get(opts, :version) in [:latest, "2025-11-24"] or
             Keyword.has_key?(opts, :enable_zoom) do
          "computer_20251124"
        else
          "computer_20250124"
        end
      end)

    %{
      type: type,
      name: Keyword.get(opts, :name, "computer"),
      display_width_px: Keyword.get(opts, :display_width_px, 1024),
      display_height_px: Keyword.get(opts, :display_height_px, 768),
      display_number: Keyword.get(opts, :display_number, 1)
    }
    |> maybe_put(:enable_zoom, Keyword.get(opts, :enable_zoom))
    |> mark(:tool)
  end

  @spec bash(keyword()) :: map()
  def bash(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "bash_20250124"),
      name: Keyword.get(opts, :name, "bash")
    }
    |> mark(:tool)
  end

  @spec text_editor(keyword()) :: map()
  def text_editor(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "text_editor_20250728"),
      name: Keyword.get(opts, :name, "str_replace_based_edit_tool")
    }
    |> maybe_put(:max_characters, Keyword.get(opts, :max_characters))
    |> mark(:tool)
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
    |> mark(:mcp_server)
  end

  @spec provider_native_tool?(term()) :: boolean()
  def provider_native_tool?(%{@provider_marker => :anthropic, @kind_marker => :tool}), do: true
  def provider_native_tool?(_), do: false

  @spec normalize_tool(map()) :: map()
  def normalize_tool(tool) when is_map(tool) do
    if provider_native_tool?(tool) do
      strip_internal_keys(tool)
    else
      raise ArgumentError,
            "Anthropic raw tool maps must come from ReqLlmNext.Anthropic helper constructors"
    end
  end

  @spec provider_native_mcp_server?(term()) :: boolean()
  def provider_native_mcp_server?(%{@provider_marker => :anthropic, @kind_marker => :mcp_server}),
    do: true

  def provider_native_mcp_server?(_), do: false

  @spec normalize_mcp_server(map()) :: map()
  def normalize_mcp_server(server) when is_map(server) do
    if provider_native_mcp_server?(server) do
      strip_internal_keys(server)
    else
      server
    end
  end

  defp mark(map, kind) do
    map
    |> Map.put(@provider_marker, :anthropic)
    |> Map.put(@kind_marker, kind)
  end

  defp strip_internal_keys(map) do
    Map.drop(map, [@provider_marker, @kind_marker])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
