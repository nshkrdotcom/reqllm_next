defmodule ReqLlmNext.Providers.Alibaba do
  @moduledoc """
  Alibaba DashScope provider configuration.
  """

  @intl_base_url "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
  @cn_base_url "https://dashscope.aliyuncs.com/compatible-mode/v1"

  use ReqLlmNext.Provider,
    base_url: @intl_base_url,
    env_key: "DASHSCOPE_API_KEY",
    auth_style: :bearer

  @impl ReqLlmNext.Provider
  def base_url do
    System.get_env("DASHSCOPE_BASE_URL") || region_base_url(System.get_env("DASHSCOPE_REGION"))
  end

  defp region_base_url(region) when region in ["cn", "china", "beijing"], do: @cn_base_url
  defp region_base_url(_region), do: @intl_base_url
end
