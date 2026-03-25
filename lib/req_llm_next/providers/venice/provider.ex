defmodule ReqLlmNext.Providers.Venice do
  @moduledoc """
  Venice provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.venice.ai/api/v1",
    env_key: "VENICE_API_KEY",
    auth_style: :bearer
end
