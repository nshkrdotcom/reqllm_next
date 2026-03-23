# Source Layout

Current-truth source-ownership contract for ReqLlmNext.

<!-- covers: reqllm.source_layout.concern_homes reqllm.source_layout.layer_scoped_quirks reqllm.source_layout.compat_outside_runtime -->

```spec-meta
id: reqllm.source_layout
kind: source_layout
status: active
summary: Source ownership rules that keep model quirks, planning logic, and compat tooling in distinct homes.
surface:
  - AGENTS.md
  - .spec/specs/source_layout.spec.md
  - lib/req_llm_next/**/*.ex
  - test/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.source_layout.concern_homes
  statement: ReqLlmNext shall keep model-boundary concerns, profile construction, mode normalization, policy resolution, plan assembly, protocol logic, wire envelopes, transport mechanics, and session state in distinct source locations that match the architecture.
  priority: must
  stability: evolving

- id: reqllm.source_layout.layer_scoped_quirks
  statement: Imperative quirks shall live in explicit layer-scoped adapters rather than in omniscient global hooks or ad hoc model-name branches spread across the stack.
  priority: must
  stability: evolving

- id: reqllm.source_layout.compat_outside_runtime
  statement: Compat-only expectations, issue drafting, and drift analysis shall live in compat tooling rather than inside provider, planner, protocol, wire, transport, or session runtime modules.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/source_layout.spec.md
  covers:
    - reqllm.source_layout.concern_homes
    - reqllm.source_layout.layer_scoped_quirks
    - reqllm.source_layout.compat_outside_runtime
```
