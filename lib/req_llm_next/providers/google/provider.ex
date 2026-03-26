defmodule ReqLlmNext.Providers.Google do
  @moduledoc """
  Google Gemini provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://generativelanguage.googleapis.com",
    env_key: "GOOGLE_API_KEY",
    auth_style: :bearer

  @impl ReqLlmNext.Provider
  def auth_headers(api_key) do
    [{"x-goog-api-key", api_key}]
  end
end
