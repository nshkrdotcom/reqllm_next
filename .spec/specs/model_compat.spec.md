# Model Compat

Current-truth live compatibility and drift-detection contract for ReqLlmNext.

<!-- covers: reqllm.model_compat.real_runtime reqllm.model_compat.shared_scenarios reqllm.model_compat.layer_attribution -->

```spec-meta
id: reqllm.model_compat
kind: compat
status: active
summary: Live scenario execution, curated provider sweeps, and drift detection built on the same runtime architecture as normal execution.
surface:
  - guides/package_thesis.md
  - guides/anthropic_surface_map.md
  - guides/openai_surface_map.md
  - guides/anthropic_openai_compatibility.md
  - guides/extension_architecture.md
  - guides/provider_expansion_roadmap.md
  - lib/req_llm_next/support_matrix.ex
  - lib/req_llm_next/provider_test/comprehensive.ex
  - lib/mix/tasks/model_compat.ex
  - test/mix/tasks/model_compat_test.exs
  - test/coverage/anthropic_comprehensive_test.exs
  - test/coverage/openai_comprehensive_test.exs
  - test/coverage/openai_websocket_coverage_test.exs
  - test/provider_features/anthropic_beta_features_test.exs
  - test/provider_features/anthropic_advanced_messages_test.exs
  - test/live_verifiers/**/*.exs
  - test/providers/deepseek/**/*.exs
  - test/providers/groq/**/*.exs
  - test/providers/openrouter/**/*.exs
  - test/providers/vllm/**/*.exs
  - test/providers/zenmux/**/*.exs
  - test/providers/anthropic/**/*.exs
decisions:
  - reqllm.decision.provider_surface_maps_in_guides
  - reqllm.decision.live_verifier_tests
  - reqllm.decision.provider_expansion_strategy
  - reqllm.decision.governed_authority_boundary
```

## Phase 10 Governed Authority Update

Model compatibility remains independent from credential selection. Governed
authority refs cannot make an unsupported model, operation, surface, or
transport valid; they only bind credentials, endpoint authority, target posture,
and cleanup evidence for a model and surface that compatibility checks already
approved.

## Requirements

```spec-requirements
- id: reqllm.model_compat.real_runtime
  statement: Model compatibility runs shall consume the same model normalization, planning, protocol, wire, transport, and provider architecture as normal runtime execution and shall not introduce test-only shortcuts around those layers.
  priority: must
  stability: evolving

- id: reqllm.model_compat.shared_scenarios
  statement: Model compatibility shall run shared allow-listed scenarios that exercise canonical API capabilities across providers so drift and regressions are observable on the real execution stack.
  priority: must
  stability: evolving

- id: reqllm.model_compat.curated_support_matrix
  statement: Provider compatibility sweeps shall run against a curated support matrix of representative provider, model, and transport lanes so live verification stays cost-aware and stable while still pressure-testing the execution-plan architecture, while provider-native feature probes, request-style media lanes that do not fit the generic scenario system, and curated replay-backed best-effort provider proof matrices for representative non-first-class providers remain outside the live matrix in focused coverage lanes.
  priority: should
  stability: evolving

- id: reqllm.model_compat.layer_attribution
  statement: Compat results shall classify anomalies by architectural layer and preserve structured evidence that can be used for follow-up work and issue drafting.
  priority: must
  stability: evolving

- id: reqllm.model_compat.provider_native_surfaces
  statement: Provider coverage work may include provider-native utility surfaces, server-tool feature probes such as Anthropic web search, web fetch, code execution, and context-management coverage, and evaluation guides when those artifacts clarify how non-canonical provider endpoints fit the architecture without broadening the main public API contract.
  priority: should
  stability: evolving

- id: reqllm.model_compat.provider_native_request_shapes
  statement: Provider-native utility coverage shall keep request-shape and representative request-execution proofs for supported non-canonical endpoints so batch, file, vector-store, background, and similar utility surfaces stay reconciled with the shared execution architecture without claiming top-level API support they do not provide, including governed authority proof that utility clients do not bypass provider-layer credential and route governance.
  priority: should
  stability: evolving

- id: reqllm.model_compat.live_verifier_separation
  statement: Live provider drift checks shall live in a sparse explicit verifier lane rather than expanding the replay-backed support matrix or default coverage suite into a broad live-provider matrix.
  priority: should
  stability: evolving

- id: reqllm.model_compat.extension_pressure_tests
  statement: Compatibility expansion work shall keep at least one non-OpenAI OpenAI-compatible provider proof lane and should expand that lane as concrete providers such as DeepSeek, Groq, OpenRouter, and vLLM land, so family reuse, provider-specific semantic overrides, provider-local routing or media-family overrides, explicit shared-family reuse, and wire-resolution fallbacks are tested before broad live coverage is claimed for that ecosystem.
  priority: should
  stability: evolving

- id: reqllm.model_compat.provider_expansion_ordering
  statement: Provider expansion work shall prefer providers that can ride existing families with provider-owned deltas before wrapper platforms or new family systems, shall treat cloud wrappers such as Azure, Google Vertex, and Amazon Bedrock as deferred architecture-heavy additions rather than early ports, and shall document the near-term provider queue plus first-class versus best-effort support boundaries in the provider-expansion roadmap so future provider work stays family-first and replay-first.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_compat.spec.md
  covers:
    - reqllm.model_compat.real_runtime
    - reqllm.model_compat.shared_scenarios
    - reqllm.model_compat.curated_support_matrix
    - reqllm.model_compat.layer_attribution
    - reqllm.model_compat.provider_native_surfaces

- kind: command
  target: mix test test/mix/tasks/model_compat_test.exs
  execute: true
  covers:
    - reqllm.model_compat.real_runtime
    - reqllm.model_compat.layer_attribution

- kind: command
  target: mix test test/coverage/anthropic_comprehensive_test.exs test/coverage/openai_comprehensive_test.exs test/coverage/openai_websocket_coverage_test.exs test/provider_features/anthropic_beta_features_test.exs test/provider_features/anthropic_advanced_messages_test.exs
  execute: true
  covers:
    - reqllm.model_compat.shared_scenarios
    - reqllm.model_compat.curated_support_matrix

- kind: command
  target: mix test test/providers/anthropic
  execute: true
  covers:
    - reqllm.model_compat.provider_native_surfaces

- kind: command
  target: mix test test/providers/anthropic/message_batches_test.exs
  execute: true
  covers:
    - reqllm.model_compat.provider_native_request_shapes

- kind: command
  target: mix test test/providers/openai/client_test.exs test/providers/anthropic/client_test.exs test/providers/openai/background_test.exs test/providers/openai/files_test.exs test/providers/openai/vector_stores_test.exs test/providers/openai/batches_test.exs
  execute: true
  covers:
    - reqllm.model_compat.provider_native_surfaces
    - reqllm.model_compat.provider_native_request_shapes

- kind: command
  target: mix test test/providers/cohere test/providers/deepseek test/providers/elevenlabs test/providers/groq test/providers/openrouter test/providers/vllm test/providers/zenmux test/providers/google test/provider_features/google_native_surfaces_test.exs
  execute: true
  covers:
    - reqllm.model_compat.extension_pressure_tests

- kind: command
  target: mix test test/coverage/best_effort_provider_matrix_test.exs
  execute: true
  covers:
    - reqllm.model_compat.curated_support_matrix
    - reqllm.model_compat.provider_expansion_ordering

- kind: command
  target: mix test.live_verifiers
  execute: true
  covers:
    - reqllm.model_compat.live_verifier_separation

- kind: source_file
  target: guides/provider_expansion_roadmap.md
  covers:
    - reqllm.model_compat.provider_expansion_ordering
```
