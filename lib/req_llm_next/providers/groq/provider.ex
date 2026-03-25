defmodule ReqLlmNext.Providers.Groq do
  @moduledoc """
  Groq provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.groq.com/openai/v1",
    env_key: "GROQ_API_KEY",
    auth_style: :bearer
end
