defmodule ReqLlmNext.Extensions.Dsl do
  @moduledoc """
  Spark authoring DSL for execution-extension providers, families, and rules.
  """

  alias ReqLlmNext.Extensions.{Criteria, Family, Provider, Rule, Seams}
  alias ReqLlmNext.Extensions.Dsl.Normalize
  alias ReqLlmNext.Extensions.Dsl.Transformers.PersistDefinitionManifest

  @criteria %Spark.Dsl.Entity{
    name: :criteria,
    target: Criteria,
    schema: [
      provider_ids: [type: {:list, :atom}, default: []],
      family_ids: [type: {:list, :atom}, default: []],
      model_ids: [type: {:list, :string}, default: []],
      operations: [type: {:list, :atom}, default: []],
      transports: [type: {:list, :atom}, default: []],
      semantic_protocols: [type: {:list, :atom}, default: []],
      stream?: [type: :boolean, required: false],
      tools?: [type: :boolean, required: false],
      structured?: [type: :boolean, required: false],
      facts: [type: :keyword_list, default: []],
      features: [type: :keyword_list, default: []]
    ],
    transform: {Normalize, :criteria, []}
  }

  @seams %Spark.Dsl.Entity{
    name: :seams,
    target: Seams,
    schema: [
      provider_module: [type: :atom, required: false],
      provider_facts_module: [type: :atom, required: false],
      surface_catalog_module: [type: :atom, required: false],
      surface_preparation_modules: [type: :keyword_list, default: []],
      semantic_protocol_modules: [type: :keyword_list, default: []],
      wire_modules: [type: :keyword_list, default: []],
      transport_modules: [type: :keyword_list, default: []],
      adapter_modules: [type: {:list, :atom}, default: []],
      utility_modules: [type: :keyword_list, default: []]
    ],
    transform: {Normalize, :seams, []}
  }

  @provider %Spark.Dsl.Entity{
    name: :provider,
    target: Provider,
    args: [:id],
    schema: [
      id: [type: :atom, required: true],
      default_family: [type: :atom, required: false],
      description: [type: :string, required: false]
    ],
    entities: [seams: [@seams]],
    singleton_entity_keys: [:seams],
    transform: {Normalize, :provider, []}
  }

  @family %Spark.Dsl.Entity{
    name: :family,
    target: Family,
    args: [:id],
    schema: [
      id: [type: :atom, required: true],
      priority: [type: :integer, default: 100],
      default?: [type: :boolean, default: false],
      description: [type: :string, required: false]
    ],
    entities: [criteria: [@criteria], seams: [@seams]],
    singleton_entity_keys: [:criteria, :seams],
    transform: {Normalize, :family, []}
  }

  @rule %Spark.Dsl.Entity{
    name: :rule,
    target: Rule,
    args: [:id],
    schema: [
      id: [type: :atom, required: true],
      priority: [type: :integer, default: 100],
      description: [type: :string, required: false]
    ],
    entities: [criteria: [@criteria], patch: [@seams]],
    singleton_entity_keys: [:criteria, :patch],
    transform: {Normalize, :rule, []}
  }

  @providers %Spark.Dsl.Section{
    name: :providers,
    entities: [@provider]
  }

  @families %Spark.Dsl.Section{
    name: :families,
    entities: [@family]
  }

  @rules %Spark.Dsl.Section{
    name: :rules,
    entities: [@rule]
  }

  use Spark.Dsl.Extension,
    sections: [@providers, @families, @rules],
    transformers: [PersistDefinitionManifest],
    module_prefix: ReqLlmNext.Extensions.Dsl.Generated
end
