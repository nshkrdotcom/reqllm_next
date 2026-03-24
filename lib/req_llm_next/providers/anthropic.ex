defmodule ReqLlmNext.Providers.Anthropic do
  @moduledoc """
  Anthropic provider configuration.
  """

  alias ReqLlmNext.Anthropic.Headers

  use ReqLlmNext.Provider,
    base_url: "https://api.anthropic.com",
    env_key: "ANTHROPIC_API_KEY",
    auth_style: :x_api_key

  @impl ReqLlmNext.Provider
  def auth_headers(api_key) do
    [{"x-api-key", api_key}]
  end

  @doc """
  Build complete headers including auth and beta features.

  Called by Streaming.build_request to get all required headers.
  The wire module headers (including anthropic-version and beta flags)
  are added by the streaming module.
  """
  def headers(api_key, opts \\ []) do
    auth = auth_headers(api_key)
    wire_headers = Headers.headers(opts)
    auth ++ wire_headers
  end
end
