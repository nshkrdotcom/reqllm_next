# Diagnostics

Current-truth structured diagnostics contract for ReqLlmNext.

<!-- covers: reqllm.diagnostics.observational reqllm.diagnostics.layer_attributed reqllm.diagnostics.compat_consumed -->

```spec-meta
id: reqllm.diagnostics
kind: diagnostics
status: active
summary: Structured diagnostic events and anomaly reports emitted by runtime layers and consumed by compat tooling.
surface:
  - .spec/specs/diagnostics.spec.md
  - guides/package_thesis.md
```

## Requirements

```spec-requirements
- id: reqllm.diagnostics.observational
  statement: Diagnostics shall be observational only and shall describe runtime behavior without mutating planning, execution, or response materialization.
  priority: must
  stability: evolving

- id: reqllm.diagnostics.layer_attributed
  statement: ReqLlmNext diagnostics shall attribute events and anomalies to explicit layers such as model profile, planner, semantic protocol, wire format, transport, session runtime, or provider.
  priority: must
  stability: evolving

- id: reqllm.diagnostics.compat_consumed
  statement: Runtime layers may emit diagnostics, but curated support-matrix compat runs, anomaly analyzers, and issue-drafting tooling shall consume them outside the execution layers rather than patching runtime behavior in place.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/diagnostics.spec.md
  covers:
    - reqllm.diagnostics.observational
    - reqllm.diagnostics.layer_attributed
    - reqllm.diagnostics.compat_consumed

```
