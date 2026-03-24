defmodule ReqLlmNext.Extensions do
  @moduledoc """
  Plain runtime contract for compile-time declared execution extensions.

  The runtime consumes manifests, families, rules, and seam patches from this
  namespace. Authoring layers such as Spark should compile into these data
  structures instead of becoming the runtime architecture themselves.
  """

  alias ReqLlmNext.Extensions.Manifest

  @type context :: %{
          optional(:provider) => atom(),
          optional(:family) => atom(),
          optional(:model_id) => String.t(),
          optional(:operation) => atom(),
          optional(:transport) => atom(),
          optional(:semantic_protocol) => atom(),
          optional(:stream?) => boolean(),
          optional(:tools?) => boolean(),
          optional(:structured?) => boolean(),
          optional(:facts) => map(),
          optional(:features) => map()
        }

  @spec provider_module(Manifest.t(), atom()) :: {:ok, module()} | {:error, term()}
  def provider_module(%Manifest{} = manifest, provider) when is_atom(provider) do
    case Map.get(manifest.providers, provider) do
      nil -> {:error, {:unknown_provider, provider}}
      module -> {:ok, module}
    end
  end

  @spec resolve_family(Manifest.t(), context()) ::
          {:ok, ReqLlmNext.Extensions.Family.t()} | {:error, :no_matching_family}
  def resolve_family(%Manifest{} = manifest, context) when is_map(context) do
    Manifest.resolve_family(manifest, context)
  end

  @spec matching_rules(Manifest.t(), context()) :: [ReqLlmNext.Extensions.Rule.t()]
  def matching_rules(%Manifest{} = manifest, context) when is_map(context) do
    Manifest.matching_rules(manifest, context)
  end
end
