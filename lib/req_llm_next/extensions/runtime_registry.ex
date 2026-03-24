defmodule ReqLlmNext.Extensions.RuntimeRegistry do
  @moduledoc """
  Compiled registry of globally-addressable runtime seam modules.
  """

  alias ReqLlmNext.Extensions.Manifest

  @type t :: %{
          provider_modules: %{optional(atom()) => module()},
          session_runtime_modules: %{optional(atom()) => module()},
          semantic_protocol_modules: %{optional(atom()) => module() | nil},
          wire_modules: %{optional(atom()) => module()},
          transport_modules: %{optional(atom()) => module() | nil}
        }

  @spec build(Manifest.t()) :: t()
  def build(%Manifest{} = manifest) do
    seams =
      manifest.providers
      |> Map.values()
      |> Enum.map(& &1.seams)
      |> Kernel.++(Enum.map(manifest.families, & &1.seams))
      |> Kernel.++(Enum.map(manifest.rules, & &1.patch))

    %{
      provider_modules: provider_modules(manifest),
      session_runtime_modules: merge_module_maps!(seams, :session_runtime_modules),
      semantic_protocol_modules: merge_module_maps!(seams, :semantic_protocol_modules),
      wire_modules: merge_module_maps!(seams, :wire_modules),
      transport_modules: merge_module_maps!(seams, :transport_modules)
    }
  end

  defp provider_modules(%Manifest{} = manifest) do
    Enum.reduce(manifest.providers, %{}, fn {provider_id, provider}, acc ->
      case provider.seams.provider_module do
        nil -> acc
        module -> Map.put(acc, provider_id, module)
      end
    end)
  end

  defp merge_module_maps!(seams, key) do
    Enum.reduce(seams, %{}, fn seams, acc ->
      seams
      |> Map.fetch!(key)
      |> Enum.reduce(acc, fn {module_key, module}, current ->
        case Map.fetch(current, module_key) do
          {:ok, ^module} ->
            current

          {:ok, existing} ->
            raise ArgumentError,
                  "runtime seam #{inspect(key)} defines conflicting modules for #{inspect(module_key)}: " <>
                    "#{inspect(existing)} vs #{inspect(module)}"

          :error ->
            Map.put(current, module_key, module)
        end
      end)
    end)
  end
end
