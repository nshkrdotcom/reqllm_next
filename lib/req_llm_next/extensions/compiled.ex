defmodule ReqLlmNext.Extensions.Compiled do
  @moduledoc """
  Compiled manifest assembled from the built-in extension definition modules.
  """

  alias ReqLlmNext.Extensions.{Definition, RuntimeRegistry}

  @definition_roots [
    Path.expand("../providers", __DIR__),
    Path.expand("../families", __DIR__)
  ]

  Enum.each(@definition_roots, &Module.put_attribute(__MODULE__, :external_resource, &1))

  @definition_paths Definition.discover_definition_paths()
  Enum.each(@definition_paths, &Module.put_attribute(__MODULE__, :external_resource, &1))

  @definitions Definition.discover_definition_modules()
               |> Enum.map(&Code.ensure_compiled!/1)
               |> Enum.uniq()
  @manifest Definition.merge_manifests!(@definitions)
  @runtime_registry RuntimeRegistry.build(@manifest)

  @spec definitions() :: [module()]
  def definitions, do: @definitions

  @spec manifest() :: ReqLlmNext.Extensions.Manifest.t()
  def manifest, do: @manifest

  @spec runtime_registry() :: RuntimeRegistry.t()
  def runtime_registry, do: @runtime_registry
end
