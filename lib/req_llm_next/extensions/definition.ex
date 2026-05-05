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
    discover_definition_paths()
    |> Enum.map(&definition_module_from_path/1)
    |> Enum.sort_by(&Atom.to_string/1)
  end

  @spec discover_definition_paths() :: [String.t()]
  def discover_definition_paths do
    definition_paths()
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
    case declared_module_name(contents) do
      {:ok, module_name} ->
        Module.safe_concat([module_name])

      :error ->
        raise ArgumentError,
              "could not determine extension definition module from #{path}"
    end
  end

  defp declared_module_name(contents) do
    contents
    |> String.split(["\n", "\r\n"])
    |> Enum.find_value(:error, &declared_module_name_from_line/1)
  end

  defp declared_module_name_from_line(line) do
    trimmed = String.trim_leading(line)
    prefix = "defmodule "

    if String.starts_with?(trimmed, prefix) do
      module_name =
        trimmed
        |> binary_part(byte_size(prefix), byte_size(trimmed) - byte_size(prefix))
        |> take_module_name()

      if module_name == "", do: false, else: {:ok, module_name}
    else
      false
    end
  end

  defp take_module_name(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.take_while(&module_name_byte?/1)
    |> IO.iodata_to_binary()
  end

  defp module_name_byte?(byte) when byte in ?a..?z, do: true
  defp module_name_byte?(byte) when byte in ?A..?Z, do: true
  defp module_name_byte?(byte) when byte in ?0..?9, do: true
  defp module_name_byte?(?_), do: true
  defp module_name_byte?(?.), do: true
  defp module_name_byte?(_byte), do: false
end
