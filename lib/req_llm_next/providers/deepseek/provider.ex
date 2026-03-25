defmodule ReqLlmNext.Providers.DeepSeek do
  @moduledoc """
  DeepSeek provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.deepseek.com",
    env_key: "DEEPSEEK_API_KEY",
    auth_style: :bearer
end
