defmodule ReqLlmNext.Providers.ElevenLabs do
  @moduledoc """
  ElevenLabs provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.elevenlabs.io",
    env_key: "ELEVENLABS_API_KEY",
    auth_style: :x_api_key

  @impl ReqLlmNext.Provider
  def auth_headers(api_key) do
    [{"xi-api-key", api_key}]
  end
end
