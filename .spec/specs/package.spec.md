# Package Contract

High-level runtime contract for the ReqLlmNext library.

```spec-meta
id: reqllm.package
kind: package
status: active
summary: Metadata-driven LLM client runtime and test contract.
surface:
  - lib/**/*.ex
  - test/support/**/*.ex
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
  statement: ReqLlmNext shall verify package behavior with deterministic automated tests that exercise provider scenarios and replay recorded fixtures by default, preserving the recorded execution surface when fixtures were captured against an older but still valid endpoint shape.
  priority: must
  stability: evolving

- id: reqllm.package.execution_planning
  statement: ReqLlmNext shall route supported requests through a deterministic planning path that normalizes model facts into `ModelProfile`, request intent into `ExecutionMode`, selects explicit `ExecutionSurface` support, validates surface-specific parameter compatibility, materializes an `ExecutionPlan`, and resolves an execution stack of provider, semantic protocol, wire, and transport modules before runtime execution.
  priority: must
  stability: evolving

- id: reqllm.package.buffered_stream_metadata
  statement: When ReqLlmNext buffers a streamed response into the canonical `Response` shape, it shall preserve terminal metadata such as finish reason and provider-facing response identifiers emitted by the canonical stream.
  priority: should
  stability: evolving

- id: reqllm.package.model_slice_verification
  statement: ReqLlmNext shall be able to lock supported scenario sets to explicit starter-model slices and curated provider support-matrix lanes, including alternative transport lanes where relevant, so provider-specific support stays visible as the planning path evolves without exploding into a one-file-per-model matrix.
  priority: should
  stability: evolving

- id: reqllm.package.local_env_loading
  statement: ReqLlmNext shall support local development and replay or live verification by loading a local `.env` file without overriding shell-provided environment variables, so API keys can be supplied for tests and compatibility runs without being committed.
  priority: should
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
    - reqllm.package.buffered_stream_metadata

- kind: command
  target: mix test test/public_api
  execute: true
  covers:
    - reqllm.package.multi_provider_api

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning

- kind: command
  target: mix test test/model_slices/anthropic_haiku_4_5_test.exs
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/model_slices/openai_gpt_4o_mini_test.exs
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test.starter_slice
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/anthropic_comprehensive_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/openai_comprehensive_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/openai_websocket_coverage_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/provider_features/anthropic_beta_features_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/env_test.exs
  execute: true
  covers:
    - reqllm.package.local_env_loading
```
