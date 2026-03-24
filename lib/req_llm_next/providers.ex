defmodule ReqLlmNext.Providers do
  @moduledoc """
  Provider registry resolved from the compiled extension manifest.
  """

  alias ReqLlmNext.Extensions

  @spec get(atom()) :: {:ok, module()} | {:error, term()}
  def get(provider_id) when is_atom(provider_id) do
    Extensions.provider_module(Extensions.compiled_manifest(), provider_id)
  end

  @spec get!(atom()) :: module()
  def get!(provider_id) do
    case get(provider_id) do
      {:ok, module} -> module
      {:error, reason} -> raise "Provider error: #{inspect(reason)}"
    end
  end

  @spec list() :: [atom()]
  def list do
    Extensions.compiled_manifest().providers
    |> Map.keys()
    |> Enum.sort()
  end
end
