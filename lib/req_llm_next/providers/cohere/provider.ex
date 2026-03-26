defmodule ReqLlmNext.Providers.Cohere do
  @moduledoc """
  Cohere provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.cohere.com",
    env_key: "COHERE_API_KEY",
    auth_style: :bearer
end
