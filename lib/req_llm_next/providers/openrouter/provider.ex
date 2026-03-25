defmodule ReqLlmNext.Providers.OpenRouter do
  @moduledoc """
  OpenRouter provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://openrouter.ai/api/v1",
    env_key: "OPENROUTER_API_KEY",
    auth_style: :bearer
end
