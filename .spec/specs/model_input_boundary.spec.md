# Model Input Boundary

Current-truth public model-input contract for ReqLlmNext 2.0.

<!-- covers: reqllm.model_input.accepted_forms reqllm.model_input.llmdb_resolution reqllm.model_input.fail_fast -->

```spec-meta
id: reqllm.model_input
kind: model_input
status: active
summary: Narrow public model boundary for `model_spec` strings and `%LLMDB.Model{}` values.
surface:
  - README.md
  - AGENTS.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/model_resolver.ex
  - test/model_resolver_test.exs
  - test/req_llm_next_test.exs
decisions:
  - reqllm.decision.model_input_boundary
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
  statement: The model boundary shall fail fast on tuples, ad hoc maps, unsupported types, or invalid model metadata and shall not let raw unvalidated model input continue into execution.
  priority: must
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

- kind: command
  target: mix test test/model_resolver_test.exs test/req_llm_next_test.exs
  execute: true
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast
```
