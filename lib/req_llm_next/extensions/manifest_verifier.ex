defmodule ReqLlmNext.Extensions.ManifestVerifier do
  @moduledoc """
  Compile-time verification for merged extension manifests.
  """

  alias ReqLlmNext.Extensions.Manifest

  @spec verify_merge!([Manifest.t()]) :: :ok
  def verify_merge!(manifests) when is_list(manifests) do
    ensure_unique_provider_ids!(manifests)
    ensure_unique_family_ids!(manifests)
    ensure_unique_rule_ids!(manifests)
    :ok
  end

  @spec verify!(Manifest.t()) :: Manifest.t()
  def verify!(%Manifest{} = manifest) do
    ensure_global_default_family!(manifest)
    ensure_provider_default_families_exist!(manifest)
    ensure_rule_family_references_exist!(manifest)
    ensure_provider_seam_boundaries!(manifest)
    ensure_family_and_rule_boundaries!(manifest)
    ensure_seam_modules_compiled!(manifest)
    ensure_family_conflicts_free!(manifest)
    ensure_rule_conflicts_free!(manifest)
    manifest
  end

  defp ensure_unique_provider_ids!(manifests) do
    manifests
    |> Enum.flat_map(&Map.keys(&1.providers))
    |> duplicate_ids!("provider")
  end

  defp ensure_unique_family_ids!(manifests) do
    manifests
    |> Enum.flat_map(&Enum.map(&1.families, fn family -> family.id end))
    |> duplicate_ids!("family")
  end

  defp ensure_unique_rule_ids!(manifests) do
    manifests
    |> Enum.flat_map(&Enum.map(&1.rules, fn rule -> rule.id end))
    |> duplicate_ids!("rule")
  end

  defp duplicate_ids!(ids, label) do
    case Enum.find(Enum.frequencies(ids), fn {_id, count} -> count > 1 end) do
      nil ->
        :ok

      {id, _count} ->
        raise ArgumentError, "duplicate #{label} id in extension manifests: #{inspect(id)}"
    end
  end

  defp ensure_global_default_family!(%Manifest{families: families}) do
    if Enum.any?(families, & &1.default?) do
      :ok
    else
      raise ArgumentError, "extension manifest must declare at least one global default family"
    end
  end

  defp ensure_provider_default_families_exist!(%Manifest{} = manifest) do
    family_ids = MapSet.new(Enum.map(manifest.families, & &1.id))

    case Enum.find(manifest.providers, fn {_provider_id, provider} ->
           not is_nil(provider.default_family) and
             not MapSet.member?(family_ids, provider.default_family)
         end) do
      nil ->
        :ok

      {provider_id, provider} ->
        raise ArgumentError,
              "provider #{inspect(provider_id)} references unknown default family #{inspect(provider.default_family)}"
    end
  end

  defp ensure_rule_family_references_exist!(%Manifest{} = manifest) do
    family_ids = MapSet.new(Enum.map(manifest.families, & &1.id))

    case Enum.find(manifest.rules, fn rule ->
           Enum.any?(rule.criteria.family_ids, &(not MapSet.member?(family_ids, &1)))
         end) do
      nil ->
        :ok

      rule ->
        missing =
          Enum.reject(rule.criteria.family_ids, &MapSet.member?(family_ids, &1))
          |> Enum.uniq()

        raise ArgumentError,
              "rule #{inspect(rule.id)} references unknown family ids: #{inspect(missing)}"
    end
  end

  defp ensure_provider_seam_boundaries!(%Manifest{} = manifest) do
    case Enum.find(manifest.providers, fn {_provider_id, provider} ->
           invalid_provider_seams?(provider.seams)
         end) do
      nil ->
        :ok

      {provider_id, _provider} ->
        raise ArgumentError,
              "provider #{inspect(provider_id)} may only declare provider, provider-facts, and utility seams"
    end
  end

  defp ensure_family_and_rule_boundaries!(%Manifest{} = manifest) do
    case Enum.find(manifest.families, fn family -> invalid_family_rule_seams?(family.seams) end) do
      nil ->
        ensure_rule_boundaries!(manifest.rules)

      family ->
        raise ArgumentError,
              "family #{inspect(family.id)} may not declare provider or utility seams"
    end
  end

  defp ensure_rule_boundaries!(rules) do
    case Enum.find(rules, fn rule -> invalid_family_rule_seams?(rule.patch) end) do
      nil ->
        :ok

      rule ->
        raise ArgumentError,
              "rule #{inspect(rule.id)} may not declare provider or utility seams"
    end
  end

  defp ensure_family_conflicts_free!(%Manifest{} = manifest) do
    case conflicting_entities(manifest.families, fn family ->
           {family.priority, serialize(family.criteria)}
         end) do
      nil ->
        :ok

      [first, second | _rest] ->
        raise ArgumentError,
              "families #{inspect(first.id)} and #{inspect(second.id)} have identical match criteria and priority"
    end
  end

  defp ensure_rule_conflicts_free!(%Manifest{} = manifest) do
    case conflicting_entities(manifest.rules, fn rule ->
           {rule.priority, serialize(rule.criteria)}
         end) do
      nil ->
        :ok

      [first, second | _rest] ->
        raise ArgumentError,
              "rules #{inspect(first.id)} and #{inspect(second.id)} have identical match criteria and priority"
    end
  end

  defp conflicting_entities(entities, key_fun) do
    entities
    |> Enum.group_by(key_fun)
    |> Enum.find_value(fn {_key, grouped} ->
      if length(grouped) > 1, do: grouped
    end)
  end

  defp invalid_provider_seams?(seams) do
    not is_nil(seams.surface_catalog_module) or
      seams.surface_preparation_modules != %{} or
      seams.semantic_protocol_modules != %{} or
      seams.wire_modules != %{} or
      seams.transport_modules != %{} or
      seams.adapter_modules != []
  end

  defp invalid_family_rule_seams?(seams) do
    not is_nil(seams.provider_module) or
      not is_nil(seams.provider_facts_module) or
      seams.utility_modules != %{}
  end

  defp ensure_seam_modules_compiled!(%Manifest{} = manifest) do
    manifest
    |> all_seam_modules()
    |> Enum.find(fn {_path, seam_module} ->
      match?({:error, _reason}, Code.ensure_compiled(seam_module))
    end)
    |> case do
      nil ->
        :ok

      {path, seam_module} ->
        raise ArgumentError,
              "extension seam #{path} references unknown module #{inspect(seam_module)}"
    end
  end

  defp all_seam_modules(%Manifest{} = manifest) do
    provider_modules =
      Enum.flat_map(manifest.providers, fn {provider_id, provider} ->
        seam_modules(provider.seams, "provider #{inspect(provider_id)}")
      end)

    family_modules =
      Enum.flat_map(manifest.families, fn family ->
        seam_modules(family.seams, "family #{inspect(family.id)}")
      end)

    rule_modules =
      Enum.flat_map(manifest.rules, fn rule ->
        seam_modules(rule.patch, "rule #{inspect(rule.id)}")
      end)

    provider_modules ++ family_modules ++ rule_modules
  end

  defp seam_modules(seams, path_prefix) do
    []
    |> maybe_module("#{path_prefix}.provider_module", seams.provider_module)
    |> maybe_module("#{path_prefix}.provider_facts_module", seams.provider_facts_module)
    |> maybe_module("#{path_prefix}.surface_catalog_module", seams.surface_catalog_module)
    |> append_map_modules(
      "#{path_prefix}.surface_preparation_modules",
      seams.surface_preparation_modules
    )
    |> append_map_modules(
      "#{path_prefix}.semantic_protocol_modules",
      seams.semantic_protocol_modules
    )
    |> append_map_modules("#{path_prefix}.wire_modules", seams.wire_modules)
    |> append_map_modules("#{path_prefix}.transport_modules", seams.transport_modules)
    |> append_list_modules("#{path_prefix}.adapter_modules", seams.adapter_modules)
    |> append_map_modules("#{path_prefix}.utility_modules", seams.utility_modules)
  end

  defp maybe_module(acc, _path, nil), do: acc

  defp maybe_module(acc, path, seam_module) when is_atom(seam_module),
    do: [{path, seam_module} | acc]

  defp append_map_modules(acc, path_prefix, modules) when is_map(modules) do
    Enum.reduce(modules, acc, fn {key, seam_module}, inner_acc ->
      maybe_module(inner_acc, "#{path_prefix}.#{key}", seam_module)
    end)
  end

  defp append_list_modules(acc, path_prefix, modules) when is_list(modules) do
    Enum.with_index(modules)
    |> Enum.reduce(acc, fn {seam_module, index}, inner_acc ->
      maybe_module(inner_acc, "#{path_prefix}[#{index}]", seam_module)
    end)
  end

  defp serialize(term), do: :erlang.term_to_binary(term)
end
