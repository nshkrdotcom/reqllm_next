defmodule ReqLlmNext.Providers.ZAI do
  @moduledoc """
  Z.AI provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.z.ai/api/paas/v4",
    env_key: "ZAI_API_KEY",
    auth_style: :bearer
end
