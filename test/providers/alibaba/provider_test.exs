defmodule ReqLlmNext.Providers.Alibaba.ProviderTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Providers.Alibaba

  setup do
    original_base_url = ReqLlmNext.Env.get("DASHSCOPE_BASE_URL")
    original_region = ReqLlmNext.Env.get("DASHSCOPE_REGION")

    on_exit(fn ->
      restore_env("DASHSCOPE_BASE_URL", original_base_url)
      restore_env("DASHSCOPE_REGION", original_region)
    end)

    :ok
  end

  test "defaults to the international DashScope endpoint" do
    ReqLlmNext.Env.delete("DASHSCOPE_BASE_URL")
    ReqLlmNext.Env.delete("DASHSCOPE_REGION")

    assert Alibaba.base_url() == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
  end

  test "supports explicit base URL override" do
    ReqLlmNext.Env.put("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")
    ReqLlmNext.Env.delete("DASHSCOPE_REGION")

    assert Alibaba.base_url() == "https://dashscope.aliyuncs.com/compatible-mode/v1"
  end

  test "supports Beijing region shorthand" do
    ReqLlmNext.Env.delete("DASHSCOPE_BASE_URL")
    ReqLlmNext.Env.put("DASHSCOPE_REGION", "beijing")

    assert Alibaba.base_url() == "https://dashscope.aliyuncs.com/compatible-mode/v1"
  end

  defp restore_env(key, nil), do: ReqLlmNext.Env.delete(key)

  defp restore_env(key, value) do
    ReqLlmNext.Env.put(key, value)
  end
end
