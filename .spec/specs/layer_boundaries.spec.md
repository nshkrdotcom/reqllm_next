# Layer Boundaries

Current-truth execution-layer handoff contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.layer_boundaries
kind: layer_boundaries
status: active
summary: Explicit handoff rules for provider, session runtime, transport, wire format, semantic protocol, and plan adapters, with one deterministic layer stack per resolved plan.
surface:
  - specs/layer_boundaries.md
  - specs/semantic_protocol.md
  - specs/wire_format.md
  - specs/transport.md
  - specs/session_runtime.md
  - specs/provider.md
  - AGENTS.md
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
```

## Verification

```spec-verification
- kind: source_file
  target: specs/layer_boundaries.md
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.plan_aware_adapters

- kind: source_file
  target: specs/semantic_protocol.md
  covers:
    - reqllm.layer_boundaries.separated_io

- kind: source_file
  target: specs/wire_format.md
  covers:
    - reqllm.layer_boundaries.separated_io

- kind: source_file
  target: specs/transport.md
  covers:
    - reqllm.layer_boundaries.separated_io

- kind: source_file
  target: specs/session_runtime.md
  covers:
    - reqllm.layer_boundaries.separated_io

- kind: source_file
  target: specs/provider.md
  covers:
    - reqllm.layer_boundaries.separated_io

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.layer_boundaries.plan_aware_adapters
```
