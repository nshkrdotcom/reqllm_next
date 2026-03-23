# Telemetry Spec

Status: Proposed

## Objective

Define the runtime telemetry contract for ReqLlmNext so request lifecycle, reasoning lifecycle, and usage can be observed consistently across sync, streaming, and non-chat operations.

## Purpose

Telemetry is the primary runtime observability surface for:

1. latency measurement
2. usage attribution
3. reasoning observability
4. transport anomaly diagnosis
5. compatibility evidence collection

This surface must be stable enough for application code, compat tooling, and future issue-filing automation to consume without provider-specific parsing.

## Core Rules

1. Every logical request must get one `request_id` before transport I/O begins.
2. Request lifecycle telemetry is the source of truth for request timing and terminal classification.
3. Metadata shape must not vary by transport. Sync and stream flows must emit the same canonical `usage`, `reasoning`, and summary shapes.
4. Compatibility events may expose a smaller view, but their documented measurement shape must match the emitted shape exactly.
5. Telemetry must be derived from canonical runtime artifacts, not provider-specific ad hoc parsing paths.
6. Streaming lifecycle accounting belongs at the stream runtime boundary, where status, headers, decoded chunks, timeout, cancel, and terminal completion are all visible.
7. Payload capture is opt-in and sanitized. Reasoning text must never be emitted raw.
8. Telemetry is observational. It must not mutate request planning, protocol encoding, transport behavior, or response materialization.

## Coverage

The telemetry contract applies to:

1. text generation
2. object generation
3. text streaming
4. object streaming
5. embeddings
6. future image, speech, and transcription operations when those operations are added

## Event Families

### Request Lifecycle

ReqLlmNext should emit:

1. `[:req_llm_next, :request, :start]`
2. `[:req_llm_next, :request, :stop]`
3. `[:req_llm_next, :request, :exception]`

Measurements:

1. `request.start` emits `%{system_time: integer()}`
2. `request.stop` emits `%{duration: integer(), system_time: integer()}`
3. `request.exception` emits `%{duration: integer(), system_time: integer()}`

Metadata:

1. `request_id`
2. `operation`
3. `mode`
4. `provider`
5. `model`
6. `transport`
7. `reasoning`
8. `request_summary`
9. `response_summary`
10. `http_status`
11. `finish_reason`
12. `usage`

Optional metadata:

1. `request_payload`
2. `response_payload`
3. `error`

### Reasoning Lifecycle

ReqLlmNext should emit:

1. `[:req_llm_next, :reasoning, :start]`
2. `[:req_llm_next, :reasoning, :update]`
3. `[:req_llm_next, :reasoning, :stop]`

Measurements:

1. `reasoning.start` emits `%{system_time: integer()}`
2. `reasoning.update` emits `%{system_time: integer()}`
3. `reasoning.stop` emits `%{duration: integer(), system_time: integer()}`

Metadata:

1. `request_id`
2. `operation`
3. `mode`
4. `provider`
5. `model`
6. `transport`
7. `reasoning`
8. `milestone`

Reasoning events are metadata-only even when payload capture is enabled.

### Token Usage Compatibility

ReqLlmNext should emit:

1. `[:req_llm_next, :token_usage]`

Measurements must be flat:

1. `input_tokens`
2. `output_tokens`
3. `total_tokens`
4. `reasoning_tokens`
5. `cache_read_tokens`
6. `cache_creation_tokens`
7. `input_cost`
8. `output_cost`
9. `total_cost`

Metadata:

1. `request_id`
2. `operation`
3. `mode`
4. `provider`
5. `model`
6. `transport`

If a field is unknown it may be omitted, but the event must not switch between flat and nested measurement shapes by transport.

## Canonical Metadata Contracts

### `request_id`

1. `request_id` identifies one logical API request.
2. All request, reasoning, and usage events for that logical request must carry the same `request_id`.
3. The `request_id` should also be copied into terminal response metadata so users can correlate returned values with emitted telemetry.

### `mode`

`mode` identifies public API behavior, not provider behavior.

Allowed values:

1. `:sync`
2. `:stream`

### `transport`

`transport` identifies the byte-moving mechanism.

Allowed values:

1. `:http`
2. `:http_sse`
3. `:websocket`

The current implementation may initially use a narrower subset, but the event field should remain transport-oriented.

## Reasoning Contract

The `reasoning` metadata map must be provider-neutral and stable across operations.

Required keys:

1. `supported?`
2. `requested?`
3. `effective?`
4. `requested_mode`
5. `requested_effort`
6. `requested_budget_tokens`
7. `effective_mode`
8. `effective_effort`
9. `effective_budget_tokens`
10. `returned_content?`
11. `reasoning_tokens`
12. `content_bytes`
13. `channel`

Allowed `channel` values:

1. `:none`
2. `:usage_only`
3. `:content_only`
4. `:content_and_usage`

Reasoning milestones should be emitted for:

1. request start
2. first observed reasoning content
3. first observed reasoning usage or any meaningful reasoning token change
4. first observed provider reasoning details
5. terminal completion

## Summary Contracts

### Request Summary

For chat-like operations, request summary should capture:

1. `message_count`
2. `text_bytes`
3. `image_part_count`
4. `tool_call_count`

For embeddings, request summary should capture:

1. `input_count`
2. `input_bytes`

Other operations should define compact, operation-specific summaries rather than raw payload dumps.

### Response Summary

For chat-like operations, response summary should capture:

1. `text_bytes`
2. `thinking_bytes`
3. `tool_call_count`
4. `image_count`
5. `object?`

For embeddings, response summary should capture:

1. `vector_count`
2. `dimensions`

Response summaries are compact terminal observations. They are not substitutes for the actual returned response object.

## Usage Contract

`usage` attached to request lifecycle metadata must be canonical across sync and stream flows.

Canonical keys:

1. `input_tokens`
2. `output_tokens`
3. `total_tokens`
4. `reasoning_tokens`
5. `cache_read_tokens`
6. `cache_creation_tokens`
7. `input_cost`
8. `output_cost`
9. `total_cost`

Rules:

1. `request.stop` usage metadata must have the same shape regardless of transport.
2. The token usage compatibility event may omit fields that are unknown, but it must preserve the same field names.
3. Costs are optional until cost metadata is available for the operation and model.

## Payload Contract

Default payload mode is metadata-only.

Allowed payload modes:

1. `:none`
2. `:raw`

Rules:

1. Raw payload capture is opt-in.
2. Raw payload capture must still sanitize secrets and redact reasoning text.
3. Embeddings should summarize vectors rather than emit raw vector payloads unless a future spec explicitly allows it.
4. Binary payloads should be summarized by size and format rather than emitted directly.

## Runtime Inputs

Telemetry should be computed from these canonical execution artifacts:

1. execution plan
2. encoded semantic-protocol request payload
3. canonical stream chunks
4. terminal response or terminal error

The telemetry surface must not depend on provider-specific request internals once those artifacts have been normalized.

## Stream Runtime Requirements

Streaming telemetry must be emitted from the runtime boundary that owns:

1. HTTP status
2. response headers
3. SSE framing
4. decoded canonical chunks
5. timeout
6. cancellation
7. terminal completion

This keeps streaming telemetry aligned with actual lifecycle transitions instead of inferred post hoc from buffered results.

## Terminal Rules

Allowed terminal classifications:

1. `:stop`
2. `:length`
3. `:tool_calls`
4. `:content_filter`
5. `:cancelled`
6. `:timeout`
7. `:incomplete`
8. `:error`
9. `:unknown`

Rules:

1. Exactly one terminal request event must be emitted per logical request.
2. `request.stop` is for successful or intentionally terminated request completion paths.
3. `request.exception` is for failure paths.
4. Timeout must not be silently collapsed into `:unknown`.
5. Cancellation must be explicitly represented rather than inferred from missing terminal metadata.

## Canonical Chunk Direction

The current tuple-based stream contract is sufficient for early iteration, but the long-term direction is a dedicated canonical stream chunk shape.

The canonical chunk contract must preserve:

1. text content
2. reasoning content
3. tool-call boundaries
4. usage updates
5. terminal metadata
6. provider-independent error information

Telemetry must consume that canonical contract rather than bespoke wire-level tuple combinations.

## Lessons Encoded From Upstream Review

1. Request lifecycle metadata must not expose different `usage` shapes for sync and stream execution paths.
2. Compatibility usage events must keep a single documented measurement schema. Flat documented fields must not be emitted as nested maps.
3. Telemetry and response materialization must agree on terminal metadata. If the stream runtime sees `finish_reason`, `usage`, or reasoning content, the non-streaming response path must preserve those facts.
4. Effective reasoning must be derived from the encoded provider request, not just the user-facing options, so adapter and protocol rewrites are observable.
5. Request correlation must be generated once and propagated everywhere instead of being reconstructed independently by each layer.

## Acceptance Criteria

This spec is satisfied when:

1. the same request metadata contract is emitted for sync and stream flows
2. request and reasoning telemetry share a stable `request_id`
3. reasoning telemetry is provider-neutral
4. usage metadata is canonical across transports
5. payload capture is opt-in and sanitized
6. stream runtime owns terminal request accounting
7. telemetry contracts are covered by dedicated tests
