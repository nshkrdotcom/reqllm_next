defmodule ReqLlmNext.Extensions.Dsl.Verifiers.VerifySeamModules do
  @moduledoc false

  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> entities_with_paths()
    |> Enum.find_value(fn {entity, path} -> verify_entity_modules(module, entity, path) end)
    |> case do
      nil -> :ok
      error -> raise error
    end
  end

  defp entities_with_paths(dsl_state) do
    provider_entities =
      Spark.Dsl.Verifier.get_entities(dsl_state, [:providers])
      |> Enum.map(&{&1, [:providers, &1.id]})

    family_entities =
      Spark.Dsl.Verifier.get_entities(dsl_state, [:families])
      |> Enum.map(&{&1, [:families, &1.id]})

    rule_entities =
      Spark.Dsl.Verifier.get_entities(dsl_state, [:rules])
      |> Enum.map(&{&1, [:rules, &1.id]})

    provider_entities ++ family_entities ++ rule_entities
  end

  defp verify_entity_modules(module, entity, path) do
    entity
    |> seam_module_refs()
    |> Enum.find_value(fn {seam_path, seam_module} ->
      case Code.ensure_compiled(seam_module) do
        {:module, _loaded} ->
          nil

        {:error, _reason} ->
          Spark.Error.DslError.exception(
            module: module,
            path: path ++ seam_path,
            message: "extension seam references unknown module #{inspect(seam_module)}",
            location: Spark.Dsl.Entity.anno(entity)
          )
      end
    end)
  end

  defp seam_module_refs(entity) do
    seams =
      Map.get(entity, :seams) ||
        Map.get(entity, :patch) ||
        ReqLlmNext.Extensions.Seams.empty()

    []
    |> maybe_module([:seams, :provider_module], seams.provider_module)
    |> maybe_module([:seams, :provider_facts_module], seams.provider_facts_module)
    |> maybe_module([:seams, :surface_catalog_module], seams.surface_catalog_module)
    |> seam_map_modules([:seams, :surface_preparation_modules], seams.surface_preparation_modules)
    |> seam_map_modules([:seams, :semantic_protocol_modules], seams.semantic_protocol_modules)
    |> seam_map_modules([:seams, :wire_modules], seams.wire_modules)
    |> seam_map_modules([:seams, :transport_modules], seams.transport_modules)
    |> seam_list_modules([:seams, :adapter_modules], seams.adapter_modules)
    |> seam_map_modules([:seams, :utility_modules], seams.utility_modules)
  end

  defp maybe_module(acc, _path, nil), do: acc

  defp maybe_module(acc, path, seam_module) when is_atom(seam_module),
    do: [{path, seam_module} | acc]

  defp seam_map_modules(acc, base_path, modules) when is_map(modules) do
    Enum.reduce(modules, acc, fn {key, seam_module}, inner_acc ->
      maybe_module(inner_acc, base_path ++ [key], seam_module)
    end)
  end

  defp seam_list_modules(acc, base_path, modules) when is_list(modules) do
    Enum.with_index(modules)
    |> Enum.reduce(acc, fn {seam_module, index}, inner_acc ->
      maybe_module(inner_acc, base_path ++ [index], seam_module)
    end)
  end
end
