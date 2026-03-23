# Wire Format Spec

Status: Proposed

<!-- covers: reqllm.architecture.execution_layers reqllm.layer_boundaries.separated_io -->

## Objective

Define the contract for turning semantic protocol payloads into transport-facing requests, envelopes, and inbound frame decoders.

## Purpose

Wire format sits between semantic protocol and transport.

It owns the provider-facing request shape that is still transport-specific but not transport-lifecycle-specific.

Examples:

1. HTTP JSON body plus `Accept: text/event-stream`
2. WebSocket client event wrapper such as `response.create`
3. Inbound SSE event payload extraction
4. Inbound WebSocket JSON envelope parsing

## Responsibilities

1. Accept an `ExecutionPlan` plus semantic protocol payload.
2. Define relative routes or client event targets.
3. Define content types and wire-level headers.
4. Wrap semantic payloads in transport-facing request envelopes.
5. Decode inbound transport frames into provider-family events for the semantic protocol.
6. Emit structured wire-format diagnostics so compat tooling can classify envelope or framing-shape anomalies.

## Input

1. `ExecutionPlan`
2. Semantic protocol payload
3. Optional incremental decode state

## Output

1. Outbound wire request or client event
2. Inbound provider-family event terms
3. Wire-format metadata updates

## Canonical Interface

```elixir
@callback wire_format_id() :: atom()
@callback outbound(ExecutionPlan.t(), payload :: map()) :: term()
@callback decode_frame(term(), decode_state :: map()) :: {[term()], map()}
@callback route(ExecutionPlan.t()) :: String.t() | nil
@callback headers(ExecutionPlan.t()) :: [{String.t(), String.t()}]
```

## Invariants

1. Wire format must not reinterpret semantic meaning.
2. Wire format must not open sockets, retry requests, or manage reconnect policy.
3. Wire format must not own provider auth.
4. Wire format must not inspect model names directly.

## Example: Responses Over HTTP SSE

For OpenAI Responses over HTTP SSE:

1. Semantic protocol builds the Responses API payload.
2. Wire format selects `/v1/responses`.
3. Wire format adds JSON request headers and `Accept: text/event-stream`.
4. Transport performs the HTTP request and yields SSE frames.
5. Wire format extracts SSE event payloads into provider-family event terms.
6. Semantic protocol decodes those events into canonical chunks.

## Example: Responses Over WebSocket

For OpenAI Responses over WebSocket:

1. Semantic protocol builds the Responses API payload.
2. Wire format wraps it in a `response.create` client event.
3. Transport sends that client event over the socket.
4. Transport returns raw WebSocket frames.
5. Wire format parses those frames into provider-family event maps.
6. Semantic protocol decodes those event maps into canonical chunks.

## Compat Attribution

Wire-format anomalies should be attributable here, for example:

1. wrong route or client event target
2. missing required content-type or accept headers
3. malformed client event envelopes
4. frame payload parse failures before semantic decoding

## What Does Not Belong Here

1. semantic finish-reason interpretation
2. usage normalization
3. socket keepalive and reconnect
4. provider auth headers
