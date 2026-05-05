# Session Runtime

Current-truth persistent runtime-state contract for ReqLlmNext 2.0.

<!-- covers: reqllm.session_runtime.persistence_owner reqllm.session_runtime.runtime_state reqllm.session_runtime.fallback_and_diagnostics -->

```spec-meta
id: reqllm.session_runtime
kind: session_runtime
status: active
summary: Continuation and persistent execution-state ownership for multi-turn and transport-persistent flows.
surface:
  - .spec/specs/session_runtime.spec.md
  - .spec/specs/layer_boundaries.spec.md
  - lib/req_llm_next/session_runtime.ex
  - lib/req_llm_next/session_runtimes/**/*.ex
  - test/providers/openai/session_runtime_responses_test.exs
decisions:
  - reqllm.decision.execution_layers
```

## Phase 10 Governed Authority Update

Realtime session runtime must revalidate governed lease, target grant, and
revocation status before reconnect or streaming and must project cleanup as refs
only. Realtime session token, reconnect token, and stream auth values are
materialized effect state and must be removed from cleanup evidence.

## Requirements

```spec-requirements
- id: reqllm.session_runtime.persistence_owner
  statement: Session runtime shall own persistent execution state such as continuation identifiers, attach-or-create behavior, transport reuse, expiry, and in-flight rules.
  priority: must
  stability: evolving

- id: reqllm.session_runtime.runtime_state
  statement: Session state shall be runtime state only and shall not be embedded into `ModelProfile`, provider metadata, or semantic protocol definitions.
  priority: must
  stability: evolving

- id: reqllm.session_runtime.fallback_and_diagnostics
  statement: Session runtime shall define fallback behavior when continuation state or transport state becomes invalid and shall emit structured diagnostics that compat tooling can attribute to the session layer.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/session_runtime.spec.md
  covers:
    - reqllm.session_runtime.persistence_owner
    - reqllm.session_runtime.runtime_state
    - reqllm.session_runtime.fallback_and_diagnostics

- kind: command
  target: mix test test/providers/openai/session_runtime_responses_test.exs test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.session_runtime.persistence_owner
    - reqllm.session_runtime.runtime_state
    - reqllm.session_runtime.fallback_and_diagnostics
```
