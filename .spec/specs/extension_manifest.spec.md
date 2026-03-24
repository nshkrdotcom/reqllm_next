# Extension Manifest

Current-truth contract for the compile-time extension manifest and its plain runtime data model.

<!-- covers: reqllm.extension_manifest.plain_runtime_contract reqllm.extension_manifest.family_precedence reqllm.extension_manifest.rule_precedence reqllm.extension_manifest.narrow_seams -->

```spec-meta
id: reqllm.extension_manifest
kind: architecture
status: active
summary: Declarative family and rule data that preserve a default happy path while allowing narrow opt-in execution overrides.
surface:
  - .spec/decisions/compile_time_extension_manifest.md
  - .spec/specs/extension_manifest.spec.md
  - guides/extension_architecture.md
  - lib/req_llm_next/extensions.ex
  - lib/req_llm_next/extensions/**/*.ex
  - test/req_llm_next/extensions/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.extension_manifest.plain_runtime_contract
  statement: ReqLlmNext shall model execution extension behavior as plain runtime data made of providers, families, rules, criteria, seam patches, and manifests so the runtime consumes a stable contract independent of any authoring DSL.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.family_precedence
  statement: Default execution families shall resolve deterministically from declarative criteria using explicit precedence, then fall back through provider-registered default families and finally global default families, so the happy path is stable and inspectable without reintroducing central provider branching.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.rule_precedence
  statement: Opt-in override rules shall apply in deterministic order from broad to narrow so later, more specific patches can refine the family default without reintroducing omniscient central branching.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.narrow_seams
  statement: Extension declarations shall only patch explicit seams such as provider registration, provider facts, surface catalog construction, surface preparation, semantic protocol mapping, wire mapping, transport mapping, adapters, and provider-native utility homes.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.spark_authoring_layer
  statement: ReqLlmNext may use Spark as a compile-time authoring DSL for built-in extension declarations, but that authoring layer shall compile to the plain manifest contract and compiled manifest modules rather than becoming the runtime extension API itself.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/extension_manifest.spec.md
  covers:
    - reqllm.extension_manifest.plain_runtime_contract
    - reqllm.extension_manifest.family_precedence
    - reqllm.extension_manifest.rule_precedence
    - reqllm.extension_manifest.narrow_seams
    - reqllm.extension_manifest.spark_authoring_layer

- kind: command
  target: mix test test/req_llm_next/extensions/manifest_test.exs test/req_llm_next/extensions/dsl_test.exs
  execute: true
  covers:
    - reqllm.extension_manifest.plain_runtime_contract
    - reqllm.extension_manifest.family_precedence
    - reqllm.extension_manifest.rule_precedence
    - reqllm.extension_manifest.spark_authoring_layer
```
