defmodule ReqLlmNext.Extensions.Compiled do
  @moduledoc """
  Compiled manifest assembled from the built-in extension definition modules.
  """

  alias ReqLlmNext.Extensions.Definition

  @definitions [
    ReqLlmNext.Extensions.Definitions.OpenAICompatible,
    ReqLlmNext.Extensions.Definitions.OpenAI,
    ReqLlmNext.Extensions.Definitions.Anthropic
  ]
  @manifest Definition.merge_manifests!(@definitions)

  @spec definitions() :: [module()]
  def definitions, do: @definitions

  @spec manifest() :: ReqLlmNext.Extensions.Manifest.t()
  def manifest, do: @manifest
end
