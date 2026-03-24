# Architecture Direction

Current-truth boundary and execution-layer contract for ReqLlmNext 2.0.

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

```spec-meta
id: reqllm.architecture
kind: architecture
status: active
summary: Current-truth runtime boundary and layer-separation contract for model input and execution flow, including handcrafted `LLMDB.Model` support at the boundary, the deterministic planning bridge, the thin top-level facade, and the separated execution stack.
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
```

## Requirements

```spec-requirements
- id: reqllm.architecture.model_input_boundary
  statement: ReqLlmNext runtime APIs shall accept model inputs only as `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, with handcrafted `LLMDB.Model` structs supported as a local-iteration boundary hook, and the top-level public API contract lane shall load the compiled facade before export assertions so architecture-boundary verification stays about the actual runtime module rather than code-loading order.
  priority: must
  stability: evolving

- id: reqllm.architecture.facts_mode_policy_plan
  statement: ReqLlmNext architecture shall normalize model facts into `ModelProfile`, request intent into `ExecutionMode`, resolve ordered policy rules, run surface-owned request preparation, and materialize a single `ExecutionPlan` before downstream execution, including manifest-backed provider-scoped descriptive fact extraction, family-owned surface catalog resolution through declared seams, honoring explicit transport preference when a matching surface exists, and validating surface-specific parameter compatibility before wire encoding.
  priority: must
  stability: evolving

- id: reqllm.architecture.execution_layers
  statement: ReqLlmNext architecture shall separate semantic protocol, wire format, transport, provider, and session-runtime concerns so request meaning, wire envelopes, persistent execution state, and byte movement can evolve independently.
  priority: must
  stability: evolving

- id: reqllm.architecture.provider_specific_utilities
  statement: ReqLlmNext architecture may expose provider-scoped utility modules for non-canonical provider endpoints, but those utilities and provider-native helper shapes shall remain outside the top-level cross-provider facade and outside the core execution-plan layer stack except where a selected provider surface explicitly accepts them.
  priority: should
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

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api
  execute: true
  covers:
    - reqllm.architecture.model_input_boundary

- kind: source_file
  target: .spec/specs/architecture.spec.md
  covers:
    - reqllm.architecture.provider_specific_utilities
```
