# Transport

Current-truth transport contract for ReqLlmNext 2.0.

<!-- covers: reqllm.transport.byte_movement reqllm.transport.supported_modes reqllm.transport.semantic_separation reqllm.transport.fixture_replay_parity -->

```spec-meta
id: reqllm.transport
kind: transport
status: active
summary: Connection mechanics and byte movement for HTTP, SSE, and WebSocket execution.
surface:
  - .spec/specs/transport.spec.md
  - .spec/specs/layer_boundaries.spec.md
decisions:
  - reqllm.decision.execution_layers
```

## Requirements

```spec-requirements
- id: reqllm.transport.byte_movement
  statement: Transport shall own connection mechanics, request dispatch, frame receipt, disconnect handling, and transport lifecycle errors without changing semantic behavior.
  priority: must
  stability: evolving

- id: reqllm.transport.supported_modes
  statement: ReqLlmNext transport architecture shall support at least `:http`, `:http_sse`, and `:websocket` modes through the same execution-plan boundary.
  priority: must
  stability: evolving

- id: reqllm.transport.semantic_separation
  statement: Transport shall not inspect model names, reinterpret semantic payload meaning, decode provider-family events into canonical chunks, or silently override planner-selected surface behavior.
  priority: must
  stability: evolving

- id: reqllm.transport.fixture_replay_parity
  statement: Transport-aware fixture replay shall preserve transport shape by replaying raw SSE chunks for HTTP streaming and raw frame payloads for WebSocket streaming through the same wire-decoding and semantic-protocol boundaries used by runtime execution, preferring the recorded fixture surface when it differs from the current plan.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/transport.spec.md
  covers:
    - reqllm.transport.byte_movement
    - reqllm.transport.supported_modes
    - reqllm.transport.semantic_separation

- kind: command
  target: mix test test/fixtures_test.exs test/req_llm_next_test.exs
  execute: true
  covers:
    - reqllm.transport.fixture_replay_parity
```
