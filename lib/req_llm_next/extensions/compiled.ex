defmodule ReqLlmNext.Extensions.Compiled do
  @moduledoc """
  Compiled manifest assembled from the built-in extension definition modules.
  """

  alias ReqLlmNext.Extensions.{Definition, RuntimeRegistry}

  @definitions [
    ReqLlmNext.Extensions.Definitions.OpenAICompatible,
    ReqLlmNext.Extensions.Definitions.OpenAI,
    ReqLlmNext.Extensions.Definitions.Anthropic
  ]
  @manifest Definition.merge_manifests!(@definitions)
  @runtime_registry RuntimeRegistry.build(@manifest)

  @spec definitions() :: [module()]
  def definitions, do: @definitions

  @spec manifest() :: ReqLlmNext.Extensions.Manifest.t()
  def manifest, do: @manifest

  @spec runtime_registry() :: RuntimeRegistry.t()
  def runtime_registry, do: @runtime_registry
end
