defmodule ReqLlmNext.Providers.VLLM do
  @moduledoc """
  vLLM provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "http://localhost:8000/v1",
    env_key: "OPENAI_API_KEY",
    auth_style: :bearer
end
