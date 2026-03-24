defmodule ReqLlmNext.Extensions.ManifestExpander do
  @moduledoc """
  Expands family inheritance inside merged extension manifests.
  """

  alias ReqLlmNext.Extensions.{Criteria, Family, Manifest, Seams}

  @spec expand!(Manifest.t()) :: Manifest.t()
  def expand!(%Manifest{} = manifest) do
    families_by_id = Map.new(manifest.families, &{&1.id, &1})

    expanded_families =
      Enum.map(manifest.families, fn family ->
        expand_family!(family, families_by_id, [])
      end)

    %{manifest | families: expanded_families}
  end

  defp expand_family!(%Family{extends: nil} = family, _families_by_id, _stack), do: family

  defp expand_family!(%Family{id: id, extends: parent_id} = family, families_by_id, stack) do
    if id in stack do
      raise ArgumentError,
            "cyclic family inheritance in extension manifest: #{inspect(Enum.reverse([id | stack]))}"
    end

    parent =
      case Map.fetch(families_by_id, parent_id) do
        {:ok, parent} ->
          parent

        :error ->
          raise ArgumentError,
                "family #{inspect(id)} extends unknown family #{inspect(parent_id)}"
      end

    expanded_parent = expand_family!(parent, families_by_id, [id | stack])

    %Family{
      family
      | criteria: Criteria.merge(expanded_parent.criteria, family.criteria),
        seams: Seams.merge(expanded_parent.seams, family.seams),
        description: family.description || expanded_parent.description
    }
  end
end
