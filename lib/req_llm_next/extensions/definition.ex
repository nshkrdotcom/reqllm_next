defmodule ReqLlmNext.Extensions.Definition do
  @moduledoc """
  Spark-backed authoring layer for execution-extension declarations.
  """

  use Spark.Dsl,
    many_extension_kinds: [:extensions],
    default_extensions: [extensions: [ReqLlmNext.Extensions.Dsl]]

  alias ReqLlmNext.Extensions.Manifest

  @spec manifest(module()) :: Manifest.t()
  def manifest(module) when is_atom(module) do
    Spark.Dsl.Extension.get_persisted(module, :reqllm_extension_manifest)
  end

  @spec providers(module()) :: %{optional(atom()) => ReqLlmNext.Extensions.Provider.t()}
  def providers(module) when is_atom(module) do
    manifest(module).providers
  end

  @spec families(module()) :: [ReqLlmNext.Extensions.Family.t()]
  def families(module) when is_atom(module) do
    manifest(module).families
  end

  @spec rules(module()) :: [ReqLlmNext.Extensions.Rule.t()]
  def rules(module) when is_atom(module) do
    manifest(module).rules
  end

  @spec merge_manifests!([module()]) :: Manifest.t()
  def merge_manifests!(modules) when is_list(modules) do
    modules
    |> Enum.map(&manifest/1)
    |> Enum.reduce(Manifest.new!(%{}), fn manifest, acc ->
      Manifest.new!(%{
        providers: Map.merge(acc.providers, manifest.providers),
        families: acc.families ++ manifest.families,
        rules: acc.rules ++ manifest.rules
      })
    end)
  end
end
