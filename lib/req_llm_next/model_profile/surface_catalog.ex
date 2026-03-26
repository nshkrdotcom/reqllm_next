defmodule ReqLlmNext.ModelProfile.SurfaceCatalog do
  @moduledoc """
  Execution-surface catalog construction driven by the compiled extension manifest.
  """

  alias ReqLlmNext.Extensions
  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Generic
  alias ReqLlmNext.RuntimeMetadata

  @type catalog :: %{
          family: atom() | nil,
          surfaces: %{
            optional(ReqLlmNext.ModelProfile.operation()) => [ReqLlmNext.ExecutionSurface.t()]
          },
          session_capabilities: map()
        }

  @spec build(LLMDB.Model.t(), map()) :: catalog()
  def build(%LLMDB.Model{} = model, provider_facts) do
    if RuntimeMetadata.registered_provider?(model.provider) or
         not RuntimeMetadata.executable_execution?(model) do
      extension_catalog(model, provider_facts)
    else
      Generic.build(model, provider_facts)
    end
  end

  defp extension_catalog(model, provider_facts) do
    context = %{provider: model.provider, model_id: model.id, facts: provider_facts}

    case Extensions.resolve_compiled(context) do
      {:ok, %{family: family, seams: %{surface_catalog_module: module}}}
      when not is_nil(module) ->
        module.build(model, provider_facts)
        |> annotate_family(family.id)
        |> Map.put(:family, family.id)

      {:ok, %{family: family}} ->
        raise ArgumentError,
              "family #{inspect(family.id)} does not declare a surface catalog module"

      {:error, :no_matching_family} ->
        raise ArgumentError,
              "no execution family matched #{inspect(model.provider)}:#{inspect(model.id)}"
    end
  end

  defp annotate_family(%{surfaces: surfaces} = catalog, family_id) do
    updated_surfaces =
      Enum.into(surfaces, %{}, fn {operation, entries} ->
        {operation, Enum.map(entries, &maybe_put_family(&1, family_id))}
      end)

    Map.put(catalog, :surfaces, updated_surfaces)
  end

  defp maybe_put_family(%ReqLlmNext.ExecutionSurface{family: nil} = surface, family_id) do
    %{surface | family: family_id}
  end

  defp maybe_put_family(surface, _family_id), do: surface
end
