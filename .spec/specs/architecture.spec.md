# Architecture Direction

Current-truth boundary and execution-layer contract for ReqLlmNext 2.0.

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

```spec-meta
id: reqllm.architecture
kind: architecture
status: active
summary: Current-truth runtime boundary and layer-separation contract for model input and execution flow, including handcrafted `LLMDB.Model` support at the boundary, a fully plan-driven execution spine, the thin top-level facade, and the separated execution stack.
surface:
  - README.md
  - AGENTS.md
  - .spec/README.md
  - guides/package_thesis.md
  - guides/anthropic_openai_compatibility.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/anthropic.ex
  - lib/req_llm_next/execution_mode.ex
  - lib/req_llm_next/execution_plan.ex
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_resolver.ex
  - lib/req_llm_next/operation_planner.ex
  - lib/req_llm_next/policy_rules.ex
  - lib/req_llm_next/execution_modules.ex
  - lib/req_llm_next/runtime_metadata.ex
  - lib/req_llm_next/support.ex
  - lib/req_llm_next/realtime.ex
  - lib/req_llm_next/response/output_item.ex
  - lib/req_llm_next/telemetry.ex
  - .spec/specs/public_api.spec.md
  - test/public_api/**/*.exs
  - test/model_resolver_test.exs
  - test/operation_planner_test.exs
decisions:
  - reqllm.decision.model_input_boundary
  - reqllm.decision.execution_layers
  - reqllm.decision.execution_plan_bridge
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_mode_first_class
  - reqllm.decision.execution_surface_support_unit
  - reqllm.decision.five_scope_policy_rules
  - reqllm.decision.layer_scoped_plan_aware_adapters
  - reqllm.decision.media_operation_families
  - reqllm.decision.canonical_output_items
  - reqllm.decision.transport_agnostic_realtime_core
  - reqllm.decision.runtime_telemetry_kernel
  - reqllm.decision.zoi_backed_struct_contracts
  - reqllm.decision.live_verifier_tests
  - reqllm.decision.provider_expansion_strategy
  - reqllm.decision.llmdb_best_effort_runtime
  - reqllm.decision.governed_authority_boundary
```

## Phase 10 Governed Authority Update

Phase 10 keeps standalone provider behavior as the default path and makes
governed authority a ref-only runtime lane. The architecture now carries
provider-key, base-url, cleanup-policy, realtime-session-token, reconnect-token,
stream, endpoint-account, lease, target, operation-policy, redaction, and
revocation refs through planning, realtime validation, cleanup projection, and
telemetry without exposing materialized provider credentials.

## Phase 2 Env And Dependency Bootstrap

This subject is affected by the Phase 2 bootstrap only at the boundary level:
runtime code receives credentials and fixture mode through the materialized
`ReqLlmNext.Env` application env map, and ExecutionPlane package dependency
selection is owned by checked-in dependency source manifests rather than
one-off resolver logic or environment variables. This update does not change
the subject-specific planning, wire, transport, telemetry, or verifier semantics
beyond that boundary.

## Requirements

```spec-requirements
- id: reqllm.architecture.model_input_boundary
  statement: ReqLlmNext runtime APIs shall accept model inputs only as `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, with handcrafted `LLMDB.Model` structs supported as a local-iteration boundary hook, and the top-level public API contract lane shall load the compiled facade before export assertions so architecture-boundary verification stays about the actual runtime module rather than code-loading order.
  priority: must
  stability: evolving

- id: reqllm.architecture.facts_mode_policy_plan
  statement: ReqLlmNext architecture shall normalize model facts into `ModelProfile`, request intent into `ExecutionMode`, resolve compatibility-aware surface policy, run surface-owned request preparation, and materialize a single `ExecutionPlan` before downstream execution, including manifest-backed provider-scoped descriptive fact extraction for first-class providers, typed `LLMDB.Provider.runtime` and `LLMDB.Model.execution` metadata as the upstream contract for best-effort providers without dedicated slice registrations, family-owned or metadata-driven surface catalog resolution before planning, manifest-backed or generic runtime-module lookup for provider, session-runtime, protocol, wire, and transport layers, honoring explicit transport and session intent when a matching surface exists, validating surface-specific parameter compatibility before wire encoding, preparing continuation state in session runtime before transport execution, and routing both streaming and request-style non-streaming HTTP execution through explicit transport modules across text, object, embedding, image, transcription, and speech operations, including provider-owned Google embedding and image lanes inside the native Google family, while allowing public docs to distinguish first-class and best-effort support tiers without splitting the runtime into different planner architectures.
  priority: must
  stability: evolving

- id: reqllm.architecture.execution_layers
  statement: ReqLlmNext architecture shall separate realtime adapter, realtime session reduction, semantic protocol, wire format, transport, provider, session-runtime, and telemetry-kernel concerns so canonical request and event meaning, wire envelopes, persistent execution state, byte movement, and diagnostics can evolve independently, and canonical response normalization shall expose explicit result channels on top of output items so higher-level helpers do not have to recover those distinctions from provider metadata while replay-backed suites and sparse live verifier suites continue to exercise the same execution spine rather than alternate ad hoc paths.
  priority: must
  stability: evolving

- id: reqllm.architecture.zoi_struct_contracts
  statement: ReqLlmNext architecture shall model package-owned planning, response, streaming, runtime-state, and extension-manifest structs as Zoi-backed schema contracts so the execution spine carries explicit required fields, defaults, and introspection instead of ad hoc plain structs.
  priority: should
  stability: evolving

- id: reqllm.architecture.provider_specific_utilities
  statement: ReqLlmNext architecture may expose provider-scoped utility modules for non-canonical provider endpoints and provider-native helper shapes such as Anthropic web search, web fetch, code execution, MCP, computer use, token counting, files, and batches, but those utilities and helper shapes shall remain outside the top-level cross-provider facade and outside the core execution-plan layer stack except where a selected provider surface explicitly accepts them, and provider expansion shall prefer reusing existing execution families with provider-owned deltas before introducing new shared abstractions.
  priority: should
  stability: evolving

- id: reqllm.architecture.governed_authority_boundary
  statement: ReqLlmNext architecture shall treat governed credentials and endpoint authority as an explicit provider-layer contract separate from model input, planning intent, semantic protocol, wire payloads, and transport mechanics, so standalone env or option fallbacks never become implicit governance and provider-owned utility paths obey the same governed authority boundary as canonical generation, realtime, media, embedding, and best-effort runtime-metadata requests.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: README.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers

- kind: source_file
  target: .spec/specs/architecture.spec.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers
    - reqllm.architecture.zoi_struct_contracts
    - reqllm.architecture.governed_authority_boundary

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api
  execute: true
  covers:
    - reqllm.architecture.model_input_boundary

- kind: source_file
  target: .spec/specs/architecture.spec.md
  covers:
    - reqllm.architecture.provider_specific_utilities

- kind: command
  target: mix test test/best_effort_runtime_test.exs test/public_api/support_status_test.exs
  execute: true
  covers:
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.model_input_boundary

- kind: command
  target: mix test test/req_llm_next/governed_authority_test.exs test/providers/openai/client_test.exs test/providers/anthropic/client_test.exs
  execute: true
  covers:
    - reqllm.architecture.execution_layers
    - reqllm.architecture.provider_specific_utilities
    - reqllm.architecture.governed_authority_boundary
```
