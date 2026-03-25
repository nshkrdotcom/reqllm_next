defmodule ReqLlmNext.Providers.XAI do
  @moduledoc """
  xAI provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.x.ai",
    env_key: "XAI_API_KEY",
    auth_style: :bearer
end
