# Execution Plan

Current-truth prescriptive runtime plan contract for ReqLlmNext 2.0.

<!-- covers: reqllm.execution_plan.prescriptive_object reqllm.execution_plan.surface_and_fallbacks reqllm.execution_plan.deterministic_stack reqllm.execution_plan.planner_owns_assembly reqllm.execution_plan.no_downstream_rediscovery -->

```spec-meta
id: reqllm.execution_plan
kind: execution_plan
status: active
summary: Single fully resolved runtime plan assembled from profile, mode, and policy rules.
surface:
  - lib/req_llm_next/execution_plan.ex
  - lib/req_llm_next/operation_planner.ex
  - lib/req_llm_next/execution_modules.ex
decisions:
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_mode_first_class
  - reqllm.decision.execution_surface_support_unit
  - reqllm.decision.five_scope_policy_rules
```

## Requirements

```spec-requirements
- id: reqllm.execution_plan.prescriptive_object
  statement: ReqLlmNext shall use `ExecutionPlan` as the only prescriptive runtime object that tells downstream layers how a request attempt will run.
  priority: must
  stability: evolving

- id: reqllm.execution_plan.surface_and_fallbacks
  statement: `ExecutionPlan` shall record exactly one chosen primary execution surface plus any fallback surfaces, normalized parameter values, timeout policy, session strategy, and adapter references for the request attempt.
  priority: must
  stability: evolving

- id: reqllm.execution_plan.deterministic_stack
  statement: `ExecutionPlan` shall deterministically resolve one implementation stack of provider, session runtime mode, semantic protocol, wire format, transport, and ordered plan adapters for a given profile, mode, and policy input.
  priority: must
  stability: evolving

- id: reqllm.execution_plan.planner_owns_assembly
  statement: ReqLlmNext shall keep plan assembly in the planner boundary, including mode normalization, rule evaluation, surface selection, parameter normalization, surface-specific parameter validation, session planning, and adapter selection.
  priority: must
  stability: evolving

- id: reqllm.execution_plan.no_downstream_rediscovery
  statement: Downstream execution layers shall consume the resolved `ExecutionPlan` and shall not rediscover provider, protocol, wire, transport, or adapter behavior by model name after planning.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/execution_plan.spec.md
  covers:
    - reqllm.execution_plan.prescriptive_object
    - reqllm.execution_plan.surface_and_fallbacks
    - reqllm.execution_plan.deterministic_stack
    - reqllm.execution_plan.planner_owns_assembly
    - reqllm.execution_plan.no_downstream_rediscovery

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.execution_plan.prescriptive_object
    - reqllm.execution_plan.deterministic_stack
    - reqllm.execution_plan.planner_owns_assembly
```
