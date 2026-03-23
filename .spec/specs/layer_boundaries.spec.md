# Layer Boundaries

Current-truth execution-layer handoff contract for ReqLlmNext 2.0.

<!-- covers: reqllm.layer_boundaries.separated_io reqllm.layer_boundaries.plan_aware_adapters reqllm.layer_boundaries.no_cross_layer_skips -->

```spec-meta
id: reqllm.layer_boundaries
kind: layer_boundaries
status: active
summary: Explicit handoff rules for provider, session runtime, transport, wire format, semantic protocol, and plan adapters, with one deterministic layer stack per resolved plan.
surface:
  - AGENTS.md
  - lib/req_llm_next/execution_modules.ex
decisions:
  - reqllm.decision.execution_layers
  - reqllm.decision.layer_scoped_plan_aware_adapters
```

## Requirements

```spec-requirements
- id: reqllm.layer_boundaries.separated_io
  statement: ReqLlmNext shall keep provider, session runtime, transport, wire format, and semantic protocol responsibilities separated so no layer skips across another layer's ownership boundary and each resolved plan binds one deterministic layer stack.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.plan_aware_adapters
  statement: ReqLlmNext shall treat adapters as explicit layer-scoped patches and start the 2.0 architecture with plan-aware adapters that operate on `ExecutionPlan` after policy resolution.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.no_cross_layer_skips
  statement: No execution layer shall skip across another layer's ownership boundary by choosing transports in semantic protocol code, reinterpreting semantic meaning in wire code, or introducing model-specific behavior in provider or transport code.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/layer_boundaries.spec.md
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.plan_aware_adapters
    - reqllm.layer_boundaries.no_cross_layer_skips

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.layer_boundaries.plan_aware_adapters
```
