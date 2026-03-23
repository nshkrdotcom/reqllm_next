# Package Contract

High-level runtime contract for the ReqLlmNext library.

```spec-meta
id: reqllm.package
kind: package
status: active
summary: Metadata-driven LLM client runtime and test contract.
surface:
  - lib/**/*.ex
  - test/**/*.exs
  - test/fixtures/**/*.json
```

## Requirements

```spec-requirements
- id: reqllm.package.multi_provider_api
  statement: ReqLlmNext shall provide a unified public API for text generation, structured output, streaming, and embeddings across supported model providers using the same operations whether callers start from an `LLMDB` `model_spec` string or an `%LLMDB.Model{}`, including handcrafted structs used for local development.
  priority: must
  stability: evolving

- id: reqllm.package.fixture_replay
  statement: ReqLlmNext shall verify package behavior with deterministic automated tests that exercise provider scenarios and replay recorded fixtures by default.
  priority: must
  stability: evolving

- id: reqllm.package.execution_planning
  statement: ReqLlmNext shall route supported requests through a deterministic planning path that normalizes model facts into `ModelProfile`, request intent into `ExecutionMode`, selects explicit `ExecutionSurface` support, and materializes an `ExecutionPlan` before executing provider and wire bridges.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test
  execute: true
  covers:
    - reqllm.package.multi_provider_api
    - reqllm.package.fixture_replay
    - reqllm.package.execution_planning

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning
```
