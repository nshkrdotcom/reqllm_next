# Wire Format

Current-truth transport-facing envelope contract for ReqLlmNext 2.0.

<!-- covers: reqllm.wire_format.envelope_ownership reqllm.wire_format.transport_separation reqllm.wire_format.frame_decode -->

```spec-meta
id: reqllm.wire_format
kind: wire_format
status: active
summary: Transport-facing request envelopes, routes, headers, and frame decoding.
surface:
  - .spec/specs/wire_format.spec.md
  - .spec/specs/layer_boundaries.spec.md
decisions:
  - reqllm.decision.execution_layers
```

## Requirements

```spec-requirements
- id: reqllm.wire_format.envelope_ownership
  statement: Wire format shall own provider-facing routes, content types, headers, and request envelopes that sit between semantic protocol payloads and transport execution.
  priority: must
  stability: evolving

- id: reqllm.wire_format.transport_separation
  statement: Wire format shall not reinterpret semantic meaning, open connections, manage retries, or own provider auth policy.
  priority: must
  stability: evolving

- id: reqllm.wire_format.frame_decode
  statement: Wire format shall decode inbound transport frames into provider-family event terms for semantic protocol without skipping directly to canonical user-facing results.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/wire_format.spec.md
  covers:
    - reqllm.wire_format.envelope_ownership
    - reqllm.wire_format.transport_separation
    - reqllm.wire_format.frame_decode
```
