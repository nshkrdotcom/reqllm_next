defmodule ReqLlmNext.ProvidersTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers

  alias ReqLlmNext.Providers.{
    Alibaba,
    Anthropic,
    Cerebras,
    DeepSeek,
    Groq,
    OpenAI,
    OpenRouter,
    VLLM,
    Venice,
    ZAI,
    XAI
  }

  describe "Providers.get/1" do
    test "returns OpenAI module for :openai" do
      assert Providers.get(:openai) == {:ok, OpenAI}
    end

    test "returns Anthropic module for :anthropic" do
      assert Providers.get(:anthropic) == {:ok, Anthropic}
    end

    test "returns DeepSeek module for :deepseek" do
      assert Providers.get(:deepseek) == {:ok, DeepSeek}
    end

    test "returns Groq module for :groq" do
      assert Providers.get(:groq) == {:ok, Groq}
    end

    test "returns OpenRouter module for :openrouter" do
      assert Providers.get(:openrouter) == {:ok, OpenRouter}
    end

    test "returns vLLM module for :vllm" do
      assert Providers.get(:vllm) == {:ok, VLLM}
    end

    test "returns xAI module for :xai" do
      assert Providers.get(:xai) == {:ok, XAI}
    end

    test "returns Venice module for :venice" do
      assert Providers.get(:venice) == {:ok, Venice}
    end

    test "returns Alibaba module for :alibaba" do
      assert Providers.get(:alibaba) == {:ok, Alibaba}
    end

    test "returns Cerebras module for :cerebras" do
      assert Providers.get(:cerebras) == {:ok, Cerebras}
    end

    test "returns Z.AI module for :zai" do
      assert Providers.get(:zai) == {:ok, ZAI}
    end

    test "returns error for unknown provider" do
      assert Providers.get(:unknown) == {:error, {:unknown_provider, :unknown}}
    end
  end

  describe "Providers.get!/1" do
    test "returns OpenAI module for :openai" do
      assert Providers.get!(:openai) == OpenAI
    end

    test "returns Anthropic module for :anthropic" do
      assert Providers.get!(:anthropic) == Anthropic
    end

    test "returns DeepSeek module for :deepseek" do
      assert Providers.get!(:deepseek) == DeepSeek
    end

    test "returns Groq module for :groq" do
      assert Providers.get!(:groq) == Groq
    end

    test "returns OpenRouter module for :openrouter" do
      assert Providers.get!(:openrouter) == OpenRouter
    end

    test "returns vLLM module for :vllm" do
      assert Providers.get!(:vllm) == VLLM
    end

    test "returns xAI module for :xai" do
      assert Providers.get!(:xai) == XAI
    end

    test "returns Venice module for :venice" do
      assert Providers.get!(:venice) == Venice
    end

    test "returns Alibaba module for :alibaba" do
      assert Providers.get!(:alibaba) == Alibaba
    end

    test "returns Cerebras module for :cerebras" do
      assert Providers.get!(:cerebras) == Cerebras
    end

    test "returns Z.AI module for :zai" do
      assert Providers.get!(:zai) == ZAI
    end

    test "raises for unknown provider" do
      assert_raise RuntimeError, ~r/Provider error/, fn ->
        Providers.get!(:unknown)
      end
    end
  end

  describe "Providers.list/0" do
    test "returns list of supported providers" do
      providers = Providers.list()

      assert :openai in providers
      assert :anthropic in providers
      assert :deepseek in providers
      assert :groq in providers
      assert :openrouter in providers
      assert :vllm in providers
      assert :xai in providers
      assert :venice in providers
      assert :alibaba in providers
      assert :cerebras in providers
      assert :zai in providers
    end
  end

  describe "Providers.OpenAI" do
    test "base_url returns OpenAI API URL" do
      assert OpenAI.base_url() == "https://api.openai.com"
    end

    test "env_key returns OPENAI_API_KEY" do
      assert OpenAI.env_key() == "OPENAI_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = OpenAI.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Anthropic" do
    test "base_url returns Anthropic API URL" do
      assert Anthropic.base_url() == "https://api.anthropic.com"
    end

    test "env_key returns ANTHROPIC_API_KEY" do
      assert Anthropic.env_key() == "ANTHROPIC_API_KEY"
    end

    test "auth_headers returns x-api-key" do
      headers = Anthropic.auth_headers("test-key")

      assert {"x-api-key", "test-key"} in headers
    end

    test "headers includes auth and wire headers" do
      headers = Anthropic.headers("test-key")

      assert {"x-api-key", "test-key"} in headers
      assert {"anthropic-version", "2023-06-01"} in headers
    end

    test "headers includes beta flags when thinking enabled" do
      headers = Anthropic.headers("test-key", thinking: %{type: "enabled"})

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "interleaved-thinking"
    end
  end

  describe "Providers.DeepSeek" do
    test "base_url returns DeepSeek API URL" do
      assert DeepSeek.base_url() == "https://api.deepseek.com"
    end

    test "env_key returns DEEPSEEK_API_KEY" do
      assert DeepSeek.env_key() == "DEEPSEEK_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = DeepSeek.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Groq" do
    test "base_url returns Groq API URL" do
      assert Groq.base_url() == "https://api.groq.com/openai/v1"
    end

    test "env_key returns GROQ_API_KEY" do
      assert Groq.env_key() == "GROQ_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = Groq.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.OpenRouter" do
    test "base_url returns OpenRouter API URL" do
      assert OpenRouter.base_url() == "https://openrouter.ai/api/v1"
    end

    test "env_key returns OPENROUTER_API_KEY" do
      assert OpenRouter.env_key() == "OPENROUTER_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = OpenRouter.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.VLLM" do
    test "base_url returns vLLM default URL" do
      assert VLLM.base_url() == "http://localhost:8000/v1"
    end

    test "env_key returns OPENAI_API_KEY" do
      assert VLLM.env_key() == "OPENAI_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = VLLM.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.XAI" do
    test "base_url returns xAI API URL" do
      assert XAI.base_url() == "https://api.x.ai"
    end

    test "env_key returns XAI_API_KEY" do
      assert XAI.env_key() == "XAI_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = XAI.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Venice" do
    test "base_url returns Venice API URL" do
      assert Venice.base_url() == "https://api.venice.ai/api/v1"
    end

    test "env_key returns VENICE_API_KEY" do
      assert Venice.env_key() == "VENICE_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = Venice.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Alibaba" do
    test "base_url returns DashScope international URL by default" do
      System.delete_env("DASHSCOPE_BASE_URL")
      System.delete_env("DASHSCOPE_REGION")

      assert Alibaba.base_url() == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    end

    test "env_key returns DASHSCOPE_API_KEY" do
      assert Alibaba.env_key() == "DASHSCOPE_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = Alibaba.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Cerebras" do
    test "base_url returns Cerebras API URL" do
      assert Cerebras.base_url() == "https://api.cerebras.ai/v1"
    end

    test "env_key returns CEREBRAS_API_KEY" do
      assert Cerebras.env_key() == "CEREBRAS_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = Cerebras.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.ZAI" do
    test "base_url returns Z.AI API URL" do
      assert ZAI.base_url() == "https://api.z.ai/api/paas/v4"
    end

    test "env_key returns ZAI_API_KEY" do
      assert ZAI.env_key() == "ZAI_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = ZAI.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Provider.build_auth_headers/2" do
    test "builds bearer auth header" do
      headers = Provider.build_auth_headers(:bearer, "my-token")
      assert headers == [{"Authorization", "Bearer my-token"}]
    end

    test "builds x-api-key auth header" do
      headers = Provider.build_auth_headers(:x_api_key, "my-key")
      assert headers == [{"x-api-key", "my-key"}]
    end
  end

  describe "get_api_key/1" do
    test "OpenAI returns api_key from opts" do
      test_key = "test-key-openai"
      key = OpenAI.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "Anthropic returns api_key from opts" do
      test_key = "test-key-anthropic"
      key = Anthropic.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "Groq returns api_key from opts" do
      test_key = "test-key-groq"
      key = Groq.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "OpenRouter returns api_key from opts" do
      test_key = "test-key-openrouter"
      key = OpenRouter.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "vLLM returns api_key from opts" do
      test_key = "test-key-vllm"
      key = VLLM.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "xAI returns api_key from opts" do
      test_key = "test-key-xai"
      key = XAI.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "OpenAI raises when no key available" do
      original = System.get_env("OPENAI_API_KEY")
      System.delete_env("OPENAI_API_KEY")

      try do
        assert_raise RuntimeError, ~r/OPENAI_API_KEY not set/, fn ->
          OpenAI.get_api_key([])
        end
      after
        if original, do: System.put_env("OPENAI_API_KEY", original)
      end
    end

    test "Anthropic raises when no key available" do
      original = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      try do
        assert_raise RuntimeError, ~r/ANTHROPIC_API_KEY not set/, fn ->
          Anthropic.get_api_key([])
        end
      after
        if original, do: System.put_env("ANTHROPIC_API_KEY", original)
      end
    end
  end
end
