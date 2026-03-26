defmodule ReqLlmNext.Providers.Generic do
  @moduledoc false

  @behaviour ReqLlmNext.Provider

  @impl ReqLlmNext.Provider
  def base_url do
    raise "Generic provider requires runtime metadata"
  end

  @impl ReqLlmNext.Provider
  def env_key do
    raise "Generic provider requires runtime metadata"
  end

  @impl ReqLlmNext.Provider
  def auth_headers(_api_key) do
    raise "Generic provider requires runtime metadata"
  end

  @impl ReqLlmNext.Provider
  def get_api_key(_opts) do
    raise "Generic provider requires runtime metadata"
  end
end
