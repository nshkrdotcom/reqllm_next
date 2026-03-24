defmodule ReqLlmNext.ModelProfile.SurfaceCatalog do
  @moduledoc """
  Execution-surface catalog construction driven by the compiled extension manifest.
  """

  alias ReqLlmNext.Extensions

  @type catalog :: %{
          family: atom() | nil,
          surfaces: %{
            optional(ReqLlmNext.ModelProfile.operation()) => [ReqLlmNext.ExecutionSurface.t()]
          },
          session_capabilities: map()
        }

  @fallback_module ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible

  @spec build(LLMDB.Model.t(), map()) :: catalog()
  def build(%LLMDB.Model{} = model, provider_facts) do
    context = %{provider: model.provider, model_id: model.id, facts: provider_facts}

    case Extensions.resolve_compiled(context) do
      {:ok, %{family: family, seams: %{surface_catalog_module: module}}}
      when not is_nil(module) ->
        module.build(model, provider_facts)
        |> Map.put(:family, family.id)

      {:ok, %{family: family}} ->
        @fallback_module.build(model, provider_facts)
        |> Map.put(:family, family.id)

      {:error, :no_matching_family} ->
        @fallback_module.build(model, provider_facts)
        |> Map.put(:family, nil)
    end
  end
end
