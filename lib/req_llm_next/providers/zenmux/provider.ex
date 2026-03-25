defmodule ReqLlmNext.Providers.Zenmux do
  @moduledoc """
  Zenmux provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://zenmux.ai/api/v1",
    env_key: "ZENMUX_API_KEY",
    auth_style: :bearer
end
