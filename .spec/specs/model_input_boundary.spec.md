# Model Input Boundary

Current-truth public model-input contract for ReqLlmNext 2.0.

<!-- covers: reqllm.model_input.accepted_forms reqllm.model_input.llmdb_resolution reqllm.model_input.fail_fast -->

```spec-meta
id: reqllm.model_input
kind: model_input
status: active
summary: Narrow public model boundary for `model_spec` strings and `%LLMDB.Model{}` values, including handcrafted structs as a first-class local-iteration hook.
surface:
  - README.md
  - AGENTS.md
  - guides/package_thesis.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/model_resolver.ex
  - test/public_api/contract_test.exs
  - test/public_api/text_generation_test.exs
  - test/model_resolver_test.exs
decisions:
  - reqllm.decision.model_input_boundary
  - reqllm.decision.zoi_backed_struct_contracts
```

## Requirements

```spec-requirements
- id: reqllm.model_input.accepted_forms
  statement: ReqLlmNext public runtime APIs shall accept model input only as an `LLMDB` `model_spec` string or a `%LLMDB.Model{}`, including handcrafted `%LLMDB.Model{}` values used for local iteration, unreleased models, and local providers.
  priority: must
  stability: evolving

- id: reqllm.model_input.llmdb_resolution
  statement: String `model_spec` input shall delegate parsing and model resolution semantics to `LLMDB` rather than reimplementing model-spec parsing inside ReqLlmNext.
  priority: must
  stability: evolving

- id: reqllm.model_input.fail_fast
  statement: The model boundary shall fail fast on tuples, ad hoc maps, unsupported types, or invalid model metadata and shall not let raw unvalidated model input continue into execution, while leaving later provider-native helper validation and surface-specific request validation to the planning boundary rather than reintroducing raw model checks downstream, and the public contract lane shall load the top-level facade before export assertions so model-boundary contract coverage is checking the real compiled API surface.
  priority: must
  stability: evolving

- id: reqllm.model_input.zoi_handoff_contracts
  statement: Accepted model input shall hand off into Zoi-backed internal package contracts such as `ModelProfile`, `ExecutionMode`, `ExecutionPlan`, `Response`, and `StreamResponse` rather than into plain ad hoc structs so the public boundary feeds explicit internal schemas.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_input_boundary.spec.md
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast
    - reqllm.model_input.zoi_handoff_contracts

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api/contract_test.exs test/public_api/text_generation_test.exs
  execute: true
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast
```
