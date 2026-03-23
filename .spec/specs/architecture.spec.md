# Architecture Direction

Current-truth boundary and execution-layer contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.architecture
kind: architecture
status: active
summary: Current-truth runtime boundary and layer-separation contract for model input and execution flow, including handcrafted `LLMDB.Model` support at the boundary, supporting package-thesis guides, and the deterministic planning bridge that drives starter model slices.
surface:
  - README.md
  - AGENTS.md
  - specs/README.md
  - guides/package_thesis.md
  - specs/architecture.md
  - specs/model_source.md
  - specs/model_profile.md
  - specs/execution_mode.md
  - specs/execution_surface.md
  - specs/overrides.md
  - specs/execution_plan.md
  - specs/layer_boundaries.md
  - specs/semantic_protocol.md
  - specs/wire_format.md
  - specs/transport.md
  - specs/session_runtime.md
  - specs/provider.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/execution_mode.ex
  - lib/req_llm_next/execution_plan.ex
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_resolver.ex
  - lib/req_llm_next/operation_planner.ex
  - lib/req_llm_next/policy_rules.ex
  - lib/req_llm_next/execution_modules.ex
  - test/model_resolver_test.exs
  - test/operation_planner_test.exs
  - test/req_llm_next_test.exs
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
  statement: ReqLlmNext runtime APIs shall accept model inputs only as `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, with handcrafted `LLMDB.Model` structs supported as a local-iteration boundary hook.
  priority: must
  stability: evolving

- id: reqllm.architecture.facts_mode_policy_plan
  statement: ReqLlmNext architecture shall normalize model facts into `ModelProfile`, request intent into `ExecutionMode`, resolve ordered policy rules, and materialize a single `ExecutionPlan` before downstream execution.
  priority: must
  stability: evolving

- id: reqllm.architecture.execution_layers
  statement: ReqLlmNext architecture shall separate semantic protocol, wire format, transport, provider, and session-runtime concerns so request meaning, wire envelopes, persistent execution state, and byte movement can evolve independently.
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
  target: specs/architecture.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers

- kind: source_file
  target: specs/model_source.md
  covers:
    - reqllm.architecture.model_input_boundary

- kind: source_file
  target: specs/wire_format.md
  covers:
    - reqllm.architecture.execution_layers

- kind: command
  target: mix test test/model_resolver_test.exs test/req_llm_next_test.exs
  execute: true
  covers:
    - reqllm.architecture.model_input_boundary
```
