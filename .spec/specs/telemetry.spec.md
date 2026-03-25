# Telemetry

Current-truth runtime telemetry contract for ReqLlmNext.

<!-- covers: reqllm.telemetry.request_lifecycle reqllm.telemetry.canonical_measurements reqllm.telemetry.sanitized_payloads -->

```spec-meta
id: reqllm.telemetry
kind: telemetry
status: active
summary: Stable request, usage, and reasoning telemetry across sync, streaming, and compat flows.
surface:
  - .spec/specs/telemetry.spec.md
  - guides/package_thesis.md
  - lib/req_llm_next/telemetry.ex
  - test/req_llm_next/telemetry_test.exs
```

## Requirements

```spec-requirements
- id: reqllm.telemetry.request_lifecycle
  statement: Every logical request shall emit one canonical request lifecycle that supports timing, finish classification, usage attribution, and runtime anomaly diagnosis across sync, streaming, and request-style media flows.
  priority: must
  stability: evolving

- id: reqllm.telemetry.canonical_measurements
  statement: Telemetry metadata and measurements shall remain stable across transports, operations, canonical realtime flows, and curated provider support-matrix lanes so application code and compat tooling do not need provider-specific parsing to interpret usage, reasoning, request summaries, or execution-stack selection.
  priority: must
  stability: evolving

- id: reqllm.telemetry.sanitized_payloads
  statement: Payload capture shall be opt-in and sanitized, and raw reasoning text shall not be emitted as telemetry.
  priority: must
  stability: evolving

- id: reqllm.telemetry.kernel_boundary
  statement: Package-level runtime telemetry shall emit through `ReqLlmNext.Telemetry` rather than ad hoc direct `:telemetry` calls from runtime layers so event names, request spans, provider-request spans, stream instrumentation, and metadata redaction remain stable.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/telemetry.spec.md
  covers:
    - reqllm.telemetry.request_lifecycle
    - reqllm.telemetry.canonical_measurements
    - reqllm.telemetry.sanitized_payloads
    - reqllm.telemetry.kernel_boundary

- kind: command
  target: mix test test/req_llm_next/telemetry_test.exs test/providers/openai/client_test.exs
  execute: true
  covers:
    - reqllm.telemetry.request_lifecycle
    - reqllm.telemetry.canonical_measurements
    - reqllm.telemetry.kernel_boundary

```
