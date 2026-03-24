defmodule ReqLlmNext.Extensions.Dsl.Transformers.PersistDefinitionManifest do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias ReqLlmNext.Extensions.Manifest

  @impl true
  def transform(dsl_state) do
    manifest =
      Manifest.new!(%{
        providers: Spark.Dsl.Transformer.get_entities(dsl_state, [:providers]),
        families: Spark.Dsl.Transformer.get_entities(dsl_state, [:families]),
        rules: Spark.Dsl.Transformer.get_entities(dsl_state, [:rules])
      })

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :reqllm_extension_manifest, manifest)}
  end
end
