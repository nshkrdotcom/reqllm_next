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
  - lib/req_llm_next/telemetry.ex
  - test/req_llm_next/telemetry_test.exs
```

## Phase 10 Governed Authority Update

Diagnostics for governed ReqLlmNext effects may include authority refs such as
credential, provider-key, base-url, realtime session, stream, cleanup policy,
target, and operation-policy refs. Diagnostics must not include materialized
provider headers, realtime session tokens, reconnect tokens, stream auth, env
credentials, or direct unmanaged option values.

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
- id: reqllm.diagnostics.observational
  statement: Diagnostics shall be observational only and shall describe runtime behavior through the package telemetry kernel without mutating planning, execution, realtime session reduction, or response materialization.
  priority: must
  stability: evolving

- id: reqllm.diagnostics.layer_attributed
  statement: ReqLlmNext diagnostics shall attribute events and anomalies to explicit layers such as model profile, planner, execution-stack resolution, semantic protocol, wire format, transport, session runtime, realtime adapter, provider, or canonical output-item materialization, including request-style media lanes, realtime event reduction, provider-owned utility request execution, and fixture-replay anomalies that do not flow through streaming semantics.
  priority: must
  stability: evolving

- id: reqllm.diagnostics.compat_consumed
  statement: Runtime layers may emit diagnostics, but curated support-matrix compat runs, replay-backed best-effort provider proof matrices, anomaly analyzers, issue-drafting tooling, provider utility verification, and future provider expansion work shall consume them outside the execution layers rather than patching runtime behavior in place or introducing provider-specific diagnostic shortcuts.
  priority: must
  stability: evolving

- id: reqllm.diagnostics.governed_authority_observable
  statement: Governed authority behavior shall remain observable through the existing provider-request diagnostics and fixture evidence without emitting raw governed credential values, unmanaged direct credential options, or env-derived secrets.
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
    - reqllm.diagnostics.governed_authority_observable

- kind: command
  target: mix test test/req_llm_next/telemetry_test.exs test/providers/openai/client_test.exs test/req_llm_next/governed_authority_test.exs
  execute: true
  covers:
    - reqllm.diagnostics.observational
    - reqllm.diagnostics.layer_attributed
    - reqllm.diagnostics.governed_authority_observable

```
