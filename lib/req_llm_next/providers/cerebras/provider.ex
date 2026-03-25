defmodule ReqLlmNext.Providers.Cerebras do
  @moduledoc """
  Cerebras provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.cerebras.ai/v1",
    env_key: "CEREBRAS_API_KEY",
    auth_style: :bearer
end
