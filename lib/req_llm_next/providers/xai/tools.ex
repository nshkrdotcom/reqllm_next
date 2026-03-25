defmodule ReqLlmNext.XAI.Tools do
  @moduledoc """
  xAI-specific helpers for provider-native built-in tools.
  """

  @provider_native_marker :__provider_native__
  @built_in_tool_types MapSet.new([
                         "web_search",
                         "x_search",
                         "code_execution",
                         "file_search"
                       ])

  @spec web_search(keyword()) :: map()
  def web_search(opts \\ []) do
    provider_tool("web_search", opts)
  end

  @spec x_search(keyword()) :: map()
  def x_search(opts \\ []) do
    provider_tool("x_search", opts)
  end

  @spec code_execution(keyword()) :: map()
  def code_execution(opts \\ []) do
    provider_tool("code_execution", opts)
  end

  @spec file_search(keyword()) :: map()
  def file_search(opts \\ []) do
    provider_tool("file_search", opts)
  end

  @spec provider_native_tool?(map()) :: boolean()
  def provider_native_tool?(tool) when is_map(tool) do
    provider_native_marker(tool) == :xai and
      MapSet.member?(@built_in_tool_types, tool_type(tool))
  end

  def provider_native_tool?(_tool), do: false

  @spec encode_provider_native_tool(map()) :: {:ok, map()} | :error
  def encode_provider_native_tool(tool) when is_map(tool) do
    if provider_native_tool?(tool) do
      {:ok, Map.drop(tool, [@provider_native_marker, "__provider_native__"])}
    else
      :error
    end
  end

  defp provider_native_marker(tool) do
    Map.get(tool, @provider_native_marker) || Map.get(tool, "__provider_native__")
  end

  defp tool_type(tool) do
    Map.get(tool, :type) || Map.get(tool, "type")
  end

  defp provider_tool(type, opts) when is_binary(type) and is_list(opts) do
    opts
    |> Enum.into(%{@provider_native_marker => :xai, type: type})
  end
end
