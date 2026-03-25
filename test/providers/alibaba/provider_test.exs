defmodule ReqLlmNext.Providers.Alibaba.ProviderTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Providers.Alibaba

  setup do
    original_base_url = System.get_env("DASHSCOPE_BASE_URL")
    original_region = System.get_env("DASHSCOPE_REGION")

    on_exit(fn ->
      restore_env("DASHSCOPE_BASE_URL", original_base_url)
      restore_env("DASHSCOPE_REGION", original_region)
    end)

    :ok
  end

  test "defaults to the international DashScope endpoint" do
    System.delete_env("DASHSCOPE_BASE_URL")
    System.delete_env("DASHSCOPE_REGION")

    assert Alibaba.base_url() == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
  end

  test "supports explicit base URL override" do
    System.put_env("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")
    System.delete_env("DASHSCOPE_REGION")

    assert Alibaba.base_url() == "https://dashscope.aliyuncs.com/compatible-mode/v1"
  end

  test "supports Beijing region shorthand" do
    System.delete_env("DASHSCOPE_BASE_URL")
    System.put_env("DASHSCOPE_REGION", "beijing")

    assert Alibaba.base_url() == "https://dashscope.aliyuncs.com/compatible-mode/v1"
  end

  defp restore_env(_key, nil), do: :ok

  defp restore_env(key, value) do
    System.put_env(key, value)
  end
end
