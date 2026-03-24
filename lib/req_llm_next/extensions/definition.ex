defmodule ReqLlmNext.Extensions.Definition do
  @moduledoc """
  Spark-backed authoring layer for execution-extension declarations.
  """

  use Spark.Dsl,
    many_extension_kinds: [:extensions],
    default_extensions: [extensions: [ReqLlmNext.Extensions.Dsl]]

  alias ReqLlmNext.Extensions.{Manifest, ManifestExpander, ManifestVerifier}

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

  @spec discover_definition_modules() :: [module()]
  def discover_definition_modules do
    definition_paths()
    |> Enum.map(&definition_module_from_path/1)
    |> Enum.sort_by(&Atom.to_string/1)
  end

  @spec merge_manifests!([module()]) :: Manifest.t()
  def merge_manifests!(modules) when is_list(modules) do
    manifests = Enum.map(modules, &manifest/1)
    ManifestVerifier.verify_merge!(manifests)

    manifests
    |> Enum.reduce(Manifest.new!(%{}), fn manifest, acc ->
      Manifest.new!(%{
        providers: Map.merge(acc.providers, manifest.providers),
        families: acc.families ++ manifest.families,
        rules: acc.rules ++ manifest.rules
      })
    end)
    |> ManifestExpander.expand!()
    |> ManifestVerifier.verify!()
  end

  defp definition_module_from_path(path) do
    path
    |> File.read!()
    |> extract_declared_module!(path)
  end

  defp definition_paths do
    [families_definition_paths(), providers_definition_paths()]
    |> List.flatten()
    |> Enum.uniq()
  end

  defp families_definition_paths do
    __DIR__
    |> Path.join("../families/**/definition.ex")
    |> Path.expand()
    |> Path.wildcard()
  end

  defp providers_definition_paths do
    __DIR__
    |> Path.join("../providers/**/definition.ex")
    |> Path.expand()
    |> Path.wildcard()
  end

  defp extract_declared_module!(contents, path) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, contents, capture: :all_but_first) do
      [module_name] ->
        Module.concat([module_name])

      _ ->
        raise ArgumentError,
              "could not determine extension definition module from #{path}"
    end
  end
end
