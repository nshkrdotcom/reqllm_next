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
```

## Requirements

```spec-requirements
- id: reqllm.telemetry.request_lifecycle
  statement: Every logical request shall emit one canonical request lifecycle that supports timing, finish classification, usage attribution, and runtime anomaly diagnosis across sync, streaming, and request-style media flows.
  priority: must
  stability: evolving

- id: reqllm.telemetry.canonical_measurements
  statement: Telemetry metadata and measurements shall remain stable across transports, operations, and curated provider support-matrix lanes so application code and compat tooling do not need provider-specific parsing to interpret usage, reasoning, or request summaries.
  priority: must
  stability: evolving

- id: reqllm.telemetry.sanitized_payloads
  statement: Payload capture shall be opt-in and sanitized, and raw reasoning text shall not be emitted as telemetry.
  priority: must
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

```
